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

    return ConnectorResult(
      data: {
        'date': date,
        'events': (_events[date] ?? const [])
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
      final response = await _channel.invokeMapMethod<String, dynamic>(
        'readCalendarEvents',
        {'date': date},
      );
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
    final validationError = _validateCalendarEvent(arguments);
    if (validationError != null) return validationError;

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
      return ConnectorResult.error(
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
