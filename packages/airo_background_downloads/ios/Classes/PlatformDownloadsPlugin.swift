import Flutter
import Foundation
import UIKit

public final class PlatformDownloadsPlugin: NSObject, FlutterPlugin, FlutterStreamHandler {
  private static let methodChannelName = "dev.airo.platform_downloads/methods"
  private static let eventChannelName = "dev.airo.platform_downloads/events"

  private let store = DownloadStateStore()
  private let resumeDataStore = DownloadResumeDataStore()
  private let fileManager = FileManager.default
  private let activeLock = NSLock()
  private var activeRequests: [Int: StoredDownloadRequest] = [:]
  private var progressSamples: [Int: (timestamp: TimeInterval, bytes: Int64)] = [:]
  private var eventSink: FlutterEventSink?
  private var backgroundCompletionHandler: (() -> Void)?
  private lazy var session: URLSession = {
    let bundleId = Bundle.main.bundleIdentifier ?? "io.airo"
    let configuration = URLSessionConfiguration.background(
      withIdentifier: "\(bundleId).platform_downloads.v1"
    )
    configuration.httpMaximumConnectionsPerHost = 1
    configuration.waitsForConnectivity = true
    let queue = OperationQueue()
    queue.name = "io.airo.platform-downloads"
    queue.maxConcurrentOperationCount = 1
    return URLSession(configuration: configuration, delegate: self, delegateQueue: queue)
  }()

  public static func register(with registrar: FlutterPluginRegistrar) {
    let instance = PlatformDownloadsPlugin()
    let methodChannel = FlutterMethodChannel(
      name: methodChannelName,
      binaryMessenger: registrar.messenger()
    )
    let eventChannel = FlutterEventChannel(
      name: eventChannelName,
      binaryMessenger: registrar.messenger()
    )
    registrar.addMethodCallDelegate(instance, channel: methodChannel)
    registrar.addApplicationDelegate(instance)
    eventChannel.setStreamHandler(instance)
    instance.restoreBackgroundTasks()
  }

  public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    do {
      switch call.method {
      case "enqueue":
        try enqueue(arguments: call.arguments)
        result(nil)
      case "pause":
        try pause(artifactId: requiredArtifactId(call.arguments))
        result(nil)
      case "resume":
        try resume(artifactId: requiredArtifactId(call.arguments), incrementRetry: false)
        result(nil)
      case "retry":
        try resume(artifactId: requiredArtifactId(call.arguments), incrementRetry: true)
        result(nil)
      case "cancel":
        try cancel(artifactId: requiredArtifactId(call.arguments))
        result(nil)
      case "getQueue":
        result(["entries": store.orderedStates()])
      case "getAvailableBytes":
        let values = try URL(fileURLWithPath: NSHomeDirectory())
          .resourceValues(forKeys: [.volumeAvailableCapacityForImportantUsageKey])
        result(values.volumeAvailableCapacityForImportantUsage)
      default:
        result(FlutterMethodNotImplemented)
      }
    } catch let error as DownloadPluginError {
      result(FlutterError(code: error.code, message: error.message, details: nil))
    } catch {
      result(
        FlutterError(
          code: "platform_unavailable",
          message: "Download operation failed.",
          details: nil
        )
      )
    }
  }

  private func enqueue(arguments: Any?) throws {
    guard let arguments = arguments as? [String: Any],
          let artifactId = nonEmpty(arguments["artifactId"] as? String),
          let sourceText = arguments["source"] as? String,
          let source = URL(string: sourceText),
          let destinationPath = nonEmpty(arguments["destinationPath"] as? String)
    else {
      throw DownloadPluginError.invalidRequest("Required download fields are missing.")
    }
    guard artifactId.range(
      of: "^[A-Za-z0-9][A-Za-z0-9._-]{0,127}$",
      options: .regularExpression
    ) != nil else {
      throw DownloadPluginError.invalidRequest(
        "artifactId must be a safe 1-128 character identifier."
      )
    }
    try validate(source: source, destinationPath: destinationPath)
    if let expectedBytes = (arguments["expectedBytes"] as? NSNumber)?.int64Value {
      let values = try URL(fileURLWithPath: NSHomeDirectory())
        .resourceValues(forKeys: [.volumeAvailableCapacityForImportantUsageKey])
      if let availableBytes = values.volumeAvailableCapacityForImportantUsage,
         availableBytes < expectedBytes {
        throw DownloadPluginError.insufficientStorage(
          "The artifact does not fit in available storage."
        )
      }
    }
    if let state = store.state(artifactId),
       ["queued", "downloading", "paused", "verifying"].contains(state.status) {
      return
    }
    let request = StoredDownloadRequest(
      artifactId: artifactId,
      source: source,
      destinationPath: destinationPath,
      expectedBytes: (arguments["expectedBytes"] as? NSNumber)?.int64Value,
      expectedSha256: arguments["expectedSha256"] as? String,
      displayName: arguments["displayName"] as? String,
      retryCount: store.request(artifactId)?.retryCount ?? 0
    )
    store.save(request: request)
    update(
      StoredDownloadState(
        artifactId: artifactId,
        status: "queued",
        downloadedBytes: 0,
        totalBytes: request.expectedBytes ?? 0,
        speedBytesPerSecond: 0,
        retryCount: request.retryCount,
        failureCode: nil,
        failureMessage: nil,
        canResume: false
      )
    )
    scheduleNext()
  }

  private func pause(artifactId: String) throws {
    guard let request = store.request(artifactId) else { return }
    session.getAllTasks { [weak self] tasks in
      guard let self else { return }
      guard let task = tasks.first(where: { self.request(for: $0)?.artifactId == artifactId })
        as? URLSessionDownloadTask
      else {
        self.updatePaused(request: request, canResume: self.hasResumeData(artifactId))
        self.scheduleNext()
        return
      }
      task.cancel { [weak self] resumeData in
        guard let self else { return }
        if let resumeData {
          try? self.saveResumeData(resumeData, artifactId: artifactId)
        }
        self.removeActive(task.taskIdentifier)
        self.updatePaused(request: request, canResume: resumeData != nil)
        self.scheduleNext()
      }
    }
  }

  private func resume(artifactId: String, incrementRetry: Bool) throws {
    guard var request = store.request(artifactId) else {
      throw DownloadPluginError.invalidRequest("Unknown artifact.")
    }
    guard let state = store.state(artifactId),
          state.status == "paused" || state.status == "failed"
    else {
      return
    }
    if incrementRetry {
      request = StoredDownloadRequest(
        artifactId: request.artifactId,
        source: request.source,
        destinationPath: request.destinationPath,
        expectedBytes: request.expectedBytes,
        expectedSha256: request.expectedSha256,
        displayName: request.displayName,
        retryCount: request.retryCount + 1
      )
      if state.failureCode == "resume_not_supported" {
        try? resumeDataStore.remove(artifactId)
      }
      store.save(request: request, moveToEnd: state.status == "paused")
    }
    update(
      StoredDownloadState(
        artifactId: artifactId,
        status: "queued",
        downloadedBytes: state.downloadedBytes,
        totalBytes: request.expectedBytes ?? state.totalBytes,
        speedBytesPerSecond: 0,
        retryCount: request.retryCount,
        failureCode: nil,
        failureMessage: nil,
        canResume: hasResumeData(artifactId)
      )
    )
    scheduleNext()
  }

  private func cancel(artifactId: String) throws {
    guard let request = store.request(artifactId) else { return }
    try? resumeDataStore.remove(artifactId)
    update(
      StoredDownloadState(
        artifactId: artifactId,
        status: "cancelled",
        downloadedBytes: 0,
        totalBytes: request.expectedBytes ?? 0,
        speedBytesPerSecond: 0,
        retryCount: request.retryCount,
        failureCode: "cancelled",
        failureMessage: nil,
        canResume: false
      )
    )
    store.clearArtifact(artifactId)
    session.getAllTasks { [weak self] tasks in
      guard let self else { return }
      tasks.filter { self.request(for: $0)?.artifactId == artifactId }.forEach { task in
        task.cancel()
        self.removeActive(task.taskIdentifier)
      }
      self.scheduleNext()
    }
  }

  private func scheduleNext() {
    session.getAllTasks { [weak self] tasks in
      guard let self else { return }
      if tasks.contains(where: { $0.state == .running || $0.state == .suspended }) {
        return
      }
      let nextActionable = self.store.orderedStates().first(where: {
        let status = $0["status"] as? String
        return status == "failed" || status == "queued"
      })
      guard nextActionable?["status"] as? String != "failed",
      let stateMap = nextActionable,
      let artifactId = stateMap["artifactId"] as? String,
      let request = self.store.request(artifactId)
      else {
        return
      }

      let task: URLSessionDownloadTask
      if let resumeData = self.resumeDataStore.load(artifactId) {
        task = self.session.downloadTask(withResumeData: resumeData)
      } else {
        task = self.session.downloadTask(with: request.source)
      }
      task.taskDescription = self.encode(request: request)
      self.setActive(request, taskIdentifier: task.taskIdentifier)
      self.update(
        StoredDownloadState(
          artifactId: artifactId,
          status: "downloading",
          downloadedBytes: (stateMap["downloadedBytes"] as? NSNumber)?.int64Value ?? 0,
          totalBytes: request.expectedBytes ?? 0,
          speedBytesPerSecond: 0,
          retryCount: request.retryCount,
          failureCode: nil,
          failureMessage: nil,
          canResume: self.hasResumeData(artifactId)
        )
      )
      task.resume()
    }
  }

  private func validate(source: URL, destinationPath: String) throws {
    guard source.scheme?.lowercased() == "https",
          source.host?.isEmpty == false,
          source.user == nil,
          source.password == nil
    else {
      throw DownloadPluginError.invalidRequest("Source must be HTTPS without embedded credentials.")
    }
    let sandbox = URL(fileURLWithPath: NSHomeDirectory(), isDirectory: true)
      .resolvingSymlinksInPath()
    let destination = URL(fileURLWithPath: destinationPath)
      .resolvingSymlinksInPath()
    guard destination.path.hasPrefix(sandbox.path + "/") else {
      throw DownloadPluginError.invalidRequest("Destination must be inside the application sandbox.")
    }
  }

  private func updatePaused(request: StoredDownloadRequest, canResume: Bool) {
    let previous = store.state(request.artifactId)
    update(
      StoredDownloadState(
        artifactId: request.artifactId,
        status: "paused",
        downloadedBytes: previous?.downloadedBytes ?? 0,
        totalBytes: request.expectedBytes ?? previous?.totalBytes ?? 0,
        speedBytesPerSecond: 0,
        retryCount: request.retryCount,
        failureCode: nil,
        failureMessage: nil,
        canResume: canResume
      )
    )
  }

  private func update(_ state: StoredDownloadState) {
    store.update(state)
    DispatchQueue.main.async { [weak self] in
      self?.eventSink?(state.platformMap)
    }
  }

  private func requiredArtifactId(_ arguments: Any?) throws -> String {
    guard let arguments = arguments as? [String: Any],
          let artifactId = nonEmpty(arguments["artifactId"] as? String),
          artifactId.range(
            of: "^[A-Za-z0-9][A-Za-z0-9._-]{0,127}$",
            options: .regularExpression
          ) != nil
    else {
      throw DownloadPluginError.invalidRequest("artifactId is required.")
    }
    return artifactId
  }

  private func nonEmpty(_ value: String?) -> String? {
    let trimmed = value?.trimmingCharacters(in: .whitespacesAndNewlines)
    return trimmed?.isEmpty == false ? trimmed : nil
  }

  private func encode(request: StoredDownloadRequest) -> String? {
    guard let data = try? JSONEncoder().encode(request) else { return nil }
    return data.base64EncodedString()
  }

  private func request(for task: URLSessionTask) -> StoredDownloadRequest? {
    if let active = activeRequest(task.taskIdentifier) {
      return active
    }
    guard let description = task.taskDescription,
          let data = Data(base64Encoded: description),
          let request = try? JSONDecoder().decode(StoredDownloadRequest.self, from: data)
    else {
      return nil
    }
    setActive(request, taskIdentifier: task.taskIdentifier)
    return request
  }

  private func setActive(_ request: StoredDownloadRequest, taskIdentifier: Int) {
    activeLock.lock()
    activeRequests[taskIdentifier] = request
    activeLock.unlock()
  }

  private func activeRequest(_ taskIdentifier: Int) -> StoredDownloadRequest? {
    activeLock.lock()
    defer { activeLock.unlock() }
    return activeRequests[taskIdentifier]
  }

  private func removeActive(_ taskIdentifier: Int) {
    activeLock.lock()
    activeRequests.removeValue(forKey: taskIdentifier)
    progressSamples.removeValue(forKey: taskIdentifier)
    activeLock.unlock()
  }

  private func sampleSpeed(taskIdentifier: Int, totalBytes: Int64) -> Double {
    let now = Date().timeIntervalSince1970
    activeLock.lock()
    defer { activeLock.unlock() }
    let previous = progressSamples[taskIdentifier]
    progressSamples[taskIdentifier] = (now, totalBytes)
    guard let previous else { return 0 }
    let elapsed = max(0.001, now - previous.timestamp)
    return Double(max(0, totalBytes - previous.bytes)) / elapsed
  }

  private func saveResumeData(_ data: Data, artifactId: String) throws {
    try resumeDataStore.save(data, artifactId: artifactId)
  }

  private func hasResumeData(_ artifactId: String) -> Bool {
    resumeDataStore.contains(artifactId)
  }

  private func restoreBackgroundTasks() {
    session.getAllTasks { [weak self] tasks in
      guard let self else { return }
      tasks.forEach { task in
        _ = self.request(for: task)
      }
      if tasks.isEmpty {
        self.scheduleNext()
      }
    }
  }

  public func onListen(
    withArguments arguments: Any?,
    eventSink events: @escaping FlutterEventSink
  ) -> FlutterError? {
    eventSink = events
    store.orderedStates().forEach(events)
    return nil
  }

  public func onCancel(withArguments arguments: Any?) -> FlutterError? {
    eventSink = nil
    return nil
  }

  public func application(
    _ application: UIApplication,
    handleEventsForBackgroundURLSession identifier: String,
    completionHandler: @escaping () -> Void
  ) -> Bool {
    guard identifier == session.configuration.identifier else { return false }
    backgroundCompletionHandler = completionHandler
    return true
  }
}

extension PlatformDownloadsPlugin: URLSessionDownloadDelegate {
  public func urlSession(
    _ session: URLSession,
    task: URLSessionTask,
    willPerformHTTPRedirection response: HTTPURLResponse,
    newRequest request: URLRequest,
    completionHandler: @escaping (URLRequest?) -> Void
  ) {
    guard let url = request.url,
          url.scheme?.lowercased() == "https",
          url.host?.isEmpty == false,
          url.user == nil,
          url.password == nil
    else {
      completionHandler(nil)
      return
    }
    completionHandler(request)
  }

  public func urlSession(
    _ session: URLSession,
    downloadTask: URLSessionDownloadTask,
    didWriteData bytesWritten: Int64,
    totalBytesWritten: Int64,
    totalBytesExpectedToWrite: Int64
  ) {
    guard let request = request(for: downloadTask) else { return }
    let previous = store.state(request.artifactId)
    let speed = sampleSpeed(
      taskIdentifier: downloadTask.taskIdentifier,
      totalBytes: totalBytesWritten
    )
    update(
      StoredDownloadState(
        artifactId: request.artifactId,
        status: "downloading",
        downloadedBytes: totalBytesWritten,
        totalBytes: request.expectedBytes ?? max(0, totalBytesExpectedToWrite),
        speedBytesPerSecond: speed,
        retryCount: request.retryCount,
        failureCode: nil,
        failureMessage: nil,
        canResume: totalBytesWritten > 0 || previous?.canResume == true
      )
    )
  }

  public func urlSession(
    _ session: URLSession,
    downloadTask: URLSessionDownloadTask,
    didResumeAtOffset fileOffset: Int64,
    expectedTotalBytes: Int64
  ) {
    guard let request = request(for: downloadTask) else { return }
    update(
      StoredDownloadState(
        artifactId: request.artifactId,
        status: "downloading",
        downloadedBytes: fileOffset,
        totalBytes: request.expectedBytes ?? expectedTotalBytes,
        speedBytesPerSecond: 0,
        retryCount: request.retryCount,
        failureCode: nil,
        failureMessage: nil,
        canResume: fileOffset > 0
      )
    )
  }

  public func urlSession(
    _ session: URLSession,
    downloadTask: URLSessionDownloadTask,
    didFinishDownloadingTo location: URL
  ) {
    guard let request = request(for: downloadTask) else { return }
    update(
      StoredDownloadState(
        artifactId: request.artifactId,
        status: "verifying",
        downloadedBytes: downloadTask.countOfBytesReceived,
        totalBytes: request.expectedBytes ?? downloadTask.countOfBytesReceived,
        speedBytesPerSecond: 0,
        retryCount: request.retryCount,
        failureCode: nil,
        failureMessage: nil,
        canResume: false
      )
    )
    var completed = false
    do {
      let attributes = try fileManager.attributesOfItem(atPath: location.path)
      let byteCount = (attributes[.size] as? NSNumber)?.int64Value ?? 0
      if let expectedBytes = request.expectedBytes, byteCount != expectedBytes {
        throw DownloadPluginError.integrity("Downloaded byte count did not match.")
      }
      if let expectedSha256 = request.expectedSha256,
         try !DownloadIntegrity.matchesSha256(url: location, expected: expectedSha256) {
        throw DownloadPluginError.integrity("Downloaded artifact failed SHA-256 verification.")
      }
      let destination = URL(fileURLWithPath: request.destinationPath)
      try fileManager.createDirectory(
        at: destination.deletingLastPathComponent(),
        withIntermediateDirectories: true
      )
      if fileManager.fileExists(atPath: destination.path) {
        _ = try fileManager.replaceItemAt(destination, withItemAt: location)
      } else {
        try fileManager.moveItem(at: location, to: destination)
      }
      try? resumeDataStore.remove(request.artifactId)
      update(
        StoredDownloadState(
          artifactId: request.artifactId,
          status: "completed",
          downloadedBytes: byteCount,
          totalBytes: request.expectedBytes ?? byteCount,
          speedBytesPerSecond: 0,
          retryCount: request.retryCount,
          failureCode: nil,
          failureMessage: nil,
          canResume: false
        )
      )
      completed = true
    } catch let error as DownloadPluginError {
      update(
        StoredDownloadState(
          artifactId: request.artifactId,
          status: "failed",
          downloadedBytes: 0,
          totalBytes: request.expectedBytes ?? 0,
          speedBytesPerSecond: 0,
          retryCount: request.retryCount,
          failureCode: error.code,
          failureMessage: error.message,
          canResume: false
        )
      )
    } catch {
      update(
        StoredDownloadState(
          artifactId: request.artifactId,
          status: "failed",
          downloadedBytes: 0,
          totalBytes: request.expectedBytes ?? 0,
          speedBytesPerSecond: 0,
          retryCount: request.retryCount,
          failureCode: "cleanup_failed",
          failureMessage: "Downloaded artifact could not be promoted.",
          canResume: false
        )
      )
    }
    removeActive(downloadTask.taskIdentifier)
    if completed {
      scheduleNext()
    }
  }

  public func urlSession(
    _ session: URLSession,
    task: URLSessionTask,
    didCompleteWithError error: Error?
  ) {
    guard let error, let request = request(for: task) else { return }
    let nsError = error as NSError
    if nsError.code == NSURLErrorCancelled {
      removeActive(task.taskIdentifier)
      return
    }
    let resumeData = nsError.userInfo[NSURLSessionDownloadTaskResumeData] as? Data
    if let resumeData {
      try? saveResumeData(resumeData, artifactId: request.artifactId)
    }
    let previous = store.state(request.artifactId)
    update(
      StoredDownloadState(
        artifactId: request.artifactId,
        status: "failed",
        downloadedBytes: previous?.downloadedBytes ?? 0,
        totalBytes: request.expectedBytes ?? previous?.totalBytes ?? 0,
        speedBytesPerSecond: 0,
        retryCount: request.retryCount,
        failureCode: resumeData == nil && (previous?.downloadedBytes ?? 0) > 0
          ? "resume_not_supported"
          : "transport",
        failureMessage: resumeData == nil && (previous?.downloadedBytes ?? 0) > 0
          ? "The server could not resume this partial download."
          : "Download was interrupted.",
        canResume: resumeData != nil
      )
    )
    removeActive(task.taskIdentifier)
  }

  public func urlSessionDidFinishEvents(forBackgroundURLSession session: URLSession) {
    DispatchQueue.main.async { [weak self] in
      self?.backgroundCompletionHandler?()
      self?.backgroundCompletionHandler = nil
    }
  }
}

private struct DownloadPluginError: Error {
  let code: String
  let message: String

  static func invalidRequest(_ message: String) -> DownloadPluginError {
    DownloadPluginError(code: "invalid_request", message: message)
  }

  static func integrity(_ message: String) -> DownloadPluginError {
    DownloadPluginError(code: "integrity_mismatch", message: message)
  }

  static func insufficientStorage(_ message: String) -> DownloadPluginError {
    DownloadPluginError(code: "insufficient_storage", message: message)
  }
}
