/// Normalized calendar types. No Android or EventKit types leak through here.
library;

enum CalendarPermissionStatus {
  granted,
  notDetermined,
  denied,
  restricted,
  unsupported,
}

class CalendarPermission {
  const CalendarPermission({
    required this.status,
    this.canRequest = false,
    this.adapter = 'unknown',
  });

  final CalendarPermissionStatus status;
  final bool canRequest;
  final String adapter;

  bool get isGranted => status == CalendarPermissionStatus.granted;

  Map<String, dynamic> toJson() => {
    'status': status.name,
    'granted': isGranted,
    'can_request': canRequest,
    'adapter': adapter,
  };

  static CalendarPermission fromJson(Map<String, dynamic> json) {
    final raw = (json['status'] as String?) ?? 'denied';
    final status = CalendarPermissionStatus.values.firstWhere(
      (value) => value.name == raw || _legacyStatus(raw) == value,
      orElse: () => CalendarPermissionStatus.denied,
    );
    return CalendarPermission(
      status: status,
      canRequest: json['can_request'] == true,
      adapter: json['adapter'] as String? ?? 'unknown',
    );
  }

  static CalendarPermissionStatus? _legacyStatus(String raw) {
    return switch (raw) {
      'not_determined' => CalendarPermissionStatus.notDetermined,
      'write_only' => CalendarPermissionStatus.restricted,
      _ => null,
    };
  }
}

enum CalendarFailureCode {
  permissionDenied,
  permissionRequired,
  platformUnsupported,
  invalidArgument,
  noResults,
  executionFailed,
}

class CalendarException implements Exception {
  const CalendarException({required this.code, required this.message});

  final CalendarFailureCode code;
  final String message;

  String get wireCode => switch (code) {
    CalendarFailureCode.permissionDenied => 'PERMISSION_DENIED',
    CalendarFailureCode.permissionRequired => 'PERMISSION_REQUIRED',
    CalendarFailureCode.platformUnsupported => 'PLATFORM_UNSUPPORTED',
    CalendarFailureCode.invalidArgument => 'INVALID_ARGUMENT',
    CalendarFailureCode.noResults => 'NO_RESULTS',
    CalendarFailureCode.executionFailed => 'EXECUTION_FAILED',
  };

  @override
  String toString() => 'CalendarException($wireCode: $message)';
}

class CalendarAccount {
  const CalendarAccount({
    required this.id,
    required this.title,
    this.account,
    this.isPrimary = false,
  });

  final String id;
  final String title;
  final String? account;
  final bool isPrimary;

  Map<String, dynamic> toJson() => {
    'id': id,
    'title': title,
    if (account != null) 'account': account,
    'isPrimary': isPrimary,
  };

  factory CalendarAccount.fromJson(Map<String, dynamic> json) {
    return CalendarAccount(
      id: json['id'] as String? ?? '',
      title: json['title'] as String? ?? 'Calendar',
      account: json['account'] as String?,
      isPrimary: json['isPrimary'] == true,
    );
  }
}

class CalendarEvent {
  const CalendarEvent({
    required this.id,
    required this.title,
    required this.start,
    required this.end,
    this.timezone,
    this.location,
    this.description,
    this.calendar,
    this.calendarId,
    this.attendees = const [],
    this.isAllDay = false,
  });

  final String id;
  final String title;
  final DateTime start;
  final DateTime end;
  final String? timezone;
  final String? location;
  final String? description;
  final String? calendar;
  final String? calendarId;
  final List<String> attendees;
  final bool isAllDay;

  Map<String, dynamic> toJson() => {
    'id': id,
    'title': title,
    'start': start.toIso8601String(),
    'end': end.toIso8601String(),
    if (timezone != null) 'timezone': timezone,
    if (location != null) 'location': location,
    if (description != null) 'description': description,
    if (calendar != null) 'calendar': calendar,
    if (calendarId != null) 'calendarId': calendarId,
    'attendees': attendees,
    'isAllDay': isAllDay,
  };

  factory CalendarEvent.fromJson(Map<String, dynamic> json) {
    return CalendarEvent(
      id: json['id'] as String? ?? '',
      title: json['title'] as String? ?? 'Untitled event',
      start: DateTime.parse(json['start'] as String),
      end: DateTime.parse(json['end'] as String),
      timezone: json['timezone'] as String?,
      location: json['location'] as String?,
      description: json['description'] as String?,
      calendar: json['calendar'] as String?,
      calendarId: json['calendarId'] as String?,
      attendees: (json['attendees'] as List?)?.cast<String>() ?? const [],
      isAllDay: json['isAllDay'] == true,
    );
  }
}

class CalendarQuery {
  const CalendarQuery({
    required this.start,
    required this.end,
    this.calendarIds,
    this.searchText,
    this.maxResults = defaultMaxResults,
  });

  static const int defaultMaxResults = 50;
  static const int absoluteMaxResults = 200;

  final DateTime start;
  final DateTime end;
  final List<String>? calendarIds;
  final String? searchText;
  final int maxResults;

  void validate() {
    if (end.isBefore(start)) {
      throw const CalendarException(
        code: CalendarFailureCode.invalidArgument,
        message: 'Calendar end must be on or after start.',
      );
    }
    if (maxResults < 1 || maxResults > absoluteMaxResults) {
      throw const CalendarException(
        code: CalendarFailureCode.invalidArgument,
        message: 'Calendar maxResults must be between 1 and 200.',
      );
    }
  }

  Map<String, dynamic> toJson() => {
    'start': start.toUtc().toIso8601String(),
    'end': end.toUtc().toIso8601String(),
    if (calendarIds != null) 'calendarIds': calendarIds,
    if (searchText != null && searchText!.isNotEmpty) 'search': searchText,
    'maxResults': maxResults,
  };
}

class CalendarDateTimeRange {
  const CalendarDateTimeRange({required this.start, required this.end});

  final DateTime start;
  final DateTime end;
}

class FreeBusySlot {
  const FreeBusySlot({required this.start, required this.end});

  final DateTime start;
  final DateTime end;
}

class FreeBusyResult {
  const FreeBusyResult({
    required this.range,
    required this.busy,
    required this.free,
  });

  final CalendarDateTimeRange range;
  final List<FreeBusySlot> busy;
  final List<FreeBusySlot> free;
}
