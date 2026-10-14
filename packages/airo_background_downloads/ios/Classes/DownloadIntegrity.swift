import CryptoKit
import Foundation

enum DownloadIntegrity {
  static func sha256(url: URL) throws -> String {
    let handle = try FileHandle(forReadingFrom: url)
    defer { try? handle.close() }

    var digest = SHA256()
    while true {
      let data = try handle.read(upToCount: 64 * 1024) ?? Data()
      if data.isEmpty { break }
      digest.update(data: data)
    }
    return digest.finalize().map { String(format: "%02x", $0) }.joined()
  }

  static func matchesSha256(url: URL, expected: String) throws -> Bool {
    try sha256(url: url).caseInsensitiveCompare(expected) == .orderedSame
  }
}
