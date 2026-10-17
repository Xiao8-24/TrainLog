import Foundation
import Observation
import TrainLogCore

@MainActor protocol HealthSyncPersistence {
    func load() throws -> HealthSyncLedger
    func save(_ ledger: HealthSyncLedger) throws
}

@MainActor final class HealthSyncFile: HealthSyncPersistence {
    private let url: URL
    init() {
        url = URL.applicationSupportDirectory.appending(path: "HealthSync/ledger.json")
    }
    func load() throws -> HealthSyncLedger {
        guard FileManager.default.fileExists(atPath: url.path) else { return HealthSyncLedger() }
        return try JSONDecoder().decode(HealthSyncLedger.self, from: Data(contentsOf: url))
    }
    func save(_ ledger: HealthSyncLedger) throws {
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        try JSONEncoder().encode(ledger).write(to: url, options: [.atomic, .completeFileProtection])
    }
}

@MainActor final class HealthSyncMemory: HealthSyncPersistence {
    var ledger = HealthSyncLedger()
    func load() throws -> HealthSyncLedger { ledger }
    func save(_ ledger: HealthSyncLedger) throws { self.ledger = ledger }
}

@MainActor @Observable final class HealthSyncCoordinator {
    static let enabledKey = "appleHealthWorkoutSyncEnabled"
    private let client: any WorkoutHealthClient
    private let persistence: any HealthSyncPersistence
    private let defaults: UserDefaults?
    private var ledger = HealthSyncLedger()
    private var loaded = false
    private var worker: Task<Void, Never>?
    private var stagingFailures: Set<UUID> = []
    private(set) var enabled: Bool
    private(set) var authorization = WorkoutHealthAuthorization.notDetermined
    private(set) var isWorking = false
    private(set) var isAuthorizing = false
    private(set) var issue: String?
    private(set) var sessionIssues: [UUID: String] = [:]
    var pendingCount: Int { Set(ledger.pending.map(\.sessionID)).union(stagingFailures).count }
    var exportedCount: Int { ledger.records.values.filter { $0.workout != nil && !$0.isPending }.count }

    init(client: any WorkoutHealthClient, persistence: any HealthSyncPersistence, defaults: UserDefaults? = nil) {
        self.client = client; self.persistence = persistence; self.defaults = defaults
        enabled = defaults?.bool(forKey: Self.enabledKey) ?? false
        // Disk/HealthKit work starts after the root view appears, not during DB
        // initialization or SwiftUI's body evaluation.
    }
    static func production() -> HealthSyncCoordinator {
        HealthSyncCoordinator(client: AppleWorkoutHealthClient(), persistence: HealthSyncFile(), defaults: .standard)
    }
    static func isolated() -> HealthSyncCoordinator {
        HealthSyncCoordinator(client: UnavailableWorkoutHealthClient(), persistence: HealthSyncMemory())
    }
    private func loadIfNeeded() -> Bool {
        guard !loaded else { return true }
        do { ledger = try persistence.load(); loaded = true; return true }
        catch { issue = "健康同步队列暂时无法读取，原文件已保留。\(error.localizedDescription)"; return false }
    }
    private func commit(_ next: HealthSyncLedger) -> Bool {
        do { try persistence.save(next); ledger = next; issue = nil; return true }
        catch { issue = "训练已保存在本机，健康同步队列暂未保存。\(error.localizedDescription)"; return false }
    }
    func refresh(sessions: [Session]) {
        authorization = client.authorization
        guard loadIfNeeded() else { return }
        reconcileManaged(sessions: sessions)
        kick()
    }
    func enable(sessions: [Session]) async {
        guard !isAuthorizing else { return }
        isAuthorizing = true
        defer { isAuthorizing = false }
        do {
            try await client.requestAuthorization()
            authorization = client.authorization
            guard authorization == .authorized else {
                issue = "尚未允许写入体能训练。可前往「健康」→个人头像→App→TrainLog 管理权限。"
                return
            }
            guard loadIfNeeded() else { return }
            enabled = true; defaults?.set(true, forKey: Self.enabledKey); issue = nil
            reconcileManaged(sessions: sessions)
            kick()
        } catch { authorization = client.authorization; issue = "未能连接 Apple 健康：\(error.localizedDescription)" }
    }
    func disable() {
        enabled = false; defaults?.set(false, forKey: Self.enabledKey)
        // An already submitted HealthKit operation may finish. No new work is
        // submitted while disconnected, and existing Health records stay put.
    }
    func track(_ session: Session) {
        guard enabled, session.status == .completed, loadIfNeeded() else { return }
        stage(session); kick()
    }
    func export(_ session: Session) {
        guard enabled, loadIfNeeded() else { return }
        stage(session); kick()
    }
    func remove(_ id: UUID) {
        stagingFailures.remove(id)
        guard loadIfNeeded(), ledger.records[id] != nil else { return }
        var next = ledger; next.remove(id)
        if commit(next) { sessionIssues.removeValue(forKey: id); kick() }
        else { stagingFailures.insert(id) }
    }
    func reconcileManaged(sessions: [Session]) {
        guard loaded else { return }
        let sessionsByID = Dictionary(uniqueKeysWithValues: sessions.map { ($0.id, $0) })
        // Reconcile only explicitly managed IDs, never silently upload an import
        // or all historical sessions when someone first grants permission.
        for id in Set(ledger.records.keys).union(stagingFailures) {
            if let session = sessionsByID[id], session.status == .completed {
                if enabled { stage(session) }
            } else { remove(id) }
        }
    }
    private func stage(_ session: Session) {
        do {
            let workout = try HealthWorkoutExport(session: session)
            var next = ledger; next.stage(workout)
            if next != ledger, !commit(next) { stagingFailures.insert(session.id); return }
            stagingFailures.remove(session.id)
            sessionIssues.removeValue(forKey: session.id)
        } catch {
            stagingFailures.remove(session.id)
            sessionIssues[session.id] = error.localizedDescription
            // An invalid edit must not leave an older queued summary to upload.
            if ledger.records[session.id] != nil {
                var next = ledger; next.remove(session.id)
                if !commit(next) { stagingFailures.insert(session.id) }
            }
        }
    }
    func retry(sessions: [Session]) {
        authorization = client.authorization
        guard enabled, loadIfNeeded() else { return }
        issue = nil; reconcileManaged(sessions: sessions); kick()
    }
    func status(for id: UUID) -> String {
        if stagingFailures.contains(id) { return "健康同步队列暂未保存，请重试" }
        if let issue = sessionIssues[id] { return issue }
        guard let record = ledger.records[id] else { return "尚未写入 Apple 健康" }
        if record.workout == nil { return "等待从 Apple 健康移除" }
        if record.isPending { return "等待写入 Apple 健康" }
        return "已写入 Apple 健康"
    }
    func isExported(_ id: UUID) -> Bool {
        guard let record = ledger.records[id] else { return false }
        return record.workout != nil && !record.isPending && sessionIssues[id] == nil
    }
    private func kick() {
        guard worker == nil, enabled, authorization == .authorized, loaded, !ledger.pending.isEmpty else { return }
        isWorking = true
        worker = Task { [weak self] in
            guard let self else { return }
            defer { self.isWorking = false; self.worker = nil }
            while self.enabled, self.client.authorization == .authorized,
                  let record = self.ledger.pending.first(where: { !self.stagingFailures.contains($0.sessionID) }) {
                do {
                    if let workout = record.workout { try await self.client.save(workout, version: record.version) }
                    else { try await self.client.delete(syncIdentifier: record.syncIdentifier) }
                    var next = self.ledger; next.acknowledge(record.sessionID, version: record.version)
                    guard self.commit(next) else { return }
                } catch {
                    self.authorization = self.client.authorization
                    self.issue = "训练已保存在本机，Apple 健康暂未同步。请检查授权后重试。\(error.localizedDescription)"
                    return
                }
            }
        }
    }
    /// Deterministic test hook; does not start or retry any work.
    func waitUntilIdle() async { await worker?.value }
}
