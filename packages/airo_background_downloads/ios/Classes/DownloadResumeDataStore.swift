import Foundation

final class DownloadResumeDataStore {
  init(
    fileManager: FileManager = .default,
    directory: URL? = nil
  ) {
    self.fileManager = fileManager
    self.directory = directory ?? fileManager.urls(
      for: .applicationSupportDirectory,
      in: .userDomainMask
    ).first!.appendingPathComponent("platform_downloads", isDirectory: true)
  }

  private let fileManager: FileManager
  private let directory: URL

  func save(_ data: Data, artifactId: String) throws {
    try fileManager.createDirectory(
      at: directory,
      withIntermediateDirectories: true
    )
    try data.write(to: url(artifactId), options: .atomic)
  }

  func load(_ artifactId: String) -> Data? {
    try? Data(contentsOf: url(artifactId))
  }

  func remove(_ artifactId: String) throws {
    let location = url(artifactId)
    if fileManager.fileExists(atPath: location.path) {
      try fileManager.removeItem(at: location)
    }
  }

  func contains(_ artifactId: String) -> Bool {
    fileManager.fileExists(atPath: url(artifactId).path)
  }

  private func url(_ artifactId: String) -> URL {
    directory.appendingPathComponent("\(artifactId).resume")
  }
}
