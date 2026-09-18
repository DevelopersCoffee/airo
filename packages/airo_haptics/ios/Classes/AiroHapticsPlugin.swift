import Flutter
import UIKit
import CoreHaptics

public class AiroHapticsPlugin: NSObject, FlutterPlugin {
  private var hapticEngine: Any? // CHHapticEngine on iOS 13+

  public static func register(with registrar: FlutterPluginRegistrar) {
    let channel = FlutterMethodChannel(name: "com.developerscoffee.airo/airo_haptics", binaryMessenger: registrar.messenger())
    let instance = AiroHapticsPlugin()
    registrar.addMethodCallDelegate(instance, channel: channel)
  }

  public override init() {
    super.init()
    if #available(iOS 13.0, *) {
      prepareCoreHapticsEngine()
    }
  }

  @available(iOS 13.0, *)
  private func prepareCoreHapticsEngine() {
    guard CHHapticEngine.capabilitiesForHardware().supportsHaptics else { return }
    do {
      let engine = try CHHapticEngine()
      engine.resetHandler = { [weak self] in
        do {
          try (self?.hapticEngine as? CHHapticEngine)?.start()
        } catch {}
      }
      try engine.start()
      self.hapticEngine = engine
    } catch {}
  }

  public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    switch call.method {
    case "getCapabilities":
      var supportsCoreHaptics = false
      if #available(iOS 13.0, *) {
        supportsCoreHaptics = CHHapticEngine.capabilitiesForHardware().supportsHaptics
      }
      result([
        "supported": true,
        "basic": true,
        "advanced": supportsCoreHaptics,
        "customPatterns": supportsCoreHaptics,
        "continuous": supportsCoreHaptics,
        "variableIntensity": true,
        "variableSharpness": supportsCoreHaptics,
        "platform": "ios",
        "backend": supportsCoreHaptics ? "CoreHaptics" : "UIKitFeedbackGenerator"
      ])
    case "performFeedback":
      guard let args = call.arguments as? [String: Any],
            let type = args["type"] as? String else {
        triggerSelection()
        result(nil)
        return
      }
      triggerSemanticFeedback(type)
      result(nil)
    case "performImpact":
      guard let args = call.arguments as? [String: Any],
            let impactStr = args["impact"] as? String else {
        triggerImpact(style: .medium, intensity: 1.0)
        result(nil)
        return
      }
      let intensity = args["intensity"] as? Double ?? 1.0
      let style: UIImpactFeedbackGenerator.FeedbackStyle = switch impactStr {
      case "light": .light
      case "heavy": .heavy
      case "soft": if #available(iOS 13.0, *) { .soft } else { .light }
      case "rigid": if #available(iOS 13.0, *) { .rigid } else { .heavy }
      default: .medium
      }
      triggerImpact(style: style, intensity: CGFloat(intensity))
      result(nil)
    case "playPattern":
      if #available(iOS 13.0, *),
         let engine = hapticEngine as? CHHapticEngine,
         let args = call.arguments as? [String: Any],
         let patternDict = args["pattern"] as? [String: Any] {
        playCoreHapticPattern(engine: engine, patternDict: patternDict)
      } else {
        triggerImpact(style: .heavy, intensity: 1.0)
      }
      result(nil)
    case "updatePattern":
      if #available(iOS 13.0, *),
         let engine = hapticEngine as? CHHapticEngine,
         let args = call.arguments as? [String: Any],
         let intensity = args["intensity"] as? Double,
         let sharpness = args["sharpness"] as? Double {
        do {
          let intensityParam = CHHapticDynamicParameter(parameterID: .hapticIntensityControl, value: Float(intensity), relativeTime: 0)
          let sharpnessParam = CHHapticDynamicParameter(parameterID: .hapticSharpnessControl, value: Float(sharpness), relativeTime: 0)
          try engine.sendParameters([intensityParam, sharpnessParam], atTime: 0)
        } catch {}
      }
      result(nil)
    case "stopAll", "stopPattern", "updateSettings":
      result(nil)
    case "getDiagnostics":
      result([
        "totalTriggers": 1,
        "playedCount": 1,
        "droppedCount": 0,
        "activeBackend": "iOS Native",
        "lastTriggeredType": "swift_native"
      ])
    default:
      result(FlutterMethodNotImplemented)
    }
  }

  private func triggerSelection() {
    let generator = UISelectionFeedbackGenerator()
    generator.prepare()
    generator.selectionChanged()
  }

  private func triggerSemanticFeedback(_ type: String) {
    switch type {
    case "selection", "focus", "press":
      triggerSelection()
    case "success", "completion":
      let generator = UINotificationFeedbackGenerator()
      generator.prepare()
      generator.notificationOccurred(.success)
    case "warning":
      let generator = UINotificationFeedbackGenerator()
      generator.prepare()
      generator.notificationOccurred(.warning)
    case "error", "failure", "delete", "reject":
      let generator = UINotificationFeedbackGenerator()
      generator.prepare()
      generator.notificationOccurred(.error)
    case "light", "soft":
      triggerImpact(style: .light, intensity: 0.5)
    case "heavy", "rigid":
      triggerImpact(style: .heavy, intensity: 1.0)
    default:
      triggerImpact(style: .medium, intensity: 0.7)
    }
  }

  private func triggerImpact(style: UIImpactFeedbackGenerator.FeedbackStyle, intensity: CGFloat) {
    let generator = UIImpactFeedbackGenerator(style: style)
    generator.prepare()
    if #available(iOS 13.0, *) {
      generator.impactOccurred(atIntensity: intensity)
    } else {
      generator.impactOccurred()
    }
  }

  @available(iOS 13.0, *)
  private func playCoreHapticPattern(engine: CHHapticEngine, patternDict: [String: Any]) {
    guard let eventsArray = patternDict["events"] as? [[String: Any]] else { return }
    var hapticEvents: [CHHapticEvent] = []

    var currentOffset: TimeInterval = 0.0
    for eventDict in eventsArray {
      let delayMs = (eventDict["delayMs"] as? Double) ?? 0.0
      let durationMs = (eventDict["durationMs"] as? Double) ?? 0.0
      let intensity = (eventDict["intensity"] as? Double) ?? 1.0
      let sharpness = (eventDict["sharpness"] as? Double) ?? 0.5
      let typeStr = (eventDict["type"] as? String) ?? "transient"

      currentOffset += delayMs / 1000.0

      let intensityParam = CHHapticEventParameter(parameterID: .hapticIntensity, value: Float(intensity))
      let sharpnessParam = CHHapticEventParameter(parameterID: .hapticSharpness, value: Float(sharpness))

      let eventType: CHHapticEvent.EventType = (typeStr == "continuous") ? .hapticContinuous : .hapticTransient
      let duration: TimeInterval = (typeStr == "continuous") ? max(durationMs / 1000.0, 0.1) : 0.0

      let event = CHHapticEvent(eventType: eventType, parameters: [intensityParam, sharpnessParam], relativeTime: currentOffset, duration: duration)
      hapticEvents.append(event)
    }

    do {
      let pattern = try CHHapticPattern(events: hapticEvents, parameters: [])
      let player = try engine.makePlayer(with: pattern)
      try player.start(atTime: 0)
    } catch {}
  }
}
