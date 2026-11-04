import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

public struct SyncConflict: LocalizedError, Sendable {
    public let remoteRevision: Int
    public var errorDescription: String? { "云端已有较新的记录（版本 \(remoteRevision)）；本机资料未被覆盖。" }
}

public struct RemoteSnapshot: Sendable {
    public var revision: Int
    public var backup: Backup?
}

/// Transport only. The app must first obtain a provider-verified account token,
/// store it in Keychain, and explain health-data sync before calling push.
public struct SyncTransport {
    public let endpoint: URL
    public let token: String
    public init(endpoint: URL, token: String) throws {
        guard !token.isEmpty else { throw ValidationError("需要账户令牌。") }
        let local = endpoint.host == "localhost" || endpoint.host == "127.0.0.1"
        guard endpoint.scheme == "https" || endpoint.scheme == "http" && local else { throw ValidationError("公开同步服务必须使用 HTTPS。") }
        self.endpoint = endpoint; self.token = token
    }
    private func request(_ path: String, method: String, data: Data? = nil, revision: Int? = nil) throws -> URLRequest {
        guard let url = URL(string: path, relativeTo: endpoint)?.absoluteURL else { throw ValidationError("同步地址无效。") }
        var request = URLRequest(url: url)
        request.httpMethod = method
        request.timeoutInterval = 30
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        if let revision { request.setValue(String(revision), forHTTPHeaderField: "If-Match") }
        if let data { request.httpBody = data; request.setValue("application/json", forHTTPHeaderField: "Content-Type") }
        return request
    }
    private func perform(_ request: URLRequest, session: URLSession) async throws -> (Data, Int) {
        let (data, response) = try await session.data(for: request)
        guard data.count <= BackupService.maximumBytes, let http = response as? HTTPURLResponse else { throw ValidationError("云端响应无效或过大。") }
        return (data, http.statusCode)
    }
    public func pull(session: URLSession = .shared) async throws -> RemoteSnapshot {
        let (data, status) = try await perform(request("/v1/snapshot", method: "GET"), session: session)
        guard status == 200 else { throw ValidationError("云端读取失败：\(status)。") }
        let decoder = JSONDecoder(); decoder.dateDecodingStrategy = .iso8601
        let envelope = try decoder.decode(SnapshotEnvelope.self, from: data)
        guard envelope.revision >= 0 else { throw ValidationError("云端版本无效。") }
        if let backup = envelope.backup { try BackupService.validate(backup) }
        return RemoteSnapshot(revision: envelope.revision, backup: envelope.backup)
    }
    public func push(_ backup: Backup, expectedRevision: Int, includeHealthDetails: Bool = false, session: URLSession = .shared) async throws -> Int {
        guard expectedRevision >= 0 else { throw ValidationError("云端版本无效。") }
        if !includeHealthDetails && (!backup.bodyWeights.isEmpty || backup.sessions.contains(where: { entry in
            entry.watchLink != nil || entry.phoneLink != nil || entry.activity?.hasWatchMeasurements == true ||
            entry.activity?.activeEnergyKcal != nil || entry.activity?.averageHeartRate != nil ||
            entry.activity?.maximumHeartRate != nil || entry.activity?.heartRate.isEmpty == false
        })) { throw ValidationError("资料包含体重或 Apple Watch 测量值；同步这些健康资料前需要明确同意。") }
        let body = try BackupService.encode(backup)
        let (data, status) = try await perform(request("/v1/snapshot", method: "PUT", data: body, revision: expectedRevision), session: session)
        let revision = try JSONDecoder().decode(RevisionResponse.self, from: data).revision
        if status == 409 { throw SyncConflict(remoteRevision: revision) }
        guard status == 200, revision > expectedRevision else { throw ValidationError("云端保存失败：\(status)。") }
        return revision
    }
}

private struct SnapshotEnvelope: Decodable { let revision: Int; let backup: Backup? }
private struct RevisionResponse: Decodable { let revision: Int }
