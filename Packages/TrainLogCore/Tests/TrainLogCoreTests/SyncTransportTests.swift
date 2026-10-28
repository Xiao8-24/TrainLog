import Foundation
import XCTest
@testable import TrainLogCore
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

private final class MockSyncProtocol: URLProtocol {
    static var responseStatus = 409
    static var responseBody = Data("{\"revision\":2}".utf8)
    static var lastRequest: URLRequest?
    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }
    override func startLoading() {
        Self.lastRequest = request
        let response = HTTPURLResponse(url: request.url!, statusCode: Self.responseStatus, httpVersion: nil, headerFields: ["Content-Type": "application/json"])!
        client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
        client?.urlProtocol(self, didLoad: Self.responseBody)
        client?.urlProtocolDidFinishLoading(self)
    }
    override func stopLoading() {}
}

final class SyncTransportTests: XCTestCase {
    private func backup() -> Backup {
        Backup(sessions: [], exercises: ExerciseCatalog.exercises, templates: ExerciseCatalog.templates, bodyWeights: [], settings: Settings())
    }
    private func session() -> URLSession {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [MockSyncProtocol.self]
        return URLSession(configuration: configuration)
    }
    func testRejectsUnencryptedPublicEndpoint() {
        XCTAssertThrowsError(try SyncTransport(endpoint: URL(string: "http://example.com")!, token: "token"))
        XCTAssertNoThrow(try SyncTransport(endpoint: URL(string: "http://127.0.0.1:8787")!, token: "token"))
    }
    func testConflictLeavesRemoteRevisionVisibleToCaller() async throws {
        let transport = try SyncTransport(endpoint: URL(string: "https://sync.example.com")!, token: "token")
        let session = session(); defer { session.invalidateAndCancel() }
        MockSyncProtocol.lastRequest = nil
        MockSyncProtocol.responseStatus = 409
        MockSyncProtocol.responseBody = Data("{\"revision\":2}".utf8)
        do {
            _ = try await transport.push(backup(), expectedRevision: 1, session: session)
            XCTFail("A stale revision must not be accepted")
        } catch let conflict as SyncConflict {
            XCTAssertEqual(conflict.remoteRevision, 2)
        }
        XCTAssertEqual(MockSyncProtocol.lastRequest?.value(forHTTPHeaderField: "If-Match"), "1")
    }
    func testHealthDataRequiresExplicitChoiceBeforeNetworkRequest() async throws {
        let transport = try SyncTransport(endpoint: URL(string: "https://sync.example.com")!, token: "token")
        let session = session(); defer { session.invalidateAndCancel() }
        var value = backup(); value.bodyWeights = [BodyWeight(weightKg: 70)]
        MockSyncProtocol.lastRequest = nil
        do {
            _ = try await transport.push(value, expectedRevision: 0, session: session)
            XCTFail("Health data should require consent")
        } catch let error as ValidationError {
            XCTAssertTrue(error.message.contains("明确同意"))
        }
        XCTAssertNil(MockSyncProtocol.lastRequest)
    }
}
