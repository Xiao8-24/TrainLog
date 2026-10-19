import Foundation
import Observation
import TrainLogCore

/// Coalesces edits; explicit close/background saves cancel older queued writes.
@MainActor @Observable final class DraftSaveController {
    enum State: Equatable { case saved(Date?), pending, failed(String) }
    private(set) var state: State = .saved(nil)
    @ObservationIgnored private var lastSaved: Session
    @ObservationIgnored private var queued: Session?
    @ObservationIgnored private var task: Task<Void, Never>?
    @ObservationIgnored private var stopped = false
    @ObservationIgnored private let delay: Duration
    @ObservationIgnored private var savedAt: Date?

    init(saved: Session, delay: Duration = .milliseconds(500)) {
        lastSaved = saved; self.delay = delay
    }
    var message: String {
        switch state {
        case .saved(let date): return date.map { "草稿已保存 · \($0.formatted(date: .omitted, time: .shortened))" } ?? "草稿保存在本机"
        case .pending: return "正在保存修改…"
        case .failed(let issue): return "当前修改尚未保存：\(issue)"
        }
    }
    func schedule(_ session: Session, save: @escaping (Session) throws -> Void) {
        guard !stopped, session.status == .draft else { return }
        if session == lastSaved {
            cancelPending(); transition(.saved(savedAt)); return
        }
        if queued == session { return }
        cancelPending()
        do { try RecordValidator.session(session) }
        catch { transition(.failed(error.localizedDescription)); return }
        queued = session; transition(.pending)
        task = Task { [weak self, delay] in
            do { try await Task.sleep(for: delay); try Task.checkCancellation() } catch { return }
            guard let self, !self.stopped else { return }
            do { try self.flush(session, save: save) } catch { /* Inline status keeps the edit visible. */ }
        }
    }
    func flush(_ session: Session, save: (Session) throws -> Void) throws {
        guard !stopped, session.status == .draft else { return }
        cancelPending()
        if session == lastSaved { transition(.saved(savedAt)); return }
        do {
            try RecordValidator.session(session)
            var value = session; value.updatedAt = Date()
            try save(value)
            lastSaved = session; savedAt = value.updatedAt
            transition(.saved(savedAt))
        } catch { transition(.failed(error.localizedDescription)); throw error }
    }
    func cancelPending() { task?.cancel(); task = nil; queued = nil }
    func stop() { stopped = true; cancelPending() }
    private func transition(_ next: State) {
        // Invalid numeric edits may contain NaN: repeated view evaluations must
        // not keep publishing the same failure and restart a render/save loop.
        if state != next { state = next }
    }
}
