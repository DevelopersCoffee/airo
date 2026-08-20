import Flutter
import UIKit

@main
@objc class AppDelegate: FlutterAppDelegate {
  private let pictureInPicturePlugin = AiroPictureInPicturePlugin()
  private let backgroundAudioPlugin = AiroBackgroundAudioPlugin()
  private let mediaAssetAnalyzerPlugin = AiroMediaAssetAnalyzerPlugin()

  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    GeneratedPluginRegistrant.register(with: self)

    if let registrar = registrar(forPlugin: "AiroAppDelegate") {
      let messenger = registrar.messenger()
      pictureInPicturePlugin.register(with: messenger)
      backgroundAudioPlugin.register(with: messenger)
      mediaAssetAnalyzerPlugin.register(with: messenger)
    }

    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }
}
