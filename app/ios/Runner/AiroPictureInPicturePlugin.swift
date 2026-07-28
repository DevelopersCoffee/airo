import AVKit
import Flutter

/// Wraps AVPictureInPictureController for the com.airo.player/picture_in_picture
/// channel. The pinned video_player_avfoundation fork publishes the exact
/// AVPlayerLayer it already owns. PiP reuses that layer and never constructs a
/// second player or duplicates the stream.
final class AiroPictureInPicturePlugin: NSObject, AVPictureInPictureControllerDelegate {
  static let channelName = "com.airo.player/picture_in_picture"

  private var channel: FlutterMethodChannel?
  private weak var playerLayer: AVPlayerLayer?
  private var pipController: AVPictureInPictureController?
  private var autoEnterEnabled = false

  deinit {
    NotificationCenter.default.removeObserver(self)
  }

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
    NotificationCenter.default.addObserver(
      self,
      selector: #selector(onPlayerLayerUnavailable(_:)),
      name: NSNotification.Name("AiroPlayerLayerUnavailable"),
      object: nil
    )
  }

  @objc private func onPlayerLayerAvailable(_ notification: Notification) {
    guard let layer = notification.object as? AVPlayerLayer else { return }
    attach(to: layer)
  }

  @objc private func onPlayerLayerUnavailable(_ notification: Notification) {
    guard
      let layer = notification.object as? AVPlayerLayer,
      playerLayer === layer
    else {
      return
    }
    detachController()
    playerLayer = nil
  }

  private func attach(to layer: AVPlayerLayer) {
    if playerLayer === layer { return }
    detachController()
    guard let controller = AVPictureInPictureController(playerLayer: layer) else {
      playerLayer = nil
      return
    }
    controller.delegate = self
    if #available(iOS 14.2, *) {
      controller.canStartPictureInPictureAutomaticallyFromInline = autoEnterEnabled
    }
    playerLayer = layer
    pipController = controller
  }

  private func detachController() {
    guard let controller = pipController else { return }
    let wasActive = controller.isPictureInPictureActive
    pipController = nil
    if wasActive {
      controller.stopPictureInPicture()
      channel?.invokeMethod("pictureInPictureStateChanged", arguments: false)
    }
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
    case "setAutoEnterEnabled":
      let arguments = call.arguments as? [String: Any]
      autoEnterEnabled = arguments?["enabled"] as? Bool ?? false
      if #available(iOS 14.2, *) {
        pipController?.canStartPictureInPictureAutomaticallyFromInline = autoEnterEnabled
      }
      result(nil)
    case "isActive":
      result(pipController?.isPictureInPictureActive ?? false)
    default:
      result(FlutterMethodNotImplemented)
    }
  }

  func pictureInPictureControllerDidStartPictureInPicture(_ controller: AVPictureInPictureController) {
    guard pipController === controller else { return }
    channel?.invokeMethod("pictureInPictureStateChanged", arguments: true)
  }

  func pictureInPictureControllerDidStopPictureInPicture(_ controller: AVPictureInPictureController) {
    guard pipController === controller else { return }
    channel?.invokeMethod("pictureInPictureStateChanged", arguments: false)
  }

  func pictureInPictureController(
    _ controller: AVPictureInPictureController,
    failedToStartPictureInPictureWithError error: Error
  ) {
    guard pipController === controller else { return }
    channel?.invokeMethod("pictureInPictureStateChanged", arguments: false)
  }

  func pictureInPictureController(
    _ pictureInPictureController: AVPictureInPictureController,
    restoreUserInterfaceForPictureInPictureStopWithCompletionHandler completionHandler:
      @escaping (Bool) -> Void
  ) {
    completionHandler(true)
  }
}
