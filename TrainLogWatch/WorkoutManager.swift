import Foundation
import HealthKit
import Observation
import WatchConnectivity
import TrainLogCore

@MainActor @Observable final class WatchWorkoutManager: NSObject, HKWorkoutSessionDelegate, HKLiveWorkoutBuilderDelegate, WCSessionDelegate {
    static let shared = WatchWorkoutManager()
    var selection: CardioActivity = .outdoorRun
    var poolLengthMeters = 25.0
    private(set) var running = false
    private(set) var paused = false
    private(set) var busy = false
    private(set) var finishing = false
    private(set) var issue: String?
    private(set) var heartRate: Double?
    private(set) var heartRateDate: Date?
    private(set) var energy: Double?
    private(set) var distance: Double?
    private(set) var elapsed = 0.0
    private(set) var elapsedUpdatedAt = Date()
    private(set) var startedAt: Date?
    private(set) var pendingCount = 0
    private(set) var hasRecovery = false
    private(set) var linkedRequest: WatchTrainingRequest?
    private var lastLinkUpdate: WatchLinkUpdate?
    private struct LinkStorage: Codable { var request: WatchTrainingRequest?; var update: WatchLinkUpdate? }
    private let linkURL = URL.applicationSupportDirectory.appending(path: "WatchConnection/link.json")
    private let health = HKHealthStore()
    private var session: HKWorkoutSession?
    private var builder: HKLiveWorkoutBuilder?
    private var record: Session?
    private var points: [HeartRatePoint] = []
    private var lastPublished = Date.distantPast
    private var completedWorkout: HKWorkout?
    private let directory = URL.applicationSupportDirectory.appending(path: "WatchOutbox", directoryHint: .isDirectory)
    private var activeURL: URL { directory.appending(path: "active.json") }
    private var finalizing = false
    private var recovering = false
    private var endedAt: Date?

    override init() {
        super.init()
        hasRecovery = FileManager.default.fileExists(atPath: activeURL.path)
        if let bytes = try? Data(contentsOf: linkURL), let saved = try? JSONDecoder().decode(LinkStorage.self, from: bytes) {
            linkedRequest = saved.request; lastLinkUpdate = saved.update
            if linkedRequest != nil { selection = .traditionalStrength }
        }
        if WCSession.isSupported() { WCSession.default.delegate = self; WCSession.default.activate() }
        refreshPending()
    }
    private var distanceType: HKQuantityType? {
        switch selection {
        case .outdoorRun, .indoorRun, .outdoorWalk, .indoorWalk, .hiking: return HKQuantityType.quantityType(forIdentifier: .distanceWalkingRunning)
        case .outdoorCycle, .indoorCycle: return HKQuantityType.quantityType(forIdentifier: .distanceCycling)
        case .swimming, .openWaterSwimming: return HKQuantityType.quantityType(forIdentifier: .distanceSwimming)
        default: return nil
        }
    }
    func prepare(_ configuration: HKWorkoutConfiguration) {
        guard linkedRequest == nil else { issue = "已连接手机训练，请开始或取消这次连接。"; return }
        guard session == nil, !busy else { issue = "请先结束当前训练。"; return }
        selection = .matching(configuration)
        // Starting remains an explicit action on the watch, including pool length.
    }
    func start() async {
        guard session == nil, !busy else { return }
        guard !hasRecovery else { issue = "请先恢复上次训练，或确认放弃未完成的恢复标记。"; recover(); return }
        guard HKHealthStore.isHealthDataAvailable() else { issue = "此设备不支持健康训练。"; return }
        if let linkedRequest {
            guard Date().timeIntervalSince(linkedRequest.requestedAt) < 86400 else { issue = "连接已过期，请先取消，再由手机重新连接。"; return }
            selection = .traditionalStrength
        }
        busy = true; issue = nil
        defer { busy = false }
        do {
            let workoutType = HKObjectType.workoutType()
            let heart = HKQuantityType.quantityType(forIdentifier: .heartRate)!
            let active = HKQuantityType.quantityType(forIdentifier: .activeEnergyBurned)!
            var share: Set<HKSampleType> = [workoutType, active]
            var read: Set<HKObjectType> = [workoutType, heart, active]
            if let distanceType { share.insert(distanceType); read.insert(distanceType) }
            try await health.requestAuthorization(toShare: share, read: read)
            guard health.authorizationStatus(for: workoutType) == .sharingAuthorized else { throw ValidationError("请允许 TrainLog 写入体能训练后再开始。") }
            let configuration = selection.workoutConfiguration
            if selection == .swimming { configuration.lapLength = HKQuantity(unit: .meter(), doubleValue: poolLengthMeters) }
            let native = try HKWorkoutSession(healthStore: health, configuration: configuration)
            let liveBuilder = native.associatedWorkoutBuilder()
            liveBuilder.dataSource = HKLiveWorkoutDataSource(healthStore: health, workoutConfiguration: configuration)
            native.delegate = self; liveBuilder.delegate = self
            let start = Date()
            var value = Session(mode: .cardio, date: start)
            value.activity = ActivityRecord(kind: selection); value.activity?.source = "appleWatch"
            value.phoneLink = linkedRequest?.reference
            try persistActive(value)
            hasRecovery = true
            try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
                liveBuilder.addMetadata([HKMetadataKeySyncIdentifier: "com.trainlog.watch.\(value.id.uuidString)", HKMetadataKeySyncVersion: 1, HKMetadataKeyWorkoutBrandName: "TrainLog"]) { success, error in
                    if let error { continuation.resume(throwing: error) }
                    else if success { continuation.resume() }
                    else { continuation.resume(throwing: ValidationError("训练标识未能保存。")) }
                }
            }
            record = value; session = native; builder = liveBuilder; startedAt = start
            points = []; heartRate = nil; heartRateDate = nil; energy = nil; distance = nil; elapsed = 0; elapsedUpdatedAt = start
            endedAt = nil; completedWorkout = nil
            native.startActivity(with: start)
            try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
                liveBuilder.beginCollection(withStart: start) { success, error in
                    if let error { continuation.resume(throwing: error) }
                    else if success { continuation.resume() }
                    else { continuation.resume(throwing: ValidationError("手表未能开始采集。")) }
                }
            }
            running = true; paused = false; publish(force: true)
            if let reference = value.phoneLink { try? persistLink(request: linkedRequest, update: WatchLinkUpdate(reference: reference, state: .recording)) }
        } catch {
            builder?.discardWorkout(); session?.end(); session = nil; builder = nil; record = nil
            running = false; issue = error.localizedDescription
            try? FileManager.default.removeItem(at: activeURL)
            hasRecovery = false
        }
    }
    func togglePause() {
        guard running, !finishing else { return }
        if paused { session?.resume() } else { session?.pause() }
    }
    func finish() {
        guard running, !finishing, !busy else { return }
        finishing = true; endedAt = Date(); session?.end()
    }
    func retrySave() {
        guard finishing else { return }
        Task { await finalize() }
    }
    private func finalize() async {
        guard !finalizing, let builder, var value = record, let end = endedAt else { return }
        finalizing = true; defer { finalizing = false }
        do {
            if completedWorkout == nil {
                if builder.endDate == nil {
                    try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
                        builder.endCollection(withEnd: end) { success, error in
                            if let error { continuation.resume(throwing: error) }
                            else if success { continuation.resume() }
                            else { continuation.resume(throwing: ValidationError("训练采集尚未结束。")) }
                        }
                    }
                }
                completedWorkout = try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<HKWorkout, Error>) in
                    builder.finishWorkout { workout, error in
                        if let error { continuation.resume(throwing: error) }
                        else if let workout { continuation.resume(returning: workout) }
                        else { continuation.resume(throwing: ValidationError("健康训练尚未保存，请重试。")) }
                    }
                }
            }
            guard let workout = completedWorkout else { return }
            let heart = HKQuantityType.quantityType(forIdentifier: .heartRate)!
            let energyType = HKQuantityType.quantityType(forIdentifier: .activeEnergyBurned)!
            let heartStats = builder.statistics(for: heart)
            value.activity?.averageHeartRate = heartStats?.averageQuantity()?.doubleValue(for: HKUnit.count().unitDivided(by: .minute()))
            value.activity?.maximumHeartRate = heartStats?.maximumQuantity()?.doubleValue(for: HKUnit.count().unitDivided(by: .minute()))
            value.activity?.activeEnergyKcal = builder.statistics(for: energyType)?.sumQuantity()?.doubleValue(for: .kilocalorie())
            if let distanceType { value.activity?.distanceMeters = builder.statistics(for: distanceType)?.sumQuantity()?.doubleValue(for: .meter()) }
            value.activity?.heartRate = points
            value.activity?.watchWorkoutID = workout.uuid
            value.manualDurationSeconds = nil; value.accumulatedSeconds = workout.duration
            value.timerStartedAt = nil; value.endTime = workout.endDate; value.updatedAt = Date(); value.status = .completed
            let envelope = WatchWorkoutEnvelope(session: value)
            try envelope.validate()
            let data = try JSONEncoder().encode(envelope)
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
            try data.write(to: directory.appending(path: "\(value.id.uuidString).json"), options: [.atomic, .completeFileProtectionUntilFirstUserAuthentication])
            if let reference = value.phoneLink { try persistLink(request: nil, update: WatchLinkUpdate(reference: reference, state: .finished)) }
            try? FileManager.default.removeItem(at: activeURL)
            hasRecovery = false
            running = false; paused = false; finishing = false; issue = nil
            session = nil; self.builder = nil; record = nil; completedWorkout = nil
            if WCSession.default.activationState == .activated {
                var context: [String: Any] = ["ended": true]
                if let update = lastLinkUpdate, let bytes = try? JSONEncoder().encode(update) { context["linkUpdate"] = bytes }
                try? WCSession.default.updateApplicationContext(context)
            }
            flush()
        } catch { issue = "训练尚未完成保存：\(error.localizedDescription)。请保留此页并重试。" }
    }
    private func persistActive(_ value: Session) throws {
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        try JSONEncoder().encode(value).write(to: activeURL, options: [.atomic, .completeFileProtectionUntilFirstUserAuthentication])
    }
    func recover() {
        guard session == nil, !recovering, FileManager.default.fileExists(atPath: activeURL.path) else { return }
        recovering = true
        health.recoverActiveWorkoutSession { native, error in
            Task { @MainActor in
                defer { self.recovering = false }
                guard let native else { await self.recoverSavedWorkout(); return }
                do {
                    let value = try JSONDecoder().decode(Session.self, from: Data(contentsOf: self.activeURL))
                    self.selection = value.activity?.kind ?? .matching(native.workoutConfiguration)
                    self.record = value; self.startedAt = native.startDate; self.session = native
                    let builder = native.associatedWorkoutBuilder()
                    builder.dataSource = HKLiveWorkoutDataSource(healthStore: self.health, workoutConfiguration: native.workoutConfiguration)
                    builder.delegate = self; native.delegate = self; self.builder = builder
                    self.running = true; self.paused = native.state == .paused; self.elapsed = builder.elapsedTime; self.elapsedUpdatedAt = Date()
                    self.issue = "已恢复训练；恢复前的心率明细保留在 Apple 健康，曲线从恢复后继续。"
                    if let reference = value.phoneLink { try? self.persistLink(request: self.linkedRequest, update: WatchLinkUpdate(reference: reference, state: .recording)) }
                    self.publish(force: true)
                } catch { self.issue = "训练恢复失败，原始数据已保留：\(error.localizedDescription)" }
            }
        }
    }
    private func recoverSavedWorkout() async {
        do {
            var value = try JSONDecoder().decode(Session.self, from: Data(contentsOf: activeURL))
            let predicate = NSCompoundPredicate(andPredicateWithSubpredicates: [
                HKQuery.predicateForObjects(withMetadataKey: HKMetadataKeySyncIdentifier, allowedValues: ["com.trainlog.watch.\(value.id.uuidString)"]),
                HKQuery.predicateForObjects(from: HKSource.default())
            ])
            let workout: HKWorkout? = try await withCheckedThrowingContinuation { continuation in
                health.execute(HKSampleQuery(sampleType: HKObjectType.workoutType(), predicate: predicate, limit: 1, sortDescriptors: nil) { _, samples, error in
                    if let error { continuation.resume(throwing: error) }
                    else { continuation.resume(returning: samples?.first as? HKWorkout) }
                })
            }
            guard let workout else { issue = "上次训练没有找到已保存的健康结果。原始恢复文件已保留，可重试恢复。"; return }
            selection = value.activity?.kind ?? .mixedCardio
            value.activity?.watchWorkoutID = workout.uuid
            let heart = HKQuantityType.quantityType(forIdentifier: .heartRate)!
            let energy = HKQuantityType.quantityType(forIdentifier: .activeEnergyBurned)!
            value.activity?.averageHeartRate = workout.statistics(for: heart)?.averageQuantity()?.doubleValue(for: HKUnit.count().unitDivided(by: .minute()))
            value.activity?.maximumHeartRate = workout.statistics(for: heart)?.maximumQuantity()?.doubleValue(for: HKUnit.count().unitDivided(by: .minute()))
            value.activity?.activeEnergyKcal = workout.statistics(for: energy)?.sumQuantity()?.doubleValue(for: .kilocalorie())
            if let distanceType { value.activity?.distanceMeters = workout.statistics(for: distanceType)?.sumQuantity()?.doubleValue(for: .meter()) }
            value.accumulatedSeconds = workout.duration; value.manualDurationSeconds = nil; value.timerStartedAt = nil
            value.endTime = workout.endDate; value.updatedAt = Date(); value.status = .completed
            value.notes = "已从 Apple 健康恢复摘要；完整心率明细请在健康中查看。"
            let envelope = WatchWorkoutEnvelope(session: value); try envelope.validate()
            try JSONEncoder().encode(envelope).write(to: directory.appending(path: "\(value.id.uuidString).json"), options: [.atomic, .completeFileProtectionUntilFirstUserAuthentication])
            if let reference = value.phoneLink { try persistLink(request: nil, update: WatchLinkUpdate(reference: reference, state: .finished)) }
            try FileManager.default.removeItem(at: activeURL)
            hasRecovery = false
            issue = "已恢复保存的健康训练摘要。"; flush()
        } catch { issue = "训练恢复文件已保留：\(error.localizedDescription)" }
    }
    private func collect(_ types: Set<HKSampleType>) {
        guard let builder, running, !finishing else { return }
        elapsed = builder.elapsedTime
        elapsedUpdatedAt = Date()
        let heart = HKQuantityType.quantityType(forIdentifier: .heartRate)!
        if types.contains(heart), !paused, let stats = builder.statistics(for: heart), let quantity = stats.mostRecentQuantity() {
            let bpm = quantity.doubleValue(for: HKUnit.count().unitDivided(by: .minute()))
            let date = stats.mostRecentQuantityDateInterval()?.end ?? Date()
            if bpm.isFinite, (20...300).contains(bpm), date != heartRateDate {
                heartRate = bpm; heartRateDate = date
                // Bounded sampling retains up to a full day at >=10-second spacing.
                if points.last.map({ date.timeIntervalSince($0.date) >= 10 }) ?? true {
                    if points.count < 10_000 { points.append(HeartRatePoint(date: date, bpm: bpm)) }
                }
            }
        }
        let energyType = HKQuantityType.quantityType(forIdentifier: .activeEnergyBurned)!
        energy = builder.statistics(for: energyType)?.sumQuantity()?.doubleValue(for: .kilocalorie())
        if let distanceType { distance = builder.statistics(for: distanceType)?.sumQuantity()?.doubleValue(for: .meter()) }
        publish(force: false)
    }
    private func persistLink(request: WatchTrainingRequest?, update: WatchLinkUpdate) throws {
        try FileManager.default.createDirectory(at: linkURL.deletingLastPathComponent(), withIntermediateDirectories: true)
        let bytes = try JSONEncoder().encode(LinkStorage(request: request, update: update))
        try bytes.write(to: linkURL, options: [.atomic, .completeFileProtectionUntilFirstUserAuthentication])
        linkedRequest = request; lastLinkUpdate = update
        sendLinkState()
    }
    private func sendLinkState() {
        guard WCSession.default.activationState == .activated, let update = lastLinkUpdate,
              let bytes = try? JSONEncoder().encode(update) else { return }
        let message: [String: Any] = ["linkUpdate": bytes]
        if !WCSession.default.outstandingUserInfoTransfers.contains(where: { $0.userInfo["linkUpdate"] as? Data == bytes }) {
            WCSession.default.transferUserInfo(message)
        }
        var context = WCSession.default.applicationContext; context["linkUpdate"] = bytes
        try? WCSession.default.updateApplicationContext(context)
        if WCSession.default.isReachable { WCSession.default.sendMessage(message, replyHandler: nil, errorHandler: nil) }
    }
    private func handle(_ command: WatchLinkCommand) throws -> WatchLinkUpdate {
        try command.request.validate()
        let reference = command.request.reference
        if let last = lastLinkUpdate, last.reference == reference,
           last.state == .recording || last.state == .finished || last.state == .cancelled { return last }
        switch command.kind {
        case .prepare:
            guard session == nil, !busy, !running, !hasRecovery else { throw ValidationError("请先结束或恢复当前手表训练。") }
            if let linkedRequest, linkedRequest.reference != reference { throw ValidationError("手表已准备另一场手机训练，请先取消。") }
            let update = WatchLinkUpdate(reference: reference, state: .prepared)
            try persistLink(request: command.request, update: update); selection = .traditionalStrength; issue = nil
            return update
        case .cancel:
            guard session == nil, !busy, !running, !hasRecovery else { throw ValidationError("训练已经开始，请在手表结束并保存。") }
            if let linkedRequest, linkedRequest.reference != reference { throw ValidationError("这不是手表当前准备的连接。") }
            let update = WatchLinkUpdate(reference: reference, state: .cancelled)
            try persistLink(request: nil, update: update); issue = nil
            return update
        case .status:
            guard let last = lastLinkUpdate, last.reference == reference else { throw ValidationError("手表尚未确认这次连接，请在手机重试连接。") }
            return last
        }
    }
    func cancelPreparedLink() {
        guard let linkedRequest else { return }
        do { _ = try handle(WatchLinkCommand(kind: .cancel, request: linkedRequest)) }
        catch { issue = error.localizedDescription }
    }
    func discardRecovery() {
        guard session == nil, !running, !recovering else { return }
        do {
            // Abandoning recovery cannot prove that HealthKit has no saved workout.
            // Retain ownership and reject replay of this request, but allow a new independent workout.
            if let bytes = try? Data(contentsOf: activeURL), let active = try? JSONDecoder().decode(Session.self, from: bytes),
               let reference = active.phoneLink {
                let update = lastLinkUpdate?.reference == reference ? lastLinkUpdate! : WatchLinkUpdate(reference: reference, state: .recording)
                try persistLink(request: nil, update: update)
            } else if let request = linkedRequest {
                try persistLink(request: nil, update: WatchLinkUpdate(reference: request.reference, state: .recording))
            }
            try FileManager.default.removeItem(at: activeURL); hasRecovery = false; issue = nil
        }
        catch { issue = "恢复标记尚未移除：\(error.localizedDescription)" }
    }
    private func publish(force: Bool) {
        guard let record, let startedAt, WCSession.default.activationState == .activated else { return }
        let now = Date(); guard force || now.timeIntervalSince(lastPublished) >= 5 else { return }
        lastPublished = now
        let freshHeart = heartRateDate.map { now.timeIntervalSince($0) <= 20 } == true ? heartRate : nil
        let snapshot = WatchLiveSnapshot(sessionID: record.id, kind: selection, updatedAt: now, startedAt: startedAt,
            elapsed: builder?.elapsedTime ?? elapsed, paused: paused, heartRate: paused ? nil : freshHeart, activeEnergyKcal: energy, distanceMeters: distance, phoneLink: record.phoneLink)
        guard let data = try? JSONEncoder().encode(snapshot) else { return }
        var context: [String: Any] = ["live": data]
        if let update = lastLinkUpdate, let bytes = try? JSONEncoder().encode(update) { context["linkUpdate"] = bytes }
        try? WCSession.default.updateApplicationContext(context)
        if WCSession.default.isReachable { WCSession.default.sendMessage(["live": data], replyHandler: nil, errorHandler: nil) }
    }
    private func pendingFiles() -> [URL] {
        (try? FileManager.default.contentsOfDirectory(at: directory, includingPropertiesForKeys: nil).filter { $0.pathExtension == "json" && $0.lastPathComponent != "active.json" }) ?? []
    }
    private func refreshPending() { pendingCount = pendingFiles().count }
    func flush() {
        refreshPending()
        guard WCSession.default.activationState == .activated else { return }
        let queued = Set(WCSession.default.outstandingFileTransfers.map { $0.file.fileURL.lastPathComponent })
        for file in pendingFiles() where !queued.contains(file.lastPathComponent) {
            WCSession.default.transferFile(file, metadata: ["trainlog": 1])
        }
    }
    nonisolated func workoutSession(_ workoutSession: HKWorkoutSession, didChangeTo toState: HKWorkoutSessionState, from fromState: HKWorkoutSessionState, date: Date) {
        Task { @MainActor in
            self.paused = toState == .paused
            self.elapsed = self.builder?.elapsedTime ?? self.elapsed; self.elapsedUpdatedAt = Date()
            if toState == .ended, self.record != nil {
                self.finishing = true; self.endedAt = self.endedAt ?? date; await self.finalize()
            }
            else { self.publish(force: true) }
        }
    }
    nonisolated func workoutSession(_ workoutSession: HKWorkoutSession, didFailWithError error: Error) { Task { @MainActor in self.issue = "系统训练发生错误：\(error.localizedDescription)" } }
    nonisolated func workoutBuilderDidCollectEvent(_ workoutBuilder: HKLiveWorkoutBuilder) {}
    nonisolated func workoutBuilder(_ workoutBuilder: HKLiveWorkoutBuilder, didCollectDataOf collectedTypes: Set<HKSampleType>) { Task { @MainActor in self.collect(collectedTypes) } }
    nonisolated func session(_ session: WCSession, activationDidCompleteWith activationState: WCSessionActivationState, error: Error?) { Task { @MainActor in self.flush(); self.sendLinkState() } }
    nonisolated func sessionReachabilityDidChange(_ session: WCSession) { Task { @MainActor in self.flush(); self.publish(force: true); self.sendLinkState() } }
    nonisolated func session(_ session: WCSession, didReceiveMessage message: [String: Any], replyHandler: @escaping ([String: Any]) -> Void) {
        guard let bytes = message["linkCommand"] as? Data, bytes.count < 8192 else { replyHandler(["error": "不支持的连接请求。"]); return }
        Task { @MainActor in
            do {
                let command = try JSONDecoder().decode(WatchLinkCommand.self, from: bytes)
                let update = try self.handle(command)
                replyHandler(["linkUpdate": try JSONEncoder().encode(update)])
            } catch { replyHandler(["error": error.localizedDescription]) }
        }
    }
    nonisolated func session(_ session: WCSession, didReceiveUserInfo userInfo: [String: Any] = [:]) {
        guard let raw = userInfo["ack"] as? String, let id = UUID(uuidString: raw) else { return }
        Task { @MainActor in
            let file = self.directory.appending(path: "\(id.uuidString).json")
            guard FileManager.default.fileExists(atPath: file.path) else { return }
            do { try FileManager.default.removeItem(at: file); self.refreshPending() }
            catch { self.issue = "手机已接收，手表副本暂未清理，可稍后重试。" }
        }
    }
    nonisolated func session(_ session: WCSession, didFinish fileTransfer: WCSessionFileTransfer, error: Error?) {
        if let error { Task { @MainActor in self.issue = "手机暂未接收，记录已留在手表：\(error.localizedDescription)" } }
    }
}
