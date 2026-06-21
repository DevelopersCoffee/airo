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
    if (arguments['confirmed'] != true) {
      return const ConnectorResult.error(
        code: 'confirmation_required',
        message: 'Please confirm before creating this calendar event.',
      );
    }

    final title = arguments['title'] as String?;
    final start = arguments['start'] as String?;
    final end = arguments['end'] as String?;
    if (title == null || title.trim().isEmpty || start == null || end == null) {
      return const ConnectorResult.error(
        code: 'invalid_calendar_event',
        message: 'create_calendar_event requires title, start, and end.',
      );
    }

    try {
      final response = await _channel
          .invokeMapMethod<String, dynamic>('createCalendarEvent', {
            'title': title,
            'start': start,
            'end': end,
            if (arguments['description'] is String)
              'description': arguments['description'],
            if (arguments['location'] is String)
              'location': arguments['location'],
          });
      if (response == null) {
        return const ConnectorResult(data: {'created': true});
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
        code: 'calendar_channel_unavailable',
        message: 'Calendar event creation is not available on this device yet.',
      );
    } on PlatformException catch (error) {
      return ConnectorResult.error(
        code: error.code,
        message: error.message ?? 'Calendar event could not be created.',
      );
    }
  }
}
