import 'package:flutter/services.dart';

import '../../domain/models/agent_skill.dart';
import '../../domain/services/agent_connector.dart';

class CalendarEventData {
  const CalendarEventData({
    required this.title,
    required this.start,
    required this.end,
    this.calendar,
  });

  final String title;
  final String start;
  final String end;
  final String? calendar;

  Map<String, dynamic> toJson() {
    return {
      'title': title,
      'start': start,
      'end': end,
      if (calendar != null) 'calendar': calendar,
    };
  }
}

class InMemoryCalendarConnector implements AgentConnector {
  InMemoryCalendarConnector({Map<String, List<CalendarEventData>>? events})
    : _events = events ?? const {};

  final Map<String, List<CalendarEventData>> _events;

  @override
  String get name => 'read_calendar_events';

  @override
  Set<SkillCapability> get requiredCapabilities => {
    SkillCapability.calendarRead,
  };

  @override
  Future<ConnectorResult> execute(Map<String, dynamic> arguments) async {
    final date = arguments['date'] as String?;
    if (date == null || date.isEmpty) {
      return const ConnectorResult.error(
        code: 'missing_date',
        message: 'read_calendar_events requires a date.',
      );
    }
    final endDate = arguments['end_date'] as String?;
    if (endDate != null && endDate.isNotEmpty && !_isValidIsoDate(endDate)) {
      return const ConnectorResult.error(
        code: 'invalid_end_date',
        message: 'read_calendar_events end_date must be YYYY-MM-DD.',
      );
    }

    final requestedDates = _expandRequestedDates(date, endDate);
    if (requestedDates == null) {
      return const ConnectorResult.error(
        code: 'invalid_date_range',
        message: 'read_calendar_events end_date must be on or after date.',
      );
    }
    return ConnectorResult(
      data: {
        'date': date,
        if (endDate != null && endDate.isNotEmpty) 'end_date': endDate,
        'events': requestedDates
            .expand((requestedDate) => _events[requestedDate] ?? const [])
            .map((event) => event.toJson())
            .toList(),
      },
    );
  }
}

class InMemoryCreateCalendarEventConnector implements AgentConnector {
  final createdEvents = <Map<String, dynamic>>[];

  @override
  String get name => 'create_calendar_event';

  @override
  Set<SkillCapability> get requiredCapabilities => {
    SkillCapability.calendarWrite,
  };

  @override
  Future<ConnectorResult> execute(Map<String, dynamic> arguments) async {
    final validationError = _validateCalendarEvent(arguments);
    if (validationError != null) return validationError;

    createdEvents.add(Map<String, dynamic>.from(arguments));
    return ConnectorResult(
      data: {...arguments, 'created': true, 'source': 'in_memory_calendar'},
    );
  }
}

class NativeCalendarConnector implements AgentConnector {
  NativeCalendarConnector({
    MethodChannel channel = const MethodChannel('com.airo.agent_connectors'),
  }) : _channel = channel;

  final MethodChannel _channel;

  @override
  String get name => 'read_calendar_events';

  @override
  Set<SkillCapability> get requiredCapabilities => {
    SkillCapability.calendarRead,
  };

  @override
  Future<ConnectorResult> execute(Map<String, dynamic> arguments) async {
    final date = arguments['date'] as String?;
    if (date == null || date.isEmpty) {
      return const ConnectorResult.error(
        code: 'missing_date',
        message: 'read_calendar_events requires a date.',
      );
    }

    try {
      final response = await _channel
          .invokeMapMethod<String, dynamic>('readCalendarEvents', {
            'date': date,
            if (arguments['end_date'] case final String endDate
                when endDate.isNotEmpty)
              'end_date': endDate,
          });
      if (response == null) {
        return ConnectorResult(data: {'date': date, 'events': const []});
      }
      if (response['error'] is String) {
        return ConnectorResult.error(
          code: response['error'] as String,
          message:
              response['message'] as String? ??
              'Calendar events could not be read.',
          data: response,
        );
      }
      return ConnectorResult(data: response);
    } on MissingPluginException {
      return ConnectorResult(
        data: {
          'date': date,
          'events': const [],
          'source': 'calendar_channel_unavailable',
        },
      );
    } on PlatformException catch (error) {
      return ConnectorResult.error(
        code: error.code,
        message: error.message ?? 'Calendar events could not be read.',
      );
    }
  }
}

class NativeCreateCalendarEventConnector implements AgentConnector {
  NativeCreateCalendarEventConnector({
    MethodChannel channel = const MethodChannel('com.airo.agent_connectors'),
  }) : _channel = channel;

  final MethodChannel _channel;

  @override
  String get name => 'create_calendar_event';

  @override
  Set<SkillCapability> get requiredCapabilities => {
    SkillCapability.calendarWrite,
  };

  @override
  Future<ConnectorResult> execute(Map<String, dynamic> arguments) async {
    final isIsoEvent = arguments.containsKey('start');
    if (isIsoEvent) {
      if (arguments['confirmed'] != true) {
        return const ConnectorResult.error(
          code: 'confirmation_required',
          message: 'Please confirm before creating this calendar event.',
        );
      }
      final title = arguments['title'] as String?;
      final start = arguments['start'] as String?;
      final end = arguments['end'] as String?;
      if (title == null ||
          title.trim().isEmpty ||
          start == null ||
          end == null) {
        return const ConnectorResult.error(
          code: 'invalid_calendar_event',
          message: 'create_calendar_event requires title, start, and end.',
        );
      }
    } else {
      final validationError = _validateCalendarEvent(arguments);
      if (validationError != null) return validationError;
    }

    try {
      final response = await _channel.invokeMapMethod<String, dynamic>(
        'createCalendarEvent',
        arguments,
      );
      if (response == null) {
        return ConnectorResult(data: {...arguments, 'created': true});
      }
      if (response['error'] is String) {
        return ConnectorResult.error(
          code: response['error'] as String,
          message:
              response['message'] as String? ??
              'Calendar event could not be created.',
          data: response,
        );
      }
      return ConnectorResult(data: response);
    } on MissingPluginException {
      return const ConnectorResult.error(
        code: 'calendar_write_unavailable',
        message: 'Calendar event creation is not available on this device yet.',
        data: {'source': 'calendar_channel_unavailable'},
      );
    } on PlatformException catch (error) {
      return ConnectorResult.error(
        code: error.code,
        message: error.message ?? 'Calendar event could not be created.',
      );
    }
  }
}

class NativeCalendarPermissionConnector implements AgentConnector {
  NativeCalendarPermissionConnector({
    MethodChannel channel = const MethodChannel('com.airo.agent_connectors'),
  }) : _channel = channel;

  final MethodChannel _channel;

  @override
  String get name => 'calendar_permission_status';

  @override
  Set<SkillCapability> get requiredCapabilities => const {};

  @override
  Future<ConnectorResult> execute(Map<String, dynamic> arguments) async {
    final shouldOpenSettings = arguments['open_settings'] == true;
    if (shouldOpenSettings && arguments['confirmed'] != true) {
      return const ConnectorResult.error(
        code: 'confirmation_required',
        message: 'Please confirm before opening calendar permission settings.',
      );
    }

    try {
      final response = await _channel.invokeMapMethod<String, dynamic>(
        shouldOpenSettings
            ? 'openCalendarPermissionSettings'
            : 'getCalendarPermissionStatus',
        const {},
      );
      return ConnectorResult(data: response ?? const {});
    } on MissingPluginException {
      return const ConnectorResult.error(
        code: 'calendar_channel_unavailable',
        message:
            'Calendar permission status is not available on this device yet.',
      );
    } on PlatformException catch (error) {
      return ConnectorResult.error(
        code: error.code,
        message:
            error.message ?? 'Calendar permission status could not be read.',
      );
    }
  }
}

ConnectorResult? _validateCalendarEvent(Map<String, dynamic> arguments) {
  final title = (arguments['title'] as String?)?.trim();
  if (title == null || title.isEmpty) {
    return const ConnectorResult.error(
      code: 'missing_title',
      message: 'create_calendar_event requires a title.',
    );
  }

  final date = (arguments['date'] as String?)?.trim();
  if (date == null || date.isEmpty) {
    return const ConnectorResult.error(
      code: 'missing_date',
      message: 'create_calendar_event requires a date.',
    );
  }
  if (!RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(date)) {
    return const ConnectorResult.error(
      code: 'invalid_date',
      message: 'create_calendar_event date must be YYYY-MM-DD.',
    );
  }

  final hour = _readInt(arguments['hour']);
  final minute = _readInt(arguments['minute']) ?? 0;
  if (hour == null || hour < 0 || hour > 23) {
    return const ConnectorResult.error(
      code: 'invalid_hour',
      message: 'create_calendar_event requires hour in 0-23 format.',
    );
  }
  if (minute < 0 || minute > 59) {
    return const ConnectorResult.error(
      code: 'invalid_minute',
      message: 'create_calendar_event requires minute in 0-59 format.',
    );
  }

  return null;
}

int? _readInt(Object? value) {
  if (value is int) return value;
  if (value is num) return value.toInt();
  if (value is String) return int.tryParse(value);
  return null;
}

bool _isValidIsoDate(String value) {
  return RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(value);
}

List<String>? _expandRequestedDates(String date, String? endDate) {
  if (!_isValidIsoDate(date)) return null;
  if (endDate == null || endDate.isEmpty) return [date];
  if (!_isValidIsoDate(endDate)) return null;

  final start = DateTime.tryParse(date);
  final end = DateTime.tryParse(endDate);
  if (start == null || end == null || end.isBefore(start)) return null;

  final dates = <String>[];
  for (
    var current = start;
    !current.isAfter(end);
    current = current.add(const Duration(days: 1))
  ) {
    dates.add(current.toIso8601String().substring(0, 10));
  }
  return dates;
}
