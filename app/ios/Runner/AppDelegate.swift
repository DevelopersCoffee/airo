import Flutter
import EventKit
import UIKit

@main
@objc class AppDelegate: FlutterAppDelegate {
  private let agentConnectorsChannel = "com.airo.agent_connectors"
  private let eventStore = EKEventStore()

  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    GeneratedPluginRegistrant.register(with: self)

    // TODO: Register GeminiNanoPlugin for memory detection and device info
    // Temporarily disabled for SPM migration testing
    // if let registrar = self.registrar(forPlugin: "GeminiNanoPlugin") {
    //   GeminiNanoPlugin.register(with: registrar)
    // }

    if let controller = window?.rootViewController as? FlutterViewController {
      FlutterMethodChannel(
        name: agentConnectorsChannel,
        binaryMessenger: controller.binaryMessenger
      ).setMethodCallHandler { [weak self] call, result in
        switch call.method {
        case "readCalendarEvents":
          guard
            let arguments = call.arguments as? [String: Any],
            let date = arguments["date"] as? String,
            !date.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
          else {
            result([
              "error": "missing_date",
              "message": "Calendar lookup requires a date.",
            ])
            return
          }
          self?.readCalendarEvents(date: date, result: result)
        case "createCalendarEvent":
          guard let arguments = call.arguments as? [String: Any] else {
            result([
              "error": "missing_arguments",
              "message": "Calendar event creation requires event details.",
            ])
            return
          }
          self?.createCalendarEvent(arguments: arguments, result: result)
        default:
          result(FlutterMethodNotImplemented)
        }
      }
    }

    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  private func readCalendarEvents(date: String, result: @escaping FlutterResult) {
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

      guard let endDate = Calendar.current.date(byAdding: .day, value: 1, to: startDate) else {
        result([
          "error": "invalid_date",
          "message": "Calendar date must use YYYY-MM-DD.",
        ])
        return
      }

      let predicate = self.eventStore.predicateForEvents(
        withStart: startDate,
        end: endDate,
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

      result([
        "date": date,
        "events": events,
      ])
    }
  }

  private func createCalendarEvent(arguments: [String: Any], result: @escaping FlutterResult) {
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
