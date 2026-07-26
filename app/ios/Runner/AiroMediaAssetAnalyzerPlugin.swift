import AVFoundation
import CoreMedia
import CoreVideo
import Darwin
import Flutter
import Foundation

final class AiroMediaAssetAnalyzerPlugin: NSObject {
  static let channelName = "com.airo.media_asset_analyzer"
  private var analysisTasks = [String: Task<Void, Never>]()

  func register(with messenger: FlutterBinaryMessenger) {
    let channel = FlutterMethodChannel(name: Self.channelName, binaryMessenger: messenger)
    channel.setMethodCallHandler { [weak self] call, result in
      self?.handle(call, result: result)
    }
  }

  private func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    if call.method == "cancel" {
      let arguments = call.arguments as? [String: Any]
      let analysisId = arguments?["analysisId"] as? String
      if let analysisId {
        analysisTasks.removeValue(forKey: analysisId)?.cancel()
      }
      result(nil)
      return
    }
    guard call.method == "analyze" else {
      result(FlutterMethodNotImplemented)
      return
    }
    guard let arguments = call.arguments as? [String: Any],
          let request = MediaAssetAnalysisRequest(arguments: arguments)
    else {
      result(
        FlutterError(
          code: "invalid_arguments",
          message: "Media asset analyzer requires assetId and filePath.",
          details: nil
        )
      )
      return
    }

    let task = Task { [weak self] in
      guard let self else { return }
      let payload = await self.analyze(request)
      await MainActor.run {
        self.analysisTasks.removeValue(forKey: request.analysisId)
        result(payload)
      }
    }
    analysisTasks[request.analysisId] = task
  }

  private func analyze(_ request: MediaAssetAnalysisRequest) async -> [String: Any] {
    let startedAt = Date()
    let startingMemoryBytes = residentMemoryBytes()
    if Task.isCancelled {
      return cancelledPayload(
        startedAt: startedAt,
        startingMemoryBytes: startingMemoryBytes,
        didUseMetadataProbe: false
      )
    }
    var warnings = OrderedStringSet()
    let container = request.containerStableId()
    let fileSizeBytes = request.fileSizeBytesHint ?? fileSize(request.filePath)
    if fileSizeBytes == nil {
      warnings.append("file_size_unavailable")
    }

    let asset = AVURLAsset(url: URL(fileURLWithPath: request.filePath))

    do {
      let duration = try await asset.load(.duration)
      let tracks = try await asset.load(.tracks)
      let durationMs = duration.isNumeric ? Int((CMTimeGetSeconds(duration) * 1000.0).rounded()) : nil
      var overallBitrate = 0
      var videoTracks = [[String: Any]]()
      var audioTracks = [[String: Any]]()
      var subtitleTracks = [[String: Any]]()

      for (index, track) in tracks.enumerated() {
        if Task.isCancelled {
          return cancelledPayload(
            startedAt: startedAt,
            startingMemoryBytes: startingMemoryBytes,
            didUseMetadataProbe: true
          )
        }
        let mediaType = track.mediaType
        let estimatedDataRate = Int((try? await track.load(.estimatedDataRate)).map { $0.rounded() } ?? 0)
        if estimatedDataRate > 0 {
          overallBitrate += estimatedDataRate
        }

        switch mediaType {
        case .video:
          let naturalSize = try? await track.load(.naturalSize)
          let formatDescriptions = try? await track.load(.formatDescriptions)
          let primaryFormatDescription = formatDescriptions?.first
          let codec = videoCodecStableId(primaryFormatDescription)
          let dynamicRange = dynamicRangeStableId(primaryFormatDescription, codec: codec)
          videoTracks.append([
            "id": "video-\(index)",
            "codec": codec,
            "width": Int(naturalSize?.width.rounded() ?? 0),
            "height": Int(naturalSize?.height.rounded() ?? 0),
            "bitrate": estimatedDataRate > 0 ? estimatedDataRate : NSNull(),
            "dynamicRange": dynamicRange,
            "confidence": "exact",
          ])
        case .audio:
          let formatDescriptions = try? await track.load(.formatDescriptions)
          let primaryFormatDescription = formatDescriptions?.first
          let locale = try? await track.load(.extendedLanguageTag)
          let commonMetadata = try? await track.load(.commonMetadata)
          audioTracks.append([
            "id": "audio-\(index)",
            "codec": audioCodecStableId(primaryFormatDescription),
            "language": locale ?? NSNull(),
            "label": trackLabel(commonMetadata) ?? NSNull(),
            "channelCount": audioChannelCount(primaryFormatDescription) ?? NSNull(),
            "isDefault": false,
            "isCommentary": false,
            "confidence": "exact",
          ])
        case .subtitle, .text, .closedCaption:
          let formatDescriptions = try? await track.load(.formatDescriptions)
          let primaryFormatDescription = formatDescriptions?.first
          let locale = try? await track.load(.extendedLanguageTag)
          let commonMetadata = try? await track.load(.commonMetadata)
          subtitleTracks.append([
            "id": "subtitle-\(index)",
            "format": subtitleFormatStableId(primaryFormatDescription, mediaType: mediaType),
            "language": locale ?? NSNull(),
            "label": trackLabel(commonMetadata) ?? NSNull(),
            "isDefault": false,
            "isForced": false,
            "isCommentary": false,
            "confidence": "exact",
          ])
        default:
          continue
        }
      }

      if durationMs == nil || durationMs == 0 {
        warnings.append("duration_unavailable")
      }
      if overallBitrate == 0, let fileSizeBytes, let durationMs, durationMs > 0 {
        overallBitrate = Int(((Double(fileSizeBytes) * 8.0) / (Double(durationMs) / 1000.0)).rounded())
        warnings.append("overall_bitrate_estimated")
      } else if overallBitrate == 0 {
        warnings.append("overall_bitrate_unavailable")
      }
      if videoTracks.allSatisfy({ ($0["codec"] as? String) == "unknown" }) {
        warnings.append("video_codec_unavailable")
      }
      if audioTracks.isEmpty {
        warnings.append("audio_tracks_unavailable")
      }
      if subtitleTracks.isEmpty {
        warnings.append("subtitle_tracks_unavailable")
      }
      if videoTracks.allSatisfy({ ($0["dynamicRange"] as? String) == "unknown" }) {
        warnings.append("hdr_unavailable")
      }

      return [
        "status": "complete",
        "profile": [
          "schemaVersion": "1.0.0",
          "assetId": request.assetId,
          "container": container,
          "durationMs": durationMs as Any,
          "fileSizeBytes": fileSizeBytes as Any,
          "overallBitrate": overallBitrate > 0 ? overallBitrate : NSNull(),
          "videoTracks": videoTracks,
          "audioTracks": audioTracks,
          "subtitleTracks": subtitleTracks,
          "warnings": warnings.values,
        ],
        "diagnostics": [
          "elapsedMs": Int(Date().timeIntervalSince(startedAt) * 1000.0),
          "didUseMetadataProbe": true,
          "fileSizeBytes": fileSizeBytes as Any,
          "estimatedBytesRead": NSNull(),
          "peakMemoryBytes": max(startingMemoryBytes, residentMemoryBytes()),
        ],
      ]
    } catch {
      if Task.isCancelled {
        return cancelledPayload(
          startedAt: startedAt,
          startingMemoryBytes: startingMemoryBytes,
          didUseMetadataProbe: true
        )
      }
      warnings.append("metadata_probe_failed")
      return [
        "status": "inspection_failed",
        "failureReason": "metadata_probe_failed",
        "profile": [
          "schemaVersion": "1.0.0",
          "assetId": request.assetId,
          "container": container,
          "durationMs": NSNull(),
          "fileSizeBytes": fileSizeBytes as Any,
          "overallBitrate": NSNull(),
          "videoTracks": [],
          "audioTracks": [],
          "subtitleTracks": [],
          "warnings": warnings.values,
        ],
        "diagnostics": [
          "elapsedMs": Int(Date().timeIntervalSince(startedAt) * 1000.0),
          "didUseMetadataProbe": true,
          "fileSizeBytes": fileSizeBytes as Any,
          "estimatedBytesRead": NSNull(),
          "peakMemoryBytes": max(startingMemoryBytes, residentMemoryBytes()),
        ],
      ]
    }
  }

  private func cancelledPayload(
    startedAt: Date,
    startingMemoryBytes: Int,
    didUseMetadataProbe: Bool
  ) -> [String: Any] {
    [
      "status": "cancelled",
      "diagnostics": [
        "elapsedMs": Int(Date().timeIntervalSince(startedAt) * 1000.0),
        "didUseMetadataProbe": didUseMetadataProbe,
        "fileSizeBytes": NSNull(),
        "estimatedBytesRead": NSNull(),
        "peakMemoryBytes": max(startingMemoryBytes, residentMemoryBytes()),
      ],
    ]
  }

  private func residentMemoryBytes() -> Int {
    var info = mach_task_basic_info()
    var count = mach_msg_type_number_t(
      MemoryLayout<mach_task_basic_info>.size / MemoryLayout<integer_t>.size
    )
    let status = withUnsafeMutablePointer(to: &info) { infoPointer in
      infoPointer.withMemoryRebound(to: integer_t.self, capacity: Int(count)) {
        task_info(
          mach_task_self_,
          task_flavor_t(MACH_TASK_BASIC_INFO),
          $0,
          &count
        )
      }
    }
    return status == KERN_SUCCESS ? Int(info.resident_size) : 0
  }

  private func fileSize(_ filePath: String) -> Int? {
    let attributes = try? FileManager.default.attributesOfItem(atPath: filePath)
    return attributes?[.size] as? Int
  }

  private func trackLabel(_ metadata: [AVMetadataItem]?) -> String? {
    metadata?
      .first(where: { $0.commonKey == .commonKeyTitle })?
      .stringValue
  }

  private func videoCodecStableId(_ description: CMFormatDescription?) -> String {
    guard let description else {
      return "unknown"
    }
    switch CMFormatDescriptionGetMediaSubType(description) {
    case kCMVideoCodecType_H264:
      return "h264"
    case kCMVideoCodecType_HEVC:
      return "hevc"
    case kCMVideoCodecType_AV1:
      return "av1"
    case kCMVideoCodecType_VP9:
      return "vp9"
    case makeFourCC("dvh1"), makeFourCC("dvhe"):
      return "hevc"
    default:
      return "unknown"
    }
  }

  private func audioCodecStableId(_ description: CMFormatDescription?) -> String {
    guard let description else {
      return "unknown"
    }
    switch CMFormatDescriptionGetMediaSubType(description) {
    case kAudioFormatMPEG4AAC, kAudioFormatMPEG4AAC_HE:
      return "aac"
    case kAudioFormatAC3:
      return "ac3"
    case kAudioFormatEnhancedAC3:
      return "eac3"
    case makeFourCC("dtsc"), makeFourCC("dtsh"), makeFourCC("dtsl"):
      return "dts"
    case kAudioFormatOpus:
      return "opus"
    case kAudioFormatMPEGLayer3:
      return "mp3"
    case makeFourCC("mlpa"):
      return "truehd"
    default:
      return "unknown"
    }
  }

  private func audioChannelCount(_ description: CMFormatDescription?) -> Int? {
    guard let description,
          let streamDescription = CMAudioFormatDescriptionGetStreamBasicDescription(description)
    else {
      return nil
    }
    return Int(streamDescription.pointee.mChannelsPerFrame)
  }

  private func subtitleFormatStableId(
    _ description: CMFormatDescription?,
    mediaType: AVMediaType
  ) -> String {
    guard let description else {
      return mediaType == .closedCaption ? "unknown" : "unknown"
    }
    switch CMFormatDescriptionGetMediaSubType(description) {
    case makeFourCC("wvtt"), makeFourCC("tx3g"):
      return "unknown"
    default:
      return "unknown"
    }
  }

  private func dynamicRangeStableId(_ description: CMFormatDescription?, codec: String) -> String {
    if codec == "hevc",
       let description,
       let extensions = CMFormatDescriptionGetExtensions(description) as? [CFString: Any],
       let transferFunction = extensions[kCVImageBufferTransferFunctionKey]
    {
      let transferFunctionValue = String(describing: transferFunction)
      switch transferFunctionValue {
      case String(describing: kCVImageBufferTransferFunction_SMPTE_ST_2084_PQ):
        return "hdr10"
      case String(describing: kCVImageBufferTransferFunction_ITU_R_2100_HLG):
        return "hlg"
      default:
        break
      }
    }
    if codec == "hevc",
       let description
    {
      let subtype = CMFormatDescriptionGetMediaSubType(description)
      if subtype == makeFourCC("dvh1") || subtype == makeFourCC("dvhe") {
        return "dolby_vision"
      }
    }
    return "unknown"
  }
}

private struct MediaAssetAnalysisRequest {
  let analysisId: String
  let assetId: String
  let filePath: String
  let fileName: String?
  let fileSizeBytesHint: Int?
  let mimeTypeHint: String?

  init?(arguments: [String: Any]) {
    guard let analysisId = arguments["analysisId"] as? String,
          let assetId = arguments["assetId"] as? String,
          let filePath = arguments["filePath"] as? String
    else {
      return nil
    }
    self.analysisId = analysisId
    self.assetId = assetId
    self.filePath = filePath
    self.fileName = arguments["fileName"] as? String
    self.fileSizeBytesHint = arguments["fileSizeBytesHint"] as? Int
    self.mimeTypeHint = arguments["mimeTypeHint"] as? String
  }

  func containerStableId() -> String {
    let mimeType = mimeTypeHint?.lowercased() ?? ""
    if mimeType.contains("matroska") || mimeType.contains("x-mkv") { return "mkv" }
    if mimeType.contains("webm") { return "webm" }
    if mimeType.contains("mp4") { return "mp4" }
    if mimeType.contains("quicktime") { return "mov" }
    if mimeType.contains("mpegts") || mimeType.contains("mp2t") { return "ts" }

    let ext = (fileName as NSString?)?.pathExtension.lowercased() ?? ""
    switch ext {
    case "mp4": return "mp4"
    case "m4v": return "m4v"
    case "mkv": return "mkv"
    case "webm": return "webm"
    case "avi": return "avi"
    case "mov": return "mov"
    case "ts": return "ts"
    case "m2ts": return "m2ts"
    case "flv": return "flv"
    case "wmv": return "wmv"
    case "vob": return "vob"
    default: return "unknown"
    }
  }
}

private struct OrderedStringSet {
  private(set) var values: [String] = []

  mutating func append(_ value: String) {
    guard !values.contains(value) else { return }
    values.append(value)
  }
}

private func makeFourCC(_ string: String) -> FourCharCode {
  string.utf8.reduce(0) { ($0 << 8) + FourCharCode($1) }
}
