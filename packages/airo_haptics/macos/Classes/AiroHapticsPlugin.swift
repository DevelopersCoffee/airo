import FlutterMacOS
import AppKit

public class AiroHapticsPlugin: NSObject, FlutterPlugin {
  public static func register(with registrar: FlutterPluginRegistrar) {
    let channel = FlutterMethodChannel(name: "com.developerscoffee.airo/airo_haptics", binaryMessenger: registrar.messenger)
    let instance = AiroHapticsPlugin()
    registrar.addMethodCallDelegate(instance, channel: channel)
  }

  public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    let performer = NSHapticFeedbackManager.defaultPerformer

    switch call.method {
    case "getCapabilities":
      result([
        "supported": true,
        "basic": true,
        "advanced": false,
        "customPatterns": false,
        "continuous": false,
        "variableIntensity": false,
        "variableSharpness": false,
        "platform": "macOS",
        "backend": "NSHapticFeedbackManager"
      ])
    case "performFeedback":
      guard let args = call.arguments as? [String: Any],
            let type = args["type"] as? String else {
        performer.perform(.generic, performanceTime: .default)
        result(nil)
        return
      }
      let pattern: NSHapticFeedbackManager.FeedbackPattern = switch type {
      case "selection", "focus": .alignment
      case "heavy", "error", "failure", "delete": .levelChange
      default: .generic
      }
      performer.perform(pattern, performanceTime: .default)
      result(nil)
    case "performImpact":
      guard let args = call.arguments as? [String: Any],
            let impactStr = args["impact"] as? String else {
        performer.perform(.generic, performanceTime: .default)
        result(nil)
        return
      }
      let pattern: NSHapticFeedbackManager.FeedbackPattern = (impactStr == "heavy" || impactStr == "rigid") ? .levelChange : .generic
      performer.perform(pattern, performanceTime: .default)
      result(nil)
    case "playPattern":
      performer.perform(.levelChange, performanceTime: .default)
      result(nil)
    case "stopAll", "stopPattern", "updateSettings":
      result(nil)
    case "getDiagnostics":
      result([
        "totalTriggers": 1,
        "playedCount": 1,
        "droppedCount": 0,
        "activeBackend": "NSHapticFeedbackManager",
        "lastTriggeredType": "macos_native"
      ])
    default:
      result(FlutterMethodNotImplemented)
    }
  }
}
