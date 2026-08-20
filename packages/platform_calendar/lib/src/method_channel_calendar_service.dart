import 'package:flutter/services.dart';

import 'calendar_diagnostics.dart';
import 'calendar_models.dart';
import 'calendar_service.dart';
import 'in_memory_calendar_service.dart';

const calendarMethodChannelName = 'dev.airo.platform_calendar/methods';

/// Native OS calendar store via a Flutter plugin channel.
class MethodChannelCalendarService implements CalendarService {
  MethodChannelCalendarService({
    MethodChannel? channel,
    this.adapterName = 'native',
  }) : _channel = channel ?? const MethodChannel(calendarMethodChannelName);

  final MethodChannel _channel;

  @override
  final String adapterName;

  Future<Map<String, dynamic>> _invoke(
    String method, [
    Map<String, dynamic>? arguments,
  ]) async {
    try {
      final response = await _channel.invokeMapMethod<String, dynamic>(
        method,
        arguments,
      );
      if (response == null) {
        throw const CalendarException(
          code: CalendarFailureCode.executionFailed,
          message: 'Calendar events could not be read.',
        );
      }
      _throwIfError(response);
      return response;
    } on MissingPluginException {
      throw const CalendarException(
        code: CalendarFailureCode.platformUnsupported,
        message: "Calendar access isn't supported on this device yet.",
      );
    } on PlatformException catch (error) {
      throw CalendarException(
        code: _codeFromWire(error.code),
        message: error.message ?? 'Calendar events could not be read.',
      );
    }
  }

  void _throwIfError(Map<String, dynamic> response) {
    final error = response['error'];
    if (error is! String || error.isEmpty) return;
    throw CalendarException(
      code: _codeFromWire(error),
      message: response['message'] as String? ?? 'Calendar request failed.',
    );
  }

  CalendarFailureCode _codeFromWire(String code) {
    return switch (code) {
      'PERMISSION_DENIED' ||
      'calendar_permission_denied' => CalendarFailureCode.permissionDenied,
      'PERMISSION_REQUIRED' ||
      'calendar_permission_required' => CalendarFailureCode.permissionRequired,
      'PLATFORM_UNSUPPORTED' ||
      'calendar_channel_unavailable' => CalendarFailureCode.platformUnsupported,
      'INVALID_ARGUMENT' ||
      'invalid_date' ||
      'invalid_end_date' ||
      'invalid_date_range' ||
      'missing_date' => CalendarFailureCode.invalidArgument,
      'NO_RESULTS' => CalendarFailureCode.noResults,
      _ => CalendarFailureCode.executionFailed,
    };
  }

  @override
  Future<CalendarPermission> permissionStatus() async {
    final response = await _invoke('getPermissionStatus');
    return CalendarPermission.fromJson({
      ...response,
      'adapter': response['adapter'] ?? adapterName,
    });
  }

  @override
  Future<CalendarPermission> requestPermission() async {
    final response = await _invoke('requestPermission');
    return CalendarPermission.fromJson({
      ...response,
      'adapter': response['adapter'] ?? adapterName,
    });
  }

  @override
  Future<bool> openSettings() async {
    final response = await _invoke('openSettings');
    return response['opened'] == true;
  }

  @override
  Future<bool> openCalendarApp() async {
    final response = await _invoke('openCalendarApp');
    return response['opened'] == true;
  }

  @override
  Future<List<CalendarAccount>> listCalendars() async {
    final response = await _invoke('listCalendars');
    final calendars = response['calendars'] as List? ?? const [];
    return calendars
        .whereType<Map>()
        .map((item) => CalendarAccount.fromJson(item.cast<String, dynamic>()))
        .toList();
  }

  @override
  Future<List<CalendarEvent>> getEvents(CalendarQuery query) async {
    query.validate();
    final stopwatch = Stopwatch()..start();
    final response = await _invoke('getEvents', query.toJson());
    final events = (response['events'] as List? ?? const [])
        .whereType<Map>()
        .map((item) => CalendarEvent.fromJson(item.cast<String, dynamic>()))
        .toList();
    stopwatch.stop();
    logCalendarDiagnostic(
      operation: 'getEvents',
      eventCount: events.length,
      durationMs:
          (response['duration_ms'] as num?)?.toInt() ??
          stopwatch.elapsedMilliseconds,
      adapter: response['adapter'] as String? ?? adapterName,
    );
    return events;
  }

  @override
  Future<List<CalendarEvent>> getEventsForDay(DateTime day) {
    final start = DateTime(day.year, day.month, day.day);
    return getEvents(
      CalendarQuery(start: start, end: start.add(const Duration(days: 1))),
    );
  }

  @override
  Future<CalendarEvent?> getEvent(String id) async {
    if (id.trim().isEmpty) {
      throw const CalendarException(
        code: CalendarFailureCode.invalidArgument,
        message: 'Calendar event id is required.',
      );
    }
    final response = await _invoke('getEvent', {'id': id});
    final event = response['event'];
    if (event is! Map) return null;
    return CalendarEvent.fromJson(event.cast<String, dynamic>());
  }

  @override
  Future<List<CalendarEvent>> searchEvents(String query) {
    final now = DateTime.now();
    return getEvents(
      CalendarQuery(
        start: now.subtract(const Duration(days: 1)),
        end: now.add(const Duration(days: 30)),
        searchText: query,
      ),
    );
  }

  @override
  Future<CalendarEvent?> getNextEvent({DateTime? from}) async {
    final origin = from ?? DateTime.now();
    final upcoming = await getEvents(
      CalendarQuery(start: origin, end: origin.add(const Duration(days: 7))),
    );
    if (upcoming.isEmpty) return null;
    return upcoming.first;
  }

  @override
  Future<FreeBusyResult> getFreeBusy(CalendarDateTimeRange range) async {
    final events = await getEvents(
      CalendarQuery(start: range.start, end: range.end),
    );
    return buildFreeBusy(range: range, events: events);
  }

  /// Write path used by the existing create-event skill. Not part of the
  /// read-focused [CalendarService] surface.
  Future<Map<String, dynamic>> createCalendarEvent(
    Map<String, dynamic> arguments,
  ) {
    return _invoke('createCalendarEvent', arguments);
  }
}
