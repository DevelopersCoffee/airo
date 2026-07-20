import AVFoundation
import Flutter
import MediaPlayer

/// Wraps AVAudioSession + MPNowPlayingInfoCenter for the
/// com.airo.player/background_audio_mode channel.
final class AiroBackgroundAudioPlugin: NSObject {
  static let channelName = "com.airo.player/background_audio_mode"

  func register(with messenger: FlutterBinaryMessenger) {
    let channel = FlutterMethodChannel(name: Self.channelName, binaryMessenger: messenger)
    channel.setMethodCallHandler { [weak self] call, result in
      self?.handle(call, result: result)
    }
  }

  private func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    guard call.method == "setEnabled" else {
      result(FlutterMethodNotImplemented)
      return
    }
    let args = call.arguments as? [String: Any]
    let enabled = args?["enabled"] as? Bool ?? false

    do {
      let session = AVAudioSession.sharedInstance()
      try session.setCategory(enabled ? .playback : .soloAmbient, mode: enabled ? .moviePlayback : .default)
      try session.setActive(enabled)
      result(nil)
    } catch {
      result(FlutterError(
        code: "audio_session_error",
        message: error.localizedDescription,
        details: nil
      ))
    }
  }
}
