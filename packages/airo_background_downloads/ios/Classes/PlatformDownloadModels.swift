import Foundation

struct StoredDownloadRequest: Codable {
  let artifactId: String
  let source: URL
  let destinationPath: String
  let expectedBytes: Int64?
  let expectedSha256: String?
  let displayName: String?
  let retryCount: Int
}

struct StoredDownloadState: Codable {
  let artifactId: String
  var status: String
  var downloadedBytes: Int64
  var totalBytes: Int64
  var speedBytesPerSecond: Double
  var retryCount: Int
  var failureCode: String?
  var failureMessage: String?
  var canResume: Bool

  var platformMap: [String: Any] {
    var output: [String: Any] = [
      "artifactId": artifactId,
      "status": status,
      "downloadedBytes": downloadedBytes,
      "totalBytes": totalBytes,
      "speedBytesPerSecond": speedBytesPerSecond,
      "retryCount": retryCount,
      "canResume": canResume
    ]
    if let failureCode {
      output["failureCode"] = failureCode
    }
    if let failureMessage {
      output["failureMessage"] = failureMessage
    }
    return output
  }
}

final class DownloadStateStore {
  private let defaults: UserDefaults
  private let encoder = JSONEncoder()
  private let decoder = JSONDecoder()
  private let lock = NSLock()

  init(defaults: UserDefaults = .standard) {
    self.defaults = defaults
  }

  func save(request: StoredDownloadRequest, moveToEnd: Bool = true) {
    lock.withLock {
      defaults.set(try? encoder.encode(request), forKey: requestKey(request.artifactId))
      if moveToEnd {
        var ids = orderUnlocked()
        ids.removeAll { $0 == request.artifactId }
        ids.append(request.artifactId)
        defaults.set(ids, forKey: Self.orderKey)
      }
    }
  }

  func request(_ artifactId: String) -> StoredDownloadRequest? {
    lock.withLock {
      guard let data = defaults.data(forKey: requestKey(artifactId)) else {
        return nil
      }
      return try? decoder.decode(StoredDownloadRequest.self, from: data)
    }
  }

  func update(_ state: StoredDownloadState) {
    lock.withLock {
      defaults.set(try? encoder.encode(state), forKey: stateKey(state.artifactId))
    }
  }

  func state(_ artifactId: String) -> StoredDownloadState? {
    lock.withLock {
      stateUnlocked(artifactId)
    }
  }

  func clearArtifact(_ artifactId: String) {
    lock.withLock {
      defaults.removeObject(forKey: requestKey(artifactId))
      defaults.removeObject(forKey: stateKey(artifactId))
      defaults.set(
        orderUnlocked().filter { $0 != artifactId },
        forKey: Self.orderKey
      )
    }
  }

  func orderedStates() -> [[String: Any]] {
    lock.withLock {
      var queuePosition = 0
      return orderUnlocked().compactMap { artifactId in
        guard let state = stateUnlocked(artifactId) else { return nil }
        var output = state.platformMap
        if state.status == "queued" {
          output["queuePosition"] = queuePosition
          queuePosition += 1
        }
        return output
      }
    }
  }

  private func orderUnlocked() -> [String] {
    defaults.stringArray(forKey: Self.orderKey) ?? []
  }

  private func stateUnlocked(_ artifactId: String) -> StoredDownloadState? {
    guard let data = defaults.data(forKey: stateKey(artifactId)) else {
      return nil
    }
    return try? decoder.decode(StoredDownloadState.self, from: data)
  }

  private func requestKey(_ artifactId: String) -> String {
    "airo.platform_downloads.v1.request.\(artifactId)"
  }

  private func stateKey(_ artifactId: String) -> String {
    "airo.platform_downloads.v1.state.\(artifactId)"
  }

  private static let orderKey = "airo.platform_downloads.v1.order"
}

extension NSLock {
  fileprivate func withLock<T>(_ operation: () -> T) -> T {
    lock()
    defer { unlock() }
    return operation()
  }
}
