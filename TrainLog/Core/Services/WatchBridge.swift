import Foundation
import HealthKit
import Observation
import WatchConnectivity
import TrainLogCore

@MainActor @Observable final class WatchBridge: NSObject, WCSessionDelegate {
    private(set) var paired = false
    private(set) var installed = false
    private(set) var reachable = false
    private(set) var live: WatchLiveSnapshot?
    private(set) var issue: String?
    private(set) var launching = false
    private var started = false
    private var receive: ((Session) throws -> Void)?
    private var receiveUpdate: ((WatchLinkUpdate) throws -> Void)?
    private var acceptedUpdates: [UUID: WatchLinkUpdate] = [:]
    private let directory = URL.applicationSupportDirectory.appending(path: "WatchInbox", directoryHint: .isDirectory)

    func activate(receive: @escaping (Session) throws -> Void, receiveUpdate: @escaping (WatchLinkUpdate) throws -> Void) {
        self.receive = receive
        self.receiveUpdate = receiveUpdate
        guard WCSession.isSupported() else { return }
        if !started { started = true; WCSession.default.delegate = self; WCSession.default.activate() }
        refresh(); drainInbox()
    }
    func refresh() {
        guard WCSession.isSupported() else { return }
        let session = WCSession.default
        paired = session.isPaired; installed = session.isWatchAppInstalled; reachable = session.isReachable
    }
    func start(_ activity: CardioActivity) async {
        guard !launching else { return }
        refresh()
        guard paired, installed else { issue = "请在已配对的 Apple Watch 上安装 TrainLog。"; return }
        launching = true; defer { launching = false }
        do { try await HKHealthStore().startWatchApp(toHandle: activity.workoutConfiguration); issue = nil }
        catch { issue = "未能打开手表训练：\(error.localizedDescription)。也可在手表上直接开始。" }
    }
    func send(_ command: WatchLinkCommand) async throws -> WatchLinkUpdate {
        refresh(); try command.request.validate()
        guard WCSession.default.activationState == .activated, reachable else { throw ValidationError("请打开手表 TrainLog 后重试。连接请求仍保存在手机。") }
        let data = try JSONEncoder().encode(command)
        guard data.count < 8192 else { throw ValidationError("连接请求过大。") }
        return try await withCheckedThrowingContinuation { continuation in
            WCSession.default.sendMessage(["linkCommand": data], replyHandler: { response in
                do {
                    if let error = response["error"] as? String { throw ValidationError(error) }
                    guard let bytes = response["linkUpdate"] as? Data, bytes.count < 8192 else { throw ValidationError("手表连接确认暂不可读，请重新连接。") }
                    let update = try JSONDecoder().decode(WatchLinkUpdate.self, from: bytes)
                    guard update.reference == command.request.reference else { throw ValidationError("收到另一场训练的连接确认。") }
                    continuation.resume(returning: update)
                } catch { continuation.resume(throwing: error) }
            }, errorHandler: { continuation.resume(throwing: $0) })
        }
    }
    private func acceptUpdate(_ dictionary: [String: Any]) {
        guard let data = dictionary["linkUpdate"] as? Data, data.count < 8192,
              let update = try? JSONDecoder().decode(WatchLinkUpdate.self, from: data),
              acceptedUpdates[update.reference.requestID] != update else { return }
        do {
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
            let target = directory.appending(path: "\(UUID().uuidString).event")
            try data.write(to: target, options: [.atomic, .completeFileProtectionUntilFirstUserAuthentication])
            drainInbox()
        } catch { issue = "手表连接状态暂未保存，下次连接会重试：\(error.localizedDescription)" }
    }
    private func acceptLive(_ dictionary: [String: Any]) {
        if dictionary["ended"] as? Bool == true { live = nil; return }
        guard let data = dictionary["live"] as? Data, data.count < 8192,
              let value = try? JSONDecoder().decode(WatchLiveSnapshot.self, from: data), value.isFresh() else { return }
        if let old = live, old.updatedAt > value.updatedAt { return }
        live = value
    }
    private func drainInbox() {
        guard let receive else { return }
        do {
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
            var failures: [String] = []
            let files = try FileManager.default.contentsOfDirectory(at: directory, includingPropertiesForKeys: nil)
            if let receiveUpdate {
                for file in files where file.pathExtension == "event" {
                    do {
                        let bytes = try Data(contentsOf: file)
                        guard bytes.count < 8192 else { throw ValidationError("连接状态文件过大。") }
                        let update = try JSONDecoder().decode(WatchLinkUpdate.self, from: bytes)
                        try receiveUpdate(update)
                        acceptedUpdates[update.reference.requestID] = update
                        try FileManager.default.removeItem(at: file)
                    } catch { failures.append(error.localizedDescription) }
                }
            }
            for file in files where file.pathExtension == "json" {
                do {
                let envelope = try WatchWorkoutEnvelope.decode(Data(contentsOf: file))
                try receive(envelope.session)
                // Receipt tombstones in the database make replay after deletion safe.
                if WCSession.default.activationState == .activated {
                    WCSession.default.transferUserInfo(["ack": envelope.session.id.uuidString])
                    try FileManager.default.removeItem(at: file)
                }
                if live?.sessionID == envelope.session.id { live = nil }
                } catch { failures.append(error.localizedDescription) }
            }
            issue = failures.isEmpty ? nil : "部分手表记录暂未导入，接收文件已保留：\(failures[0])"
        } catch { issue = "手表记录暂未导入，已保留接收文件。\(error.localizedDescription)" }
    }
    nonisolated func session(_ session: WCSession, didReceive file: WCSessionFile) {
        // WCSession removes its temporary file after this callback returns.
        // Copy it synchronously before moving processing onto the main actor.
        let inbox = URL.applicationSupportDirectory.appending(path: "WatchInbox", directoryHint: .isDirectory)
        do {
            let size = try file.fileURL.resourceValues(forKeys: [.fileSizeKey]).fileSize ?? Int.max
            guard size <= 4 * 1024 * 1024 else { throw ValidationError("手表文件过大。") }
            try FileManager.default.createDirectory(at: inbox, withIntermediateDirectories: true)
            let target = inbox.appending(path: "\(UUID().uuidString).json")
            try FileManager.default.copyItem(at: file.fileURL, to: target)
            try FileManager.default.setAttributes([.protectionKey: FileProtectionType.completeUntilFirstUserAuthentication], ofItemAtPath: target.path)
            Task { @MainActor in self.drainInbox() }
        } catch { Task { @MainActor in self.issue = "暂时无法接收手表记录，手表会保留副本。\(error.localizedDescription)" } }
    }
    nonisolated func session(_ session: WCSession, activationDidCompleteWith activationState: WCSessionActivationState, error: Error?) {
        Task { @MainActor in self.refresh(); self.acceptLive(session.receivedApplicationContext); self.acceptUpdate(session.receivedApplicationContext); self.drainInbox() }
    }
    nonisolated func sessionWatchStateDidChange(_ session: WCSession) { Task { @MainActor in self.refresh() } }
    nonisolated func sessionReachabilityDidChange(_ session: WCSession) { Task { @MainActor in self.refresh() } }
    nonisolated func sessionDidBecomeInactive(_ session: WCSession) {}
    nonisolated func sessionDidDeactivate(_ session: WCSession) { session.activate() }
    nonisolated func session(_ session: WCSession, didReceiveApplicationContext applicationContext: [String: Any]) { Task { @MainActor in self.acceptLive(applicationContext); self.acceptUpdate(applicationContext) } }
    nonisolated func session(_ session: WCSession, didReceiveMessage message: [String: Any]) { Task { @MainActor in self.acceptLive(message); self.acceptUpdate(message) } }
    nonisolated func session(_ session: WCSession, didReceiveUserInfo userInfo: [String: Any] = [:]) { Task { @MainActor in self.acceptUpdate(userInfo) } }
}
