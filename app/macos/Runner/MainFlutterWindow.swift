import Cocoa
import FlutterMacOS

class MainFlutterWindow: NSWindow {
  private var fullscreenChannel: FlutterMethodChannel?
  private var fullscreenExitObserver: NSObjectProtocol?

  deinit {
    if let fullscreenExitObserver {
      NotificationCenter.default.removeObserver(fullscreenExitObserver)
    }
  }

  override func awakeFromNib() {
    let flutterViewController = FlutterViewController()
    let windowFrame = self.frame
    self.contentViewController = flutterViewController
    self.setFrame(windowFrame, display: true)

    RegisterGeneratedPlugins(registry: flutterViewController)
    configureFullscreenChannel(flutterViewController: flutterViewController)

    super.awakeFromNib()
  }

  private func configureFullscreenChannel(flutterViewController: FlutterViewController) {
    let channel = FlutterMethodChannel(
      name: "com.developerscoffee.airo.window/fullscreen",
      binaryMessenger: flutterViewController.engine.binaryMessenger)
    fullscreenChannel = channel
    fullscreenExitObserver = NotificationCenter.default.addObserver(
      forName: NSWindow.didExitFullScreenNotification,
      object: self,
      queue: .main
    ) { [weak self] _ in
      self?.fullscreenChannel?.invokeMethod("nativeFullscreenExited", arguments: nil)
    }

    channel.setMethodCallHandler { [weak self] call, result in
      guard let window = self else {
        result(FlutterError(
          code: "window_unavailable",
          message: "Main window is unavailable",
          details: nil))
        return
      }

      DispatchQueue.main.async {
        switch call.method {
        case "enterFullscreen":
          if !window.styleMask.contains(.fullScreen) {
            window.toggleFullScreen(nil)
          }
          result(nil)
        case "exitFullscreen":
          if window.styleMask.contains(.fullScreen) {
            window.toggleFullScreen(nil)
          }
          result(nil)
        case "toggleFullscreen":
          window.toggleFullScreen(nil)
          result(nil)
        case "isFullscreen":
          result(window.styleMask.contains(.fullScreen))
        default:
          result(FlutterMethodNotImplemented)
        }
      }
    }
  }
}
