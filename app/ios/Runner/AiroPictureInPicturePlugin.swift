import AVKit
import Flutter

/// Wraps AVPictureInPictureController for the com.airo.player/picture_in_picture
/// channel. Airo's live player renders via a native AVPlayerLayer reachable
/// through NotificationCenter (posted by the platform_media MPV/AVPlayer
/// bridge) — this plugin listens for that layer becoming available rather
/// than owning player construction itself, since platform_media already
/// owns the player lifecycle.
final class AiroPictureInPicturePlugin: NSObject, AVPictureInPictureControllerDelegate {
  static let channelName = "com.airo.player/picture_in_picture"

  private var channel: FlutterMethodChannel?
  private var pipController: AVPictureInPictureController?

  func register(with messenger: FlutterBinaryMessenger) {
    let channel = FlutterMethodChannel(name: Self.channelName, binaryMessenger: messenger)
    channel.setMethodCallHandler { [weak self] call, result in
      self?.handle(call, result: result)
    }
    self.channel = channel

    NotificationCenter.default.addObserver(
      self,
      selector: #selector(onPlayerLayerAvailable(_:)),
      name: NSNotification.Name("AiroPlayerLayerAvailable"),
      object: nil
    )
  }

  @objc private func onPlayerLayerAvailable(_ notification: Notification) {
    guard let layer = notification.object as? AVPlayerLayer else { return }
    pipController = AVPictureInPictureController(playerLayer: layer)
    pipController?.delegate = self
  }

  private func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    switch call.method {
    case "isSupported":
      result(AVPictureInPictureController.isPictureInPictureSupported())
    case "requestEnter":
      guard let controller = pipController, controller.isPictureInPicturePossible else {
        result(false)
        return
      }
      controller.startPictureInPicture()
      result(true)
    default:
      result(FlutterMethodNotImplemented)
    }
  }

  func pictureInPictureControllerDidStartPictureInPicture(_ controller: AVPictureInPictureController) {
    channel?.invokeMethod("pictureInPictureStateChanged", arguments: true)
  }

  func pictureInPictureControllerDidStopPictureInPicture(_ controller: AVPictureInPictureController) {
    channel?.invokeMethod("pictureInPictureStateChanged", arguments: false)
  }
}
