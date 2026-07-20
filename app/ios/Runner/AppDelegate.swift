import EventKit
import EventKitUI
import Flutter
import EventKit
import UIKit

@main
@objc class AppDelegate: FlutterAppDelegate, EKEventEditViewDelegate {
  private let agentConnectorsChannel = "com.airo.agent_connectors"
  private let eventStore = EKEventStore()
  private var pendingCreateEventResult: FlutterResult?
  private let pictureInPicturePlugin = AiroPictureInPicturePlugin()
  private let backgroundAudioPlugin = AiroBackgroundAudioPlugin()

  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    GeneratedPluginRegistrant.register(with: self)

    if let controller = window?.rootViewController as? FlutterViewController {
      let channel = FlutterMethodChannel(
        name: agentConnectorsChannel,
        binaryMessenger: controller.binaryMessenger
      )
      channel.setMethodCallHandler { [weak self] call, result in
        self?.handleAgentConnectorCall(call, result: result)
      }

      pictureInPicturePlugin.register(with: controller.binaryMessenger)
      backgroundAudioPlugin.register(with: controller.binaryMessenger)
    }

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



  private func openCalendarPermissionSettings(result: @escaping FlutterResult) {
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

  private func readCalendarEvents(
    date: String,
    endDate: String?,
    result: @escaping FlutterResult
  ) {
    requestCalendarAccess { [weak self] granted in
      guard let self else { return }
      guard granted else {
        result([
          "error": "calendar_permission_denied",
          "message": "Calendar permission is required to check your schedule.",
        ])
        return
      }

      guard let startDate = self.dayStart(from: date) else {
        result([
          "error": "invalid_date",
          "message": "Calendar date must use YYYY-MM-DD.",
        ])
        return
      }

      let inclusiveEndDate: Date
      if let endDate, !endDate.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
        guard let parsedEndDate = self.dayStart(from: endDate) else {
          result([
            "error": "invalid_end_date",
            "message": "Calendar end_date must use YYYY-MM-DD.",
          ])
          return
        }
        guard parsedEndDate >= startDate else {
          result([
            "error": "invalid_date_range",
            "message": "Calendar end_date must be on or after date.",
          ])
          return
        }
        inclusiveEndDate = parsedEndDate
      } else {
        inclusiveEndDate = startDate
      }

      guard let queryEndDate = Calendar.current.date(byAdding: .day, value: 1, to: inclusiveEndDate) else {
        result([
          "error": "invalid_date",
          "message": "Calendar date must use YYYY-MM-DD.",
        ])
        return
      }

      let predicate = self.eventStore.predicateForEvents(
        withStart: startDate,
        end: queryEndDate,
        calendars: nil
      )
      let formatter = ISO8601DateFormatter()
      formatter.formatOptions = [.withInternetDateTime, .withColonSeparatorInTimeZone]

      let events = self.eventStore.events(matching: predicate)
        .sorted { $0.startDate < $1.startDate }
        .map { event in
          var payload = [
            "title": event.title ?? "Untitled event",
            "start": formatter.string(from: event.startDate),
            "end": formatter.string(from: event.endDate),
          ] as [String: Any]
          if let calendarTitle = event.calendar?.title {
            payload["calendar"] = calendarTitle
          }
          return payload
        }

      var payload: [String: Any] = [
        "date": date,
        "events": events,
      ]
      if let endDate, !endDate.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
        payload["end_date"] = endDate
      }
      result(payload)
    }
  }

  private func createCalendarEvent(arguments: [String: Any], result: @escaping FlutterResult) {
    if arguments["start"] != nil && arguments["end"] != nil {
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

      DispatchQueue.main.async { [weak self] in
        guard let self else { return }
        guard let rootVC = UIApplication.shared.windows.first?.rootViewController else {
          result(["error": "ui_hierarchy_error", "message": "Could not find root view controller."])
          return
        }

        let event = EKEvent(eventStore: self.eventStore)
        event.title = title
        event.startDate = start
        event.endDate = end
        if let notes = arguments["description"] as? String {
          event.notes = notes
        }
        if let location = arguments["location"] as? String {
          event.location = location
        }

        self.pendingCreateEventResult = result
        let editVC = EKEventEditViewController()
        editVC.eventStore = self.eventStore
        editVC.event = event
        editVC.editViewDelegate = self
        rootVC.present(editVC, animated: true)
      }
      return
    }

    requestCalendarAccess { [weak self] granted in
      guard let self else { return }
      guard granted else {
        result([
          "error": "calendar_permission_denied",
          "message": "Calendar permission is required to add this event.",
        ])
        return
      }

      guard
        let title = arguments["title"] as? String,
        !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
        let date = arguments["date"] as? String,
        let hour = arguments["hour"] as? Int
      else {
        result([
          "error": "missing_event_details",
          "message": "Calendar event creation requires title, date, and time.",
        ])
        return
      }

      let minute = arguments["minute"] as? Int ?? 0
      let durationMinutes = max(arguments["duration_minutes"] as? Int ?? 30, 1)
      guard let startDate = self.date(from: date, hour: hour, minute: minute) else {
        result([
          "error": "invalid_date",
          "message": "Calendar date must use YYYY-MM-DD.",
        ])
        return
      }

      let event = EKEvent(eventStore: self.eventStore)
      event.title = title
      event.notes = arguments["message"] as? String
      event.startDate = startDate
      event.endDate = startDate.addingTimeInterval(TimeInterval(durationMinutes * 60))
      event.calendar = self.eventStore.defaultCalendarForNewEvents
      if arguments["repeat_daily"] as? Bool == true {
        event.addRecurrenceRule(
          EKRecurrenceRule(
            recurrenceWith: .daily,
            interval: 1,
            end: nil
          )
        )
      }

      do {
        try self.eventStore.save(event, span: .futureEvents)
        result([
          "created": true,
          "event_id": event.eventIdentifier as Any,
          "title": title,
          "date": date,
          "hour": hour,
          "minute": minute,
          "repeat_daily": arguments["repeat_daily"] as? Bool ?? false,
        ])
      } catch {
        result([
          "error": "calendar_insert_failed",
          "message": error.localizedDescription,
        ])
      }
    }
  }

  private func dayStart(from date: String) -> Date? {
    let formatter = DateFormatter()
    formatter.calendar = Calendar(identifier: .gregorian)
    formatter.locale = Locale(identifier: "en_US_POSIX")
    formatter.timeZone = .current
    formatter.dateFormat = "yyyy-MM-dd"
    formatter.isLenient = false
    guard let parsedDate = formatter.date(from: date) else { return nil }
    return Calendar.current.startOfDay(for: parsedDate)
  }

  private func requestCalendarAccess(completion: @escaping (Bool) -> Void) {
    if #available(iOS 17.0, *) {
      eventStore.requestFullAccessToEvents { granted, _ in
        DispatchQueue.main.async { completion(granted) }
      }
    } else {
      eventStore.requestAccess(to: .event) { granted, _ in
        DispatchQueue.main.async { completion(granted) }
      }
    }
  }

  private func date(from date: String, hour: Int, minute: Int) -> Date? {
    guard (0...23).contains(hour), (0...59).contains(minute) else {
      return nil
    }
    let parts = date.split(separator: "-").compactMap { Int($0) }
    guard parts.count == 3 else { return nil }
    var components = DateComponents()
    components.year = parts[0]
    components.month = parts[1]
    components.day = parts[2]
    components.hour = hour
    components.minute = minute
    components.second = 0
    components.timeZone = .current
    return Calendar.current.date(from: components)
  }
}
