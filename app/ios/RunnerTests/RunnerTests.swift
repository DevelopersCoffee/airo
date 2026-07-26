import AudioToolbox
import CoreMedia
import CoreVideo
import Flutter
import UIKit
import XCTest
@testable import Runner

class RunnerTests: XCTestCase {
  func testMediaAnalyzerNormalizesSupportedAndUnknownCodecs() {
    XCTAssertEqual(
      MediaAssetFormatNormalizer.videoCodecStableId(subtype: kCMVideoCodecType_H264),
      "h264"
    )
    XCTAssertEqual(
      MediaAssetFormatNormalizer.videoCodecStableId(subtype: kCMVideoCodecType_HEVC),
      "hevc"
    )
    XCTAssertEqual(
      MediaAssetFormatNormalizer.audioCodecStableId(subtype: kAudioFormatMPEG4AAC),
      "aac"
    )
    XCTAssertEqual(
      MediaAssetFormatNormalizer.audioCodecStableId(subtype: makeFourCC("dtsc")),
      "dts"
    )
    XCTAssertEqual(
      MediaAssetFormatNormalizer.videoCodecStableId(subtype: makeFourCC("zzzz")),
      "unknown"
    )
    XCTAssertEqual(
      MediaAssetFormatNormalizer.audioCodecStableId(subtype: makeFourCC("zzzz")),
      "unknown"
    )
  }

  func testMediaAnalyzerNormalizesHdrAndExplicitUnknownTransferFunctions() {
    XCTAssertEqual(
      MediaAssetFormatNormalizer.dynamicRangeStableId(
        codec: "hevc",
        subtype: kCMVideoCodecType_HEVC,
        transferFunction: String(
          describing: kCVImageBufferTransferFunction_SMPTE_ST_2084_PQ
        )
      ),
      "hdr10"
    )
    XCTAssertEqual(
      MediaAssetFormatNormalizer.dynamicRangeStableId(
        codec: "hevc",
        subtype: kCMVideoCodecType_HEVC,
        transferFunction: "not-exposed"
      ),
      "unknown"
    )
  }

  func testMediaAnalyzerNormalizesContainerHintsWithoutOpeningTheAsset() {
    XCTAssertEqual(
      MediaAssetFormatNormalizer.containerStableId(
        mimeType: "video/mp4",
        fileName: "opaque.bin"
      ),
      "mp4"
    )
    XCTAssertEqual(
      MediaAssetFormatNormalizer.containerStableId(
        mimeType: nil,
        fileName: "movie.mkv"
      ),
      "mkv"
    )
    XCTAssertEqual(
      MediaAssetFormatNormalizer.containerStableId(
        mimeType: nil,
        fileName: "opaque"
      ),
      "unknown"
    )
  }
}
