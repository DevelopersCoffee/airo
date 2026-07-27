import Foundation
import XCTest
@testable import PlatformDownloadsNative

final class PlatformDownloadsNativeTests: XCTestCase {
  func testSha256AcceptsKnownFixtureAndRejectsMismatch() throws {
    let directory = temporaryDirectory()
    defer { try? FileManager.default.removeItem(at: directory) }
    let artifact = directory.appendingPathComponent("fixture.bin")
    try Data("airo".utf8).write(to: artifact)

    XCTAssertTrue(
      try DownloadIntegrity.matchesSha256(
        url: artifact,
        expected: "f92f191e8d784a2f82b95f4828338dd3c0c9f74b0320dd931772b42c6c5cbb63"
      )
    )
    XCTAssertFalse(
      try DownloadIntegrity.matchesSha256(
        url: artifact,
        expected: String(repeating: "0", count: 64)
      )
    )
  }

  func testResumeDataPersistsAndIsRemovedDeterministically() throws {
    let directory = temporaryDirectory()
    defer { try? FileManager.default.removeItem(at: directory) }
    let store = DownloadResumeDataStore(directory: directory)
    let data = Data([1, 2, 3, 4])

    try store.save(data, artifactId: "model-a")

    XCTAssertTrue(store.contains("model-a"))
    XCTAssertEqual(store.load("model-a"), data)

    try store.remove("model-a")
    XCTAssertFalse(store.contains("model-a"))
    XCTAssertNil(store.load("model-a"))
  }

  func testOnlyQueuedEntriesReceiveContiguousQueuePositions() {
    let suite = "platform-downloads-tests-\(UUID().uuidString)"
    let defaults = UserDefaults(suiteName: suite)!
    defer { defaults.removePersistentDomain(forName: suite) }
    let store = DownloadStateStore(defaults: defaults)
    for id in ["completed", "queued-a", "paused", "queued-b"] {
      store.save(
        request: StoredDownloadRequest(
          artifactId: id,
          source: URL(string: "https://example.com/\(id)")!,
          destinationPath: "/tmp/\(id)",
          expectedBytes: nil,
          expectedSha256: nil,
          displayName: nil,
          retryCount: 0
        )
      )
    }
    for (id, status) in [
      ("completed", "completed"),
      ("queued-a", "queued"),
      ("paused", "paused"),
      ("queued-b", "queued"),
    ] {
      store.update(
        StoredDownloadState(
          artifactId: id,
          status: status,
          downloadedBytes: 0,
          totalBytes: 0,
          speedBytesPerSecond: 0,
          retryCount: 0,
          failureCode: nil,
          failureMessage: nil,
          canResume: false
        )
      )
    }

    let entries = store.orderedStates()

    XCTAssertEqual(entries[1]["queuePosition"] as? Int, 0)
    XCTAssertNil(entries[2]["queuePosition"])
    XCTAssertEqual(entries[3]["queuePosition"] as? Int, 1)

    store.clearArtifact("queued-a")
    XCTAssertNil(store.request("queued-a"))
    XCTAssertNil(store.state("queued-a"))
    XCTAssertFalse(
      store.orderedStates().contains {
        $0["artifactId"] as? String == "queued-a"
      }
    )
  }

  private func temporaryDirectory() -> URL {
    let directory = FileManager.default.temporaryDirectory.appendingPathComponent(
      UUID().uuidString,
      isDirectory: true
    )
    try! FileManager.default.createDirectory(
      at: directory,
      withIntermediateDirectories: true
    )
    return directory
  }
}
