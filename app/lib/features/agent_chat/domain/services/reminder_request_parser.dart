enum ReminderRequestCategory {
  general('general'),
  billing('billing'),
  medicine('medicine'),
  family('family'),
  habit('habit');

  const ReminderRequestCategory(this.key);

  final String key;
}

enum ReminderScheduleType {
  oneTime('one_time'),
  dueDate('due_date'),
  dailyTime('daily_time'),
  intervalHours('interval_hours'),
  mealRelative('meal_relative');

  const ReminderScheduleType(this.key);

  final String key;
}

class ReminderTime {
  const ReminderTime({required this.hour, required this.minute});

  final int hour;
  final int minute;

  Map<String, int> toJson() => {'hour': hour, 'minute': minute};
}

class ParsedReminderRequest {
  const ParsedReminderRequest({
    required this.title,
    required this.message,
    required this.times,
    required this.repeatDaily,
    required this.category,
    required this.scheduleType,
    this.date,
    this.metadata = const {},
    this.requiresCompletion = false,
    this.followUpPolicy = 'none',
  });

  final String title;
  final String message;
  final List<ReminderTime> times;
  final bool repeatDaily;
  final ReminderRequestCategory category;
  final ReminderScheduleType scheduleType;
  final String? date;
  final Map<String, dynamic> metadata;
  final bool requiresCompletion;
  final String followUpPolicy;

  Map<String, dynamic> toConnectorArguments() {
    final firstTime = times.first;
    return {
      'title': title,
      'message': message,
      'hour': firstTime.hour,
      'minute': firstTime.minute,
      if (times.length > 1)
        'times': times.map((time) => time.toJson()).toList(),
      'repeat_daily': repeatDaily,
      'category': category.key,
      'schedule_type': scheduleType.key,
      'metadata': metadata,
      'requires_completion': requiresCompletion,
      'follow_up_policy': followUpPolicy,
      if (date != null) 'date': date,
    };
  }
}

class ReminderRequestParser {
  const ReminderRequestParser();

  bool needsCurrentDate(String prompt) {
    return _mentionsToday(prompt) || _mentionsTomorrow(prompt);
  }

  bool isScheduleCheck(String prompt) {
    return _isScheduleCheck(prompt);
  }

  bool shouldSelectReminderSkill(String prompt) {
    final lower = prompt.toLowerCase();
    final hasReminderVerb =
        lower.contains('reminder') ||
        lower.contains('remind me') ||
        lower.contains('notification') ||
        lower.contains('notify me') ||
        lower.contains('alert me');
    if (hasReminderVerb) return true;

    final hasMedicineSignal =
        lower.contains('medicine') ||
        lower.contains('medication') ||
        lower.contains('tablet') ||
        lower.contains('pill') ||
        lower.contains('minoxidil');
    if (hasMedicineSignal && _parseTime(prompt) != null) return true;
    if (hasMedicineSignal && _intervalHours(lower) != null) return true;

    final hasTaskCadence =
        (lower.contains('every day') ||
            lower.contains('daily') ||
            lower.contains('each day')) &&
        _parseTime(prompt) != null;
    final hasTaskSubject =
        lower.contains('tuition') ||
        lower.contains('children') ||
        lower.contains('water plants') ||
        lower.contains('workout') ||
        lower.contains('habit');
    return hasTaskCadence && hasTaskSubject;
  }

  ParsedReminderRequest? parse({
    required String prompt,
    required String? currentDate,
  }) {
    final medicinePlan = _parseMedicineReminder(prompt);
    if (medicinePlan != null) return medicinePlan;

    final dueDatePlan = _parseDueDateReminder(prompt, currentDate);
    if (dueDatePlan != null) return dueDatePlan;

    final time = _parseTime(prompt);
    if (time == null) return null;

    final repeatDaily = _isDaily(prompt);
    final scheduleCheck = _isScheduleCheck(prompt);
    final title =
        _quotedText(prompt) ??
        _titleAfterColon(prompt) ??
        _namedReminderTitle(prompt) ??
        _taskTitle(prompt) ??
        (scheduleCheck ? 'Daily Schedule Check' : 'Reminder');
    final message = scheduleCheck
        ? 'Check your schedule for today.'
        : 'Reminder: $title';
    final date = repeatDaily ? null : _dateFromPrompt(prompt, currentDate);

    return ParsedReminderRequest(
      title: title,
      message: message,
      times: [time],
      repeatDaily: repeatDaily,
      category: _taskCategory(prompt),
      scheduleType: repeatDaily
          ? ReminderScheduleType.dailyTime
          : ReminderScheduleType.oneTime,
      date: date,
      metadata: {'source': 'chat'},
    );
  }
}

ParsedReminderRequest? _parseDueDateReminder(
  String prompt,
  String? currentDate,
) {
  final lower = prompt.toLowerCase();
  final keepAsking =
      lower.contains('keep asking') ||
      lower.contains('until i do it') ||
      lower.contains('until done') ||
      lower.contains('until completed');
  final hasDueDate =
      lower.contains('by tomorrow') ||
      lower.contains('tomorrow') ||
      lower.contains('by today') ||
      lower.contains('today');
  if (!keepAsking && !hasDueDate) return null;
  if (!keepAsking && _parseTime(prompt) != null) return null;

  final date = _dateFromPrompt(prompt, currentDate);
  if (date == null) return null;

  final time = _parseTime(prompt) ?? const ReminderTime(hour: 9, minute: 0);
  final title = _dueDateTitle(prompt) ?? _namedReminderTitle(prompt);
  if (title == null) return null;

  return ParsedReminderRequest(
    title: title,
    message: 'Reminder: $title',
    times: [time],
    repeatDaily: keepAsking,
    category: _taskCategory(prompt),
    scheduleType: ReminderScheduleType.dueDate,
    date: date,
    requiresCompletion: keepAsking,
    followUpPolicy: keepAsking ? 'daily_until_done' : 'none',
    metadata: {
      'source': 'chat',
      'due_date': date,
      'requires_completion': keepAsking,
      'follow_up_policy': keepAsking ? 'daily_until_done' : 'none',
    },
  );
}

ParsedReminderRequest? _parseMedicineReminder(String prompt) {
  final lower = prompt.toLowerCase();
  final looksMedical =
      lower.contains('medicine') ||
      lower.contains('medication') ||
      lower.contains('tablet') ||
      lower.contains('pill') ||
      lower.contains('minoxidil') ||
      lower.contains('take ');
  if (!looksMedical) return null;

  final medicineName = _medicineName(prompt);
  if (medicineName == null) return null;

  final mealTimes = _mealRelativeTimes(lower);
  if (mealTimes.isNotEmpty) {
    return ParsedReminderRequest(
      title: medicineName,
      message: 'Take $medicineName.',
      times: mealTimes,
      repeatDaily: true,
      category: ReminderRequestCategory.medicine,
      scheduleType: ReminderScheduleType.mealRelative,
      metadata: {
        'medicine_name': medicineName,
        'meal_relation': lower.contains('before') ? 'before' : 'after',
        'source': 'chat',
      },
    );
  }

  final intervalHours = _intervalHours(lower);
  if (intervalHours == 12) {
    final start = _parseTime(prompt) ?? const ReminderTime(hour: 8, minute: 0);
    return ParsedReminderRequest(
      title: medicineName,
      message: 'Take $medicineName.',
      times: [
        start,
        ReminderTime(hour: (start.hour + 12) % 24, minute: start.minute),
      ],
      repeatDaily: true,
      category: ReminderRequestCategory.medicine,
      scheduleType: ReminderScheduleType.intervalHours,
      metadata: {
        'medicine_name': medicineName,
        'interval_hours': 12,
        'source': 'chat',
      },
    );
  }

  final time = _parseTime(prompt);
  if (time == null) return null;
  return ParsedReminderRequest(
    title: medicineName,
    message: 'Take $medicineName.',
    times: [time],
    repeatDaily: true,
    category: ReminderRequestCategory.medicine,
    scheduleType: ReminderScheduleType.dailyTime,
    metadata: {'medicine_name': medicineName, 'source': 'chat'},
  );
}

ReminderTime? _parseTime(String prompt) {
  final explicitMatch = RegExp(
    r'(?:\bat\s+|@\s*)(\d{1,2}|one|two|three|four|five|six|seven|eight|nine|ten|eleven|twelve)(?::(\d{2}))?\s*(am|pm)?(?:\s*o'
    r'\s*clock)?\b',
    caseSensitive: false,
  ).firstMatch(prompt);
  final meridiemMatch = RegExp(
    r'\b(\d{1,2}|one|two|three|four|five|six|seven|eight|nine|ten|eleven|twelve)(?::(\d{2}))?\s*(am|pm)\b',
    caseSensitive: false,
  ).firstMatch(prompt);
  final match = explicitMatch ?? meridiemMatch;
  if (match == null) return null;

  var hour = _parseHour(match.group(1) ?? '');
  final minute = int.tryParse(match.group(2) ?? '0') ?? 0;
  final meridiem = match.group(3)?.toLowerCase();
  if (hour == null || minute < 0 || minute > 59) return null;
  if (meridiem == 'pm' && hour < 12) hour += 12;
  if (meridiem == 'am' && hour == 12) hour = 0;
  if (hour < 0 || hour > 23) return null;
  return ReminderTime(hour: hour, minute: minute);
}

String? _medicineName(String prompt) {
  final quoted = _quotedText(prompt);
  if (quoted != null) return quoted;
  final lower = prompt.toLowerCase();
  final match = RegExp(
    r'\btake\s+([a-zA-Z0-9][a-zA-Z0-9 -]*?)(?:\s+(?:at|every|before|after|daily|with|for|in|on)\b|[,.]|$)',
    caseSensitive: false,
  ).firstMatch(prompt);
  final parsed = match?.group(1)?.trim();
  if (parsed != null && parsed.isNotEmpty) return _titleCase(parsed);
  if (lower.contains('minoxidil')) return 'Minoxidil';
  return null;
}

int? _intervalHours(String lower) {
  final match = RegExp(r'every\s+(\d{1,2})\s+hours?').firstMatch(lower);
  return int.tryParse(match?.group(1) ?? '');
}

List<ReminderTime> _mealRelativeTimes(String lower) {
  final relation = lower.contains('before')
      ? -30
      : lower.contains('after')
      ? 30
      : 0;
  if (relation == 0) return const [];
  final anchors = <(int, int)>[];
  if (lower.contains('breakfast')) anchors.add((8, 0));
  if (lower.contains('lunch') || lower.contains('midday')) anchors.add((13, 0));
  if (lower.contains('dinner') || lower.contains('meal')) anchors.add((20, 0));
  return anchors.map((anchor) {
    final date = DateTime(
      2026,
      1,
      1,
      anchor.$1,
      anchor.$2,
    ).add(Duration(minutes: relation));
    return ReminderTime(hour: date.hour, minute: date.minute);
  }).toList();
}

String? _taskTitle(String prompt) {
  final lower = prompt.toLowerCase();
  if (lower.contains('tuition') && lower.contains('drop')) {
    return 'Drop children to tuition';
  }
  if (lower.contains('tuition') && lower.contains('pick')) {
    return 'Pick children from tuition';
  }
  return null;
}

ReminderRequestCategory _taskCategory(String prompt) {
  final lower = prompt.toLowerCase();
  if (lower.contains('bill') ||
      lower.contains('recharge') ||
      lower.contains('electricity')) {
    return ReminderRequestCategory.billing;
  }
  if (lower.contains('tuition') || lower.contains('children')) {
    return ReminderRequestCategory.family;
  }
  if (lower.contains('workout') || lower.contains('habit')) {
    return ReminderRequestCategory.habit;
  }
  return ReminderRequestCategory.general;
}

String? _dueDateTitle(String prompt) {
  final lower = prompt.toLowerCase();
  if (lower.contains('electricity') && lower.contains('bill')) {
    return 'Recharge electricity bill';
  }
  final match = RegExp(
    r'\bremind me to\s+(.+?)(?:\s+by\s+|\s+tomorrow\b|\s+today\b|\s+and keep\b|$)',
    caseSensitive: false,
  ).firstMatch(prompt);
  final parsed = match?.group(1)?.trim();
  if (parsed == null || parsed.isEmpty) return null;
  return _titleCase(parsed);
}

String? _dateFromPrompt(String prompt, String? currentDate) {
  if (currentDate == null) return null;
  final current = DateTime.tryParse(currentDate);
  if (current == null) return null;
  if (_mentionsTomorrow(prompt)) {
    return _formatDate(current.add(const Duration(days: 1)));
  }
  if (_mentionsToday(prompt)) return _formatDate(current);
  return null;
}

String? _quotedText(String prompt) {
  final match = RegExp(r'"([^"]+)"').firstMatch(prompt);
  return match?.group(1)?.trim();
}

String? _titleAfterColon(String prompt) {
  final match = RegExp(r':\s*([^,.;]+)$').firstMatch(prompt);
  return match?.group(1)?.trim();
}

String? _namedReminderTitle(String prompt) {
  final match = RegExp(
    r'\b(?:called|named|for)\s+([^,.;]+?)(?:\s+(?:at|every|tomorrow|today)\b|$)',
    caseSensitive: false,
  ).firstMatch(prompt);
  return match?.group(1)?.trim();
}

bool _isDaily(String prompt) {
  final lower = prompt.toLowerCase();
  return lower.contains('daily') ||
      lower.contains('every day') ||
      lower.contains('each day');
}

bool _isScheduleCheck(String prompt) {
  final lower = prompt.toLowerCase();
  return lower.contains('check my schedule') ||
      lower.contains('check your schedule');
}

bool _mentionsToday(String prompt) => prompt.toLowerCase().contains('today');

bool _mentionsTomorrow(String prompt) {
  return prompt.toLowerCase().contains('tomorrow');
}

int? _parseHour(String value) {
  final parsed = int.tryParse(value);
  if (parsed != null) return parsed;
  return const {
    'one': 1,
    'two': 2,
    'three': 3,
    'four': 4,
    'five': 5,
    'six': 6,
    'seven': 7,
    'eight': 8,
    'nine': 9,
    'ten': 10,
    'eleven': 11,
    'twelve': 12,
  }[value.toLowerCase()];
}

String _formatDate(DateTime value) {
  return '${value.year.toString().padLeft(4, '0')}-'
      '${value.month.toString().padLeft(2, '0')}-'
      '${value.day.toString().padLeft(2, '0')}';
}

String _titleCase(String value) {
  return value
      .split(RegExp(r'\s+'))
      .where((word) => word.isNotEmpty)
      .map((word) {
        return word.length == 1
            ? word.toUpperCase()
            : '${word[0].toUpperCase()}${word.substring(1).toLowerCase()}';
      })
      .join(' ');
}
