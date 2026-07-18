import 'dart:convert';

import 'package:airo_app/main.dart' as app;
import 'package:airo_app/core/routing/app_router.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:patrol/patrol.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _selectedAssistantModelKey = 'selected_assistant_model_id';
const _isLoggedInKey = 'is_logged_in';
const _currentUserKey = 'current_user';
const _journeyUserJson =
    '{"id":"agent-skills-journey","username":"Agent Skills Journey","isAdmin":true,"isGoogleUser":false,"createdAt":"2026-06-22T00:00:00.000Z"}';
const _journeyPrompt = String.fromEnvironment(
  'AIRO_AGENT_SKILLS_PROMPT',
  defaultValue: 'Check my schedule for today',
);

Future<void> _pumpUntilFound(
  PatrolIntegrationTester $,
  Finder finder, {
  Duration timeout = const Duration(seconds: 30),
}) async {
  final end = DateTime.now().add(timeout);
  while (DateTime.now().isBefore(end)) {
    await $.pump(const Duration(milliseconds: 250));
    if (finder.evaluate().isNotEmpty) return;
  }

  expect(finder, findsOneWidget);
}

Future<bool> _grantPermissionIfShown(
  PatrolIntegrationTester $, {
  Duration timeout = const Duration(seconds: 15),
}) async {
  final end = DateTime.now().add(timeout);
  while (DateTime.now().isBefore(end)) {
    if (await $.platformAutomator.mobile.isPermissionDialogVisible()) {
      await $.platformAutomator.mobile.grantPermissionWhenInUse();
      await $.pumpAndSettle();
      return true;
    }
    await $.pump(const Duration(milliseconds: 250));
  }
  return false;
}

void main() {
  patrolTest(
    'Agent Skills - calendar schedule journey',
    ($) async {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_selectedAssistantModelKey, 'gemini-nano');
      await prefs.setBool(_isLoggedInKey, true);
      await prefs.setString(_currentUserKey, _journeyUserJson);

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

      if (find
          .byKey(const Key('agent_chat_skills_button'))
          .evaluate()
          .isEmpty) {
        AppRouter.router.go('/agent');
        await $.pumpAndSettle();
      }
      record('assistant_opened');

      expect($(#agent_chat_skills_button), findsOneWidget);

      await $(#agent_chat_skills_button).tap();
      await $.pumpAndSettle();
      expect($('Manage Skills'), findsOneWidget);
      expect($('read-calendar-events'), findsOneWidget);
      record('skills_sheet_verified');

      await $(#manage_skills_close_button).tap();
      await $.pumpAndSettle();

      await $(#agent_chat_input).enterText(_journeyPrompt);
      await $(#agent_chat_send_button).tap();
      await $.pumpAndSettle();
      record('prompt_sent', {'prompt': _journeyPrompt});

      await _pumpUntilFound($, find.text(_journeyPrompt));

      if (defaultTargetPlatform != TargetPlatform.android &&
          await _grantPermissionIfShown($)) {
        record('calendar_permission_granted');
      }

      final actionTraceFinder = find.textContaining('Performed action');
      await _pumpUntilFound($, actionTraceFinder);

      expect($(_journeyPrompt), findsOneWidget);
      expect(actionTraceFinder, findsOneWidget);
      expect($('read-calendar-events'), findsWidgets);
      expect($('get_current_date_time'), findsOneWidget);
      expect($('read_calendar_events'), findsOneWidget);
      final scheduleResponseFinder = find.byWidgetPredicate(
        (widget) =>
            widget is Text &&
            (widget.data?.contains('I checked your schedule') == true ||
                widget.data?.contains('Here is your schedule') == true),
      );
      await _pumpUntilFound($, scheduleResponseFinder);
      expect(scheduleResponseFinder, findsOneWidget);

      stopwatch.stop();
      record('journey_complete', {'total_ms': stopwatch.elapsedMilliseconds});

      debugPrint(
        'AIRO_AGENT_SKILLS_JOURNEY_RESULT '
        '${jsonEncode({'journey': 'agent_skills_calendar_schedule', 'status': 'passed', 'platform': defaultTargetPlatform.name, 'total_ms': stopwatch.elapsedMilliseconds, 'events': events})}',
      );
    },
    tags: ['release_smoke', 'permissions', 'offline_lifecycle'],
  );
}
