import 'dart:convert';

import 'package:airo_app/main.dart' as app;
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:patrol/patrol.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _selectedAssistantModelKey = 'selected_assistant_model_id';
const _journeyPrompt = String.fromEnvironment(
  'AIRO_AGENT_SKILLS_PROMPT',
  defaultValue: 'Check my schedule for today',
);

void main() {
  patrolTest('Agent Skills - calendar schedule journey', ($) async {
    // ignore: invalid_use_of_visible_for_testing_member
    SharedPreferences.setMockInitialValues({
      _selectedAssistantModelKey: 'gemini-nano',
    });

    final stopwatch = Stopwatch()..start();
    final events = <Map<String, Object?>>[];

    void record(String name, [Map<String, Object?> data = const {}]) {
      events.add({
        'name': name,
        'elapsed_ms': stopwatch.elapsedMilliseconds,
        ...data,
      });
    }

    record('launch_start');
    app.main();
    await $.pumpAndSettle();
    record('launch_ready');

    await $('Assistant').tap();
    await $.pumpAndSettle();
    record('assistant_opened');

    expect($(#agent_chat_skills_button), findsOneWidget);

    await $(#agent_chat_skills_button).tap();
    await $.pumpAndSettle();
    expect($('Manage Skills'), findsOneWidget);
    expect($('read-calendar-events'), findsOneWidget);
    record('skills_sheet_verified');

    await $('Close').tap();
    await $.pumpAndSettle();

    await $(#agent_chat_input).enterText(_journeyPrompt);
    await $(#agent_chat_send_button).tap();
    await $.pumpAndSettle();
    record('prompt_sent', {'prompt': _journeyPrompt});

    if (await $.platformAutomator.mobile.isPermissionDialogVisible()) {
      await $.platformAutomator.mobile.grantPermissionWhenInUse();
      await $.pumpAndSettle();
      record('calendar_permission_granted');
    }

    await $.pumpAndSettle(timeout: const Duration(seconds: 15));

    expect($(_journeyPrompt), findsOneWidget);
    expect($('Performed action'), findsOneWidget);
    expect($('read-calendar-events'), findsWidgets);
    expect($('get_current_date_time'), findsOneWidget);
    expect($('read_calendar_events'), findsOneWidget);
    expect(
      find.byWidgetPredicate(
        (widget) =>
            widget is Text &&
            (widget.data?.contains('I checked your schedule') == true ||
                widget.data?.contains('Here is your schedule') == true),
      ),
      findsOneWidget,
    );

    stopwatch.stop();
    record('journey_complete', {'total_ms': stopwatch.elapsedMilliseconds});

    debugPrint(
      'AIRO_AGENT_SKILLS_JOURNEY_RESULT '
      '${jsonEncode({'journey': 'agent_skills_calendar_schedule', 'status': 'passed', 'platform': defaultTargetPlatform.name, 'total_ms': stopwatch.elapsedMilliseconds, 'events': events})}',
    );
  });
}
