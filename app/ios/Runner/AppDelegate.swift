import EventKit
import EventKitUI
import Flutter
import UIKit

@main
@objc class AppDelegate: FlutterAppDelegate, EKEventEditViewDelegate {
  private let agentConnectorsChannelName = "com.airo.agent_connectors"
  private let eventStore = EKEventStore()
  private var pendingCreateEventResult: FlutterResult?

  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    GeneratedPluginRegistrant.register(with: self)

    if let controller = window?.rootViewController as? FlutterViewController {
      let channel = FlutterMethodChannel(
        name: agentConnectorsChannelName,
        binaryMessenger: controller.binaryMessenger
      )
      channel.setMethodCallHandler { [weak self] call, result in
        self?.handleAgentConnectorCall(call, result: result)
      }
    }

    // TODO: Register GeminiNanoPlugin for memory detection and device info
    // Temporarily disabled for SPM migration testing
    // if let registrar = self.registrar(forPlugin: "GeminiNanoPlugin") {
    //   GeminiNanoPlugin.register(with: registrar)
    // }

    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  private func handleAgentConnectorCall(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    switch call.method {
    case "getCalendarPermissionStatus":
      getCalendarPermissionStatus(result: result)
    case "openCalendarPermissionSettings":
      openCalendarPermissionSettings(result: result)
    case "readCalendarEvents":
      guard let arguments = call.arguments as? [String: Any],
            let date = arguments["date"] as? String,
            !date.isEmpty
      else {
        result(["error": "missing_date", "message": "Calendar lookup requires a date."])
        return
      }
      readCalendarEvents(date: date, result: result)
    case "createCalendarEvent":
      guard let arguments = call.arguments as? [String: Any] else {
        result(["error": "invalid_calendar_event", "message": "Calendar event arguments are required."])
        return
      }
      createCalendarEvent(arguments: arguments, result: result)
    default:
      result(FlutterMethodNotImplemented)
    }
  }

  private func getCalendarPermissionStatus(result: FlutterResult) {
    let status = EKEventStore.authorizationStatus(for: .event)
    result(calendarPermissionPayload(for: status))
  }

  private func calendarPermissionPayload(for status: EKAuthorizationStatus) -> [String: Any] {
    switch status {
    case .authorized:
      return ["status": "granted", "granted": true, "can_request": false]
    case .notDetermined:
      return ["status": "not_determined", "granted": false, "can_request": true]
    case .denied:
      return ["status": "denied", "granted": false, "can_request": false]
    case .restricted:
      return ["status": "restricted", "granted": false, "can_request": false]
    @unknown default:
      if #available(iOS 17.0, *) {
        if status == .fullAccess {
          return ["status": "granted", "granted": true, "can_request": false]
        }
        if status == .writeOnly {
          return ["status": "write_only", "granted": false, "can_request": false]
        }
      }
      return ["status": "unknown", "granted": false, "can_request": false]
    }
  }

  private func hasCalendarReadAccess() -> Bool {
    let status = EKEventStore.authorizationStatus(for: .event)
    if status == .authorized { return true }
    if #available(iOS 17.0, *) {
      return status == .fullAccess
    }
    return false
  }

  private func hasCalendarWriteAccess() -> Bool {
    let status = EKEventStore.authorizationStatus(for: .event)
    if status == .authorized { return true }
    if #available(iOS 17.0, *) {
      return status == .fullAccess || status == .writeOnly
    }
    return false
  }

  private func requestCalendarReadAccess(result: @escaping (Bool) -> Void) {
    if #available(iOS 17.0, *) {
      eventStore.requestFullAccessToEvents { granted, _ in
        DispatchQueue.main.async { result(granted) }
      }
    } else {
      eventStore.requestAccess(to: .event) { granted, _ in
        DispatchQueue.main.async { result(granted) }
      }
    }
  }

  private func requestCalendarWriteAccess(result: @escaping (Bool) -> Void) {
    if #available(iOS 17.0, *) {
      eventStore.requestWriteOnlyAccessToEvents { granted, _ in
        DispatchQueue.main.async { result(granted) }
      }
    } else {
      eventStore.requestAccess(to: .event) { granted, _ in
        DispatchQueue.main.async { result(granted) }
      }
    }
  }

  private func readCalendarEvents(date: String, result: @escaping FlutterResult) {
    if !hasCalendarReadAccess() {
      requestCalendarReadAccess { [weak self] granted in
        guard let self else { return }
        if granted {
          self.readCalendarEvents(date: date, result: result)
        } else {
          result([
            "error": "calendar_permission_denied",
            "message": "Calendar permission is required to check your schedule."
          ])
        }
      }
      return
    }

    let dateFormatter = DateFormatter()
    dateFormatter.calendar = Calendar(identifier: .gregorian)
    dateFormatter.locale = Locale(identifier: "en_US_POSIX")
    dateFormatter.dateFormat = "yyyy-MM-dd"
    guard let day = dateFormatter.date(from: date),
          let end = Calendar.current.date(byAdding: .day, value: 1, to: day)
    else {
      result(["error": "invalid_date", "message": "Calendar date must use YYYY-MM-DD."])
      return
    }

    let predicate = eventStore.predicateForEvents(withStart: day, end: end, calendars: nil)
    let events = eventStore.events(matching: predicate).sorted { $0.startDate < $1.startDate }
    let outputFormatter = ISO8601DateFormatter()
    let payload = events.map { event in
      [
        "title": event.title ?? "Untitled event",
        "start": outputFormatter.string(from: event.startDate),
        "end": outputFormatter.string(from: event.endDate),
        "calendar": event.calendar.title
      ]
    }
    result(["date": date, "events": payload])
  }

  private func createCalendarEvent(arguments: [String: Any], result: @escaping FlutterResult) {
    guard let title = arguments["title"] as? String, !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
          let startRaw = arguments["start"] as? String,
          let endRaw = arguments["end"] as? String
    else {
      result(["error": "invalid_calendar_event", "message": "Calendar event requires title, start, and end."])
      return
    }

    let parser = ISO8601DateFormatter()
    guard let start = parser.date(from: startRaw),
          let end = parser.date(from: endRaw),
          end > start
    else {
      result([
        "error": "invalid_calendar_event_time",
        "message": "Calendar event times must use ISO-8601 and end after start."
      ])
      return
    }

    if !hasCalendarWriteAccess() {
      requestCalendarWriteAccess { [weak self] granted in
        guard let self else { return }
        if granted {
          self.createCalendarEvent(arguments: arguments, result: result)
        } else {
          result([
            "error": "calendar_permission_denied",
            "message": "Calendar permission is required to create events."
          ])
        }
      }
      return
    }

    guard let controller = window?.rootViewController else {
      result(["error": "calendar_ui_unavailable", "message": "Calendar confirmation UI is unavailable."])
      return
    }

    let event = EKEvent(eventStore: eventStore)
    event.title = title
    event.startDate = start
    event.endDate = end
    event.notes = arguments["description"] as? String
    event.location = arguments["location"] as? String
    event.calendar = eventStore.defaultCalendarForNewEvents

    let editController = EKEventEditViewController()
    editController.eventStore = eventStore
    editController.event = event
    editController.editViewDelegate = self
    pendingCreateEventResult = result
    controller.present(editController, animated: true)
  }

  private func openCalendarPermissionSettings(result: FlutterResult) {
    guard let url = URL(string: UIApplication.openSettingsURLString) else {
      result(["error": "settings_unavailable", "message": "Settings URL is unavailable."])
      return
    }
    UIApplication.shared.open(url) { opened in
      result(["opened": opened])
    }
  }

  func eventEditViewController(
    _ controller: EKEventEditViewController,
    didCompleteWith action: EKEventEditViewAction
  ) {
    controller.dismiss(animated: true)
    let result = pendingCreateEventResult
    pendingCreateEventResult = nil

    switch action {
    case .saved:
      result?(["created": true, "confirmation": "ios_event_edit"])
    case .canceled:
      result?(["error": "calendar_event_cancelled", "message": "Calendar event creation was cancelled."])
    case .deleted:
      result?(["error": "calendar_event_deleted", "message": "Calendar event was deleted before saving."])
    @unknown default:
      result?(["error": "calendar_event_unknown", "message": "Calendar event creation ended unexpectedly."])
    }
  }
}
