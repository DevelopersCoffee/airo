import Flutter
import UIKit

public class ModelDownloadPlugin: NSObject, FlutterPlugin, URLSessionDownloadDelegate {
    private var methodChannel: FlutterMethodChannel?
    private var eventChannel: FlutterEventChannel?
    private var progressSink: FlutterEventSink?

    // Keep track of downloads: taskId -> [modelId, filePath, lastProgressTime]
    private var activeDownloads: [Int: (modelId: String, filePath: String, lastProgressTime: Double)] = [:]
    private var session: URLSession?

    public static func register(with registrar: FlutterPluginRegistrar) {
        let instance = ModelDownloadPlugin()
        instance.setupChannels(with: registrar)
    }

    private func setupChannels(with registrar: FlutterPluginRegistrar) {
        let binaryMessenger = registrar.messenger()
        methodChannel = FlutterMethodChannel(name: "com.airo.model_download", binaryMessenger: binaryMessenger)
        eventChannel = FlutterEventChannel(name: "com.airo.model_download/progress", binaryMessenger: binaryMessenger)
        
        registrar.addMethodCallDelegate(self, channel: methodChannel!)
        eventChannel?.setStreamHandler(self)
        
        let config = URLSessionConfiguration.background(withIdentifier: "io.airo.app.background_download")
        session = URLSession(configuration: config, delegate: self, delegateQueue: nil)
    }

    public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        switch call.method {
        case "startDownload":
            startDownload(call, result: result)
        case "cancelDownload":
            cancelDownload(call, result: result)
        case "getFreeDiskSpace":
            getFreeDiskSpace(result: result)
        default:
            result(FlutterMethodNotImplemented)
        }
    }

    private func startDownload(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        guard let args = call.arguments as? [String: Any],
              let modelId = args["modelId"] as? String,
              let urlString = args["url"] as? String,
              let filePath = args["filePath"] as? String,
              let url = URL(string: urlString) else {
            result(FlutterError(code: "INVALID_ARGUMENTS", message: "modelId, url, and filePath are required", details: nil))
            return
        }

        guard let session = session else {
            result(FlutterError(code: "SESSION_ERROR", message: "URLSession is not initialized", details: nil))
            return
        }

        let task = session.downloadTask(with: url)
        activeDownloads[task.taskIdentifier] = (modelId: modelId, filePath: filePath, lastProgressTime: 0.0)
        task.resume()

        // Report starting state
        updateProgress(modelId: modelId, status: "downloading", downloaded: 0, total: 0, speed: 0.0)
        result(true)
    }

    private func cancelDownload(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        guard let args = call.arguments as? [String: Any],
              let modelId = args["modelId"] as? String else {
            result(FlutterError(code: "INVALID_ARGUMENTS", message: "modelId is required", details: nil))
            return
        }

        guard let session = session else {
            result(FlutterError(code: "SESSION_ERROR", message: "URLSession is not initialized", details: nil))
            return
        }

        session.getTasksWithCompletionHandler { _, _, downloadTasks in
            for task in downloadTasks {
                if let downloadInfo = self.activeDownloads[task.taskIdentifier],
                   downloadInfo.modelId == modelId {
                    task.cancel()
                    self.activeDownloads.removeValue(forKey: task.taskIdentifier)
                    self.updateProgress(modelId: modelId, status: "cancelled", downloaded: 0, total: 0, speed: 0.0)
                }
            }
            result(true)
        }
    }

    private func getFreeDiskSpace(result: @escaping FlutterResult) {
        let fileManager = FileManager.default
        let documentDirectory = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first
        
        do {
            let values = try documentDirectory?.resourceValues(forKeys: [.volumeAvailableCapacityForImportantUsageKey])
            if let capacity = values?.volumeAvailableCapacityForImportantUsage {
                result(capacity)
            } else {
                result(FlutterError(code: "DISK_SPACE_ERROR", message: "Could not query capacity", details: nil))
            }
        } catch {
            result(FlutterError(code: "DISK_SPACE_ERROR", message: error.localizedDescription, details: nil))
        }
    }

    // MARK: - URLSessionDownloadDelegate

    public func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask, didWriteData bytesWritten: Int64, totalBytesWritten: Int64, totalBytesExpectedToWrite: Int64) {
        guard let info = activeDownloads[downloadTask.taskIdentifier] else { return }

        let currentTime = CACurrentMediaTime()
        let elapsed = currentTime - info.lastProgressTime

        // Throttle progress updates to at most once per 500ms (0.5s)
        if elapsed >= 0.5 {
            activeDownloads[downloadTask.taskIdentifier]?.lastProgressTime = currentTime
            
            // Calculate approximate speed in bytes/sec
            let speed = Double(bytesWritten) / max(elapsed, 0.001)

            updateProgress(
                modelId: info.modelId,
                status: "downloading",
                downloaded: totalBytesWritten,
                total: totalBytesExpectedToWrite,
                speed: speed
            )
        }
    }

    public func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask, didFinishDownloadingTo location: URL) {
        guard let info = activeDownloads[downloadTask.taskIdentifier] else { return }
        
        let destinationURL = URL(fileURLWithPath: info.filePath)
        
        do {
            let fileManager = FileManager.default
            if fileManager.fileExists(atPath: destinationURL.path) {
                try fileManager.removeItem(at: destinationURL)
            }
            try fileManager.createDirectory(at: destinationURL.deletingLastPathComponent(), withIntermediateDirectories: true, attributes: nil)
            try fileManager.moveItem(at: location, to: destinationURL)

            updateProgress(
                modelId: info.modelId,
                status: "completed",
                downloaded: downloadTask.countOfBytesReceived,
                total: downloadTask.countOfBytesExpectedToReceive,
                speed: 0.0
            )
        } catch {
            updateProgress(
                modelId: info.modelId,
                status: "failed",
                downloaded: 0,
                total: 0,
                speed: 0.0,
                error: error.localizedDescription
            )
        }
        
        activeDownloads.removeValue(forKey: downloadTask.taskIdentifier)
    }

    public func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
        guard let info = activeDownloads[task.taskIdentifier] else { return }
        
        if let error = error {
            let nsError = error as NSError
            if nsError.code != NSURLErrorCancelled {
                updateProgress(
                    modelId: info.modelId,
                    status: "failed",
                    downloaded: 0,
                    total: 0,
                    speed: 0.0,
                    error: error.localizedDescription
                )
            }
        }
        
        activeDownloads.removeValue(forKey: task.taskIdentifier)
    }

    private func updateProgress(modelId: String, status: String, downloaded: Int64, total: Int64, speed: Double, error: String? = nil) {
        guard let sink = progressSink else { return }
        
        let payload: [String: Any] = [
            "modelId": modelId,
            "status": status,
            "downloadedBytes": downloaded,
            "totalBytes": total,
            "speedBytesPerSecond": speed,
            "error": error as Any
        ]
        
        DispatchQueue.main.async {
            sink(payload)
        }
    }
}

// MARK: - FlutterStreamHandler
extension ModelDownloadPlugin: FlutterStreamHandler {
    public func onListen(withArguments arguments: Any?, eventSink events: @escaping FlutterEventSink) -> FlutterError? {
        progressSink = events
        return nil
    }

    public func onCancel(withArguments arguments: Any?) -> FlutterError? {
        progressSink = nil
        return nil
    }
}
