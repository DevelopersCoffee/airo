import 'package:feature_mind/src/agent_chat/data/built_in_skills/draft_diet_plan.dart';
import 'package:feature_mind/src/agent_chat/data/built_in_skills/insurance_planner.dart';
import 'package:feature_mind/src/agent_chat/data/built_in_skills/teacher_personas.dart';
import 'package:feature_mind/src/agent_chat/data/built_in_skills/wellbeing.dart';
import 'package:feature_mind/src/agent_chat/data/connectors/calendar_connector.dart';
import 'package:feature_mind/src/agent_chat/data/connectors/date_time_connector.dart';
import 'package:feature_mind/src/agent_chat/data/connectors/life_track_status_connector.dart';
import 'package:feature_mind/src/agent_chat/data/connectors/notification_connector.dart';
import 'package:feature_mind/src/agent_chat/data/connectors/route_connector.dart';
import 'package:feature_mind/src/agent_chat/domain/models/agent_skill.dart';
import 'package:feature_mind/src/agent_chat/domain/models/grounded_citation.dart';
import 'package:feature_mind/src/agent_chat/domain/services/agent_connector_registry.dart';
import 'package:feature_mind/src/agent_chat/domain/services/agent_skill_orchestrator.dart';
import 'package:feature_mind/src/agent_chat/domain/services/agent_skill_registry.dart';
import 'package:feature_mind/src/runtime/fixture/fixture_mind_runtime.dart';
import 'package:feature_mind/src/runtime/models/capability_models.dart';
import 'package:feature_mind/src/runtime/ports/operation_log_port.dart';
import 'package:core_domain/core_domain.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('AgentSkillOrchestrator', () {
    test('parses selected skill ids from json and rejects malformed input', () {
      expect(
        parseSelectedSkillId('{"skill_id":"read-calendar-events"}'),
        'read-calendar-events',
      );
      expect(parseSelectedSkillId('{"skill_id":null}'), isNull);
      expect(parseSelectedSkillId('not json'), isNull);
    });

    test('parses tool calls from json and rejects malformed action payloads', () {
      final toolCall = parseSkillModelAction(
        '```json\n{"type":"tool_call","tool":"open_route","arguments":{"feature":"money"}}\n```',
      );
      expect(toolCall?.type, SkillModelActionType.toolCall);
      expect(toolCall?.tool, 'open_route');
      expect(toolCall?.arguments, {'feature': 'money'});

      expect(
        parseSkillModelAction('{"type":"final","message":"Done"}')?.message,
        'Done',
      );
      expect(parseSkillModelAction('not json'), isNull);
    });

    test('does not handle prompts when no skill applies', () async {
      final orchestrator = _buildOrchestrator();

      final result = await orchestrator.run('Split this bill');

      expect(result.handled, false);
    });

    test('lets generative plugins fall through to the chat model', () async {
      final orchestrator = _buildOrchestrator(
        skills: [draftDietPlanSkill],
        modelClient: _FixedActionModelClient(
          selectedSkillId: 'draft-diet-plan',
          actions: const [],
        ),
        useFallbackModelClient: false,
      );

      final result = await orchestrator.run(
        'Make me a 7 day vegetarian diet plan',
      );

      expect(result.handled, false);
    });

    test(
      'pinned generative assistant falls through to the chat model',
      () async {
        final orchestrator = _buildOrchestrator(
          skills: [lessonPlanningAssistant],
          useFallbackModelClient: false,
        );

        final result = await orchestrator.run(
          'For Grade 6 science on ecosystems, draft a lesson.',
          pinnedPersonaId: 'lesson-planning-assistant',
        );

        expect(result.handled, false);
      },
    );

    test(
      'pinned insurance planner answers pending tasks from LifeTrack',
      () async {
        final repository = _FakeLifeTrackRepository([
          _track(
            title: 'Health claim',
            category: LifeTrackCategory.insurance,
            milestones: [
              _milestone(
                name: 'Follow-up',
                items: [
                  _item(summary: 'Log insurer follow-up requests'),
                  _item(
                    summary: 'Record settlement outcome',
                    status: ItemStatus.done,
                  ),
                ],
              ),
            ],
          ),
        ]);
        final orchestrator = _buildOrchestrator(
          skills: [insurancePlannerPersona],
          lifeTrackRepository: repository,
        );

        final result = await orchestrator.run(
          'What is pending on my insurance track?',
          pinnedPersonaId: 'insurance-planner',
        );

        expect(result.handled, true);
        expect(result.message, contains('Log insurer follow-up requests'));
        expect(result.message, isNot(contains('Record settlement outcome')));
        expect(result.safetyClass, CapabilitySafetyClass.financial);
        expect(
          result.traces.map((trace) => trace.detail),
          contains('query_lifetrack_status'),
        );
      },
    );

    test('runs wellbeing as a skill with tools, not a screen', () async {
      final orchestrator = _buildOrchestrator(skills: [wellbeingSkill]);

      final result = await orchestrator.run(
        'Guide me through a breathing reset',
      );

      expect(result.handled, true);
      expect(result.message, contains('box breathing'));
      expect(
        result.traces.map((trace) => trace.detail),
        containsAll(['wellbeing-check-in', 'guide_breathing']),
      );
    });

    test('runs calendar skill with date and calendar connectors', () async {
      final orchestrator = _buildOrchestrator();

      final result = await orchestrator.run('Check my schedule for today');

      expect(result.handled, true);
      expect(result.message, contains('no events scheduled'));
      expect(
        result.traces.map((trace) => trace.detail),
        containsAll([
          'read-calendar-events',
          'get_current_date_time',
          'read_calendar_events',
        ]),
      );
      expect(result.traces.last.parameters['date'], '2026-06-20');
      expect(result.traces.last.durationMs, isNotNull);
    });

    test('summarizes calendar events when connector returns events', () async {
      final orchestrator = _buildOrchestrator(
        events: {
          '2026-06-20': const [
            CalendarEventData(
              title: 'Team standup',
              start: '2026-06-20T10:00:00+05:30',
              end: '2026-06-20T10:30:00+05:30',
              calendar: 'Work',
            ),
          ],
        },
      );

      final result = await orchestrator.run('What meetings do I have today?');

      expect(result.handled, true);
      expect(result.message, contains('Team standup'));
      expect(result.message, contains('10:00'));
    });

    test('lists events without requiring the word calendar', () async {
      final orchestrator = _buildOrchestrator(
        events: {
          '2026-06-20': const [
            CalendarEventData(
              title: 'Team standup',
              start: '2026-06-20T10:00:00+05:30',
              end: '2026-06-20T10:30:00+05:30',
              calendar: 'Work',
            ),
          ],
        },
      );

      final result = await orchestrator.run('list all events');

      expect(result.handled, true);
      expect(result.isError, false);
      expect(result.message, contains('Team standup'));
      expect(result.message, isNot(contains('too many steps')));
    });

    test(
      'does not open a feature when the user asks what Airo can do',
      () async {
        final orchestrator = _buildOrchestrator();

        final result = await orchestrator.run('what can u do');

        expect(result.handled, false);
      },
    );

    test(
      'answers LifeTrack status questions through deterministic local tool',
      () async {
        final repository = _FakeLifeTrackRepository([
          _track(
            title: 'Flat purchase',
            milestones: [
              _milestone(
                name: 'Documents',
                items: [
                  _item(summary: 'Upload sale agreement'),
                  _item(summary: 'Pay booking amount', status: ItemStatus.done),
                ],
              ),
            ],
          ),
        ]);
        final orchestrator = _buildOrchestrator(
          lifeTrackRepository: repository,
        );

        final result = await orchestrator.run(
          'What is pending on my flat track?',
        );

        expect(result.handled, true);
        expect(result.isError, false);
        expect(result.message, contains('LifeTrack status for Flat purchase'));
        expect(result.message, contains('Upload sale agreement'));
        expect(result.message, isNot(contains('Pay booking amount')));
        expect(
          result.traces.map((trace) => trace.detail),
          containsAll(['query-lifetrack-status', 'query_lifetrack_status']),
        );
      },
    );

    test('schedules a daily notification reminder', () async {
      final notificationScheduler = InMemoryNotificationScheduler(
        now: () => DateTime(2026, 6, 20, 9, 3),
      );
      final orchestrator = _buildOrchestrator(
        notificationScheduler: notificationScheduler,
      );

      final result = await orchestrator.run(
        'Set a daily reminder at 9am to check my schedule for today.',
      );

      expect(result.handled, true);
      expect(result.message, contains('successfully scheduled for 9:00 AM'));
      expect(result.message, contains('add this to your calendar'));
      expect(result.pendingCalendarEvent, isNotNull);
      expect(result.pendingCalendarEvent!['title'], 'Daily Schedule Check');
      expect(result.pendingCalendarEvent!['date'], '2026-06-20');
      expect(result.pendingCalendarEvent!['hour'], 9);
      expect(
        result.traces.map((trace) => trace.detail),
        containsAll([
          'schedule-notification',
          'get_current_date_time',
          'schedule_notification',
        ]),
      );
      expect(
        result.traces
            .where((trace) => trace.title == 'Execute action')
            .every((trace) => trace.durationMs != null),
        isTrue,
      );
      expect(notificationScheduler.scheduled, hasLength(1));
      expect(
        notificationScheduler.scheduled.single.title,
        'Daily Schedule Check',
      );
      expect(
        notificationScheduler.scheduled.single.message,
        'Check your schedule for today.',
      );
      expect(notificationScheduler.scheduled.single.hour, 9);
      expect(notificationScheduler.scheduled.single.minute, 0);
      expect(notificationScheduler.scheduled.single.repeatDaily, true);
    });

    test('schedules a one-time notification for tomorrow', () async {
      final notificationScheduler = InMemoryNotificationScheduler(
        now: () => DateTime(2026, 6, 20, 9, 3),
      );
      final orchestrator = _buildOrchestrator(
        notificationScheduler: notificationScheduler,
      );

      final result = await orchestrator.run(
        'Create a reminder at 2:30pm tomorrow for "team meeting"',
      );

      expect(result.handled, true);
      expect(result.message, contains('"team meeting"'));
      expect(result.message, contains('add this to your calendar'));
      expect(result.pendingCalendarEvent, isNotNull);
      expect(result.pendingCalendarEvent!['title'], 'team meeting');
      expect(result.pendingCalendarEvent!['date'], '2026-06-21');
      expect(result.pendingCalendarEvent!['hour'], 14);
      expect(result.pendingCalendarEvent!['minute'], 30);
      expect(notificationScheduler.scheduled.single.title, 'team meeting');
      expect(notificationScheduler.scheduled.single.hour, 14);
      expect(notificationScheduler.scheduled.single.minute, 30);
      expect(notificationScheduler.scheduled.single.repeatDaily, false);
      expect(notificationScheduler.scheduled.single.date, '2026-06-21');
    });

    test('schedules medicine reminders in a 12 hour window', () async {
      final notificationScheduler = InMemoryNotificationScheduler(
        now: () => DateTime(2026, 6, 20, 9, 3),
      );
      final orchestrator = _buildOrchestrator(
        notificationScheduler: notificationScheduler,
      );

      final result = await orchestrator.run(
        'Remind me to take Minoxidil every 12 hours starting at 8am',
      );

      expect(result.handled, true);
      expect(result.message, contains('2 medicine reminders'));
      expect(result.message, isNot(contains('add this to your calendar')));
      expect(result.pendingCalendarEvent, isNull);
      expect(notificationScheduler.scheduled, hasLength(2));
      expect(notificationScheduler.scheduled.first.category, 'medicine');
      expect(
        notificationScheduler.scheduled.first.scheduleType,
        'interval_hours',
      );
      expect(notificationScheduler.scheduled.first.hour, 8);
      expect(notificationScheduler.scheduled.last.hour, 20);
      expect(
        notificationScheduler.scheduled.first.metadata['medicine_name'],
        'Minoxidil',
      );
    });

    test('schedules medicine reminders relative to meals', () async {
      final notificationScheduler = InMemoryNotificationScheduler(
        now: () => DateTime(2026, 6, 20, 9, 3),
      );
      final orchestrator = _buildOrchestrator(
        notificationScheduler: notificationScheduler,
      );

      final result = await orchestrator.run(
        'Remind me to take Metformin after breakfast and dinner',
      );

      expect(result.handled, true);
      expect(notificationScheduler.scheduled, hasLength(2));
      expect(notificationScheduler.scheduled.first.hour, 8);
      expect(notificationScheduler.scheduled.first.minute, 30);
      expect(notificationScheduler.scheduled.last.hour, 20);
      expect(notificationScheduler.scheduled.last.minute, 30);
      expect(notificationScheduler.scheduled.first.category, 'medicine');
      expect(
        notificationScheduler.scheduled.first.scheduleType,
        'meal_relative',
      );
    });

    test('schedules family tasks from natural language', () async {
      final notificationScheduler = InMemoryNotificationScheduler(
        now: () => DateTime(2026, 6, 20, 9, 3),
      );
      final orchestrator = _buildOrchestrator(
        notificationScheduler: notificationScheduler,
      );

      final result = await orchestrator.run(
        'Drop my children to tuition every day at four o clock',
      );

      expect(result.handled, true);
      expect(
        notificationScheduler.scheduled.single.title,
        'Drop children to tuition',
      );
      expect(notificationScheduler.scheduled.single.hour, 4);
      expect(notificationScheduler.scheduled.single.category, 'family');
    });

    test('schedules due-date reminders until completed', () async {
      final notificationScheduler = InMemoryNotificationScheduler(
        now: () => DateTime(2026, 6, 20, 9, 3),
      );
      final orchestrator = _buildOrchestrator(
        notificationScheduler: notificationScheduler,
      );

      final result = await orchestrator.run(
        'Remind me to recharge my electricity bill tomorrow by tomorrow and keep asking until I do it',
      );

      expect(result.handled, true);
      expect(result.message, contains('keep asking until you mark it done'));
      expect(
        notificationScheduler.scheduled.single.title,
        'Recharge electricity bill',
      );
      expect(notificationScheduler.scheduled.single.category, 'billing');
      expect(notificationScheduler.scheduled.single.scheduleType, 'due_date');
      expect(notificationScheduler.scheduled.single.date, '2026-06-21');
      expect(notificationScheduler.scheduled.single.hour, 9);
      expect(notificationScheduler.scheduled.single.repeatDaily, true);
      expect(notificationScheduler.scheduled.single.requiresCompletion, true);
      expect(
        notificationScheduler.scheduled.single.followUpPolicy,
        'daily_until_done',
      );
    });

    test('stops unsupported tool calls', () async {
      final orchestrator = _buildOrchestrator(
        modelClient: _UnsupportedToolModelClient(),
      );

      final result = await orchestrator.run('Check my schedule for today');

      expect(result.handled, true);
      expect(result.isError, true);
      expect(result.message, contains('unsupported action'));
    });

    test('builds skill-selection prompt from enabled skill summaries', () {
      final orchestrator = _buildOrchestrator();

      final prompt = orchestrator.buildSkillSelectionPrompt(
        'Check my schedule for today',
      );

      expect(prompt, contains('Available enabled skills'));
      expect(prompt, contains('read-calendar-events'));
      expect(prompt, contains('schedule-notification'));
      expect(prompt, isNot(contains('draft-diet-plan')));
      expect(prompt, isNot(contains('lesson-planning-assistant')));
      expect(prompt, isNot(contains('create-calendar-event')));
      expect(prompt, contains('Return JSON only'));
    });

    test(
      'blocks connectors when selected skill lacks required capability',
      () async {
        final orchestrator = _buildOrchestrator(
          skills: [
            AgentSkill(
              id: 'read-calendar-events',
              name: 'Read Calendar Events',
              description: 'Read calendar without declared capability.',
              instructions: 'Try to read calendar events.',
              tools: const ['read_calendar_events'],
              capabilities: const [],
            ),
          ],
          modelClient: _FixedActionModelClient(
            selectedSkillId: 'read-calendar-events',
            actions: [
              const SkillModelAction.toolCall(
                tool: 'read_calendar_events',
                arguments: {'date': '2026-06-20'},
              ),
            ],
          ),
        );

        final result = await orchestrator.run('Check my schedule for today');

        expect(result.handled, true);
        expect(result.isError, true);
        expect(result.message, contains('permission'));
        expect(result.traces.last.title, 'Blocked capability');
      },
    );

    test('returns an error for malformed model JSON actions', () async {
      final orchestrator = _buildOrchestrator(
        modelClient: _JsonModelClient(
          selectedSkillJson: '{"skill_id":"read-calendar-events"}',
          actionJson: 'not json',
        ),
        useFallbackModelClient: false,
      );

      final result = await orchestrator.run('Check my schedule for today');

      expect(result.handled, isFalse);
      expect(result.isError, isFalse);
    });

    test(
      'returns an error when model output is unusable without fallback',
      () async {
        final orchestrator = _buildOrchestrator(
          modelClient: _NullActionModelClient(),
          useFallbackModelClient: false,
        );

        final result = await orchestrator.run('Check my schedule for today');

        expect(result.handled, isFalse);
        expect(result.isError, isFalse);
      },
    );

    test('stops after max tool steps', () async {
      final orchestrator = _buildOrchestrator(
        maxSteps: 1,
        modelClient: _FixedActionModelClient(
          selectedSkillId: 'read-calendar-events',
          actions: [
            const SkillModelAction.toolCall(tool: 'get_current_date_time'),
          ],
        ),
      );

      final result = await orchestrator.run('Check my schedule for today');

      expect(result.handled, true);
      expect(result.isError, true);
      expect(result.message, contains('too many steps'));
      expect(result.traces.map((trace) => trace.detail), [
        'read-calendar-events',
        'get_current_date_time',
      ]);
    });

    test('stops runs that exceed the bounded step limit', () async {
      final orchestrator = _buildOrchestrator(
        modelClient: _LoopingToolModelClient(),
        useFallbackModelClient: false,
        maxSteps: 2,
      );

      final result = await orchestrator.run('Check my schedule for today');

      expect(result.handled, true);
      expect(result.isError, true);
      expect(result.message, contains('too many steps'));
      expect(
        result.traces.where((trace) => trace.detail == 'get_current_date_time'),
        hasLength(2),
      );
    });

    test(
      'normalizes route tool typo and executes open route connector',
      () async {
        final orchestrator = _buildOrchestrator(
          modelClient: _OpenRouteTypoModelClient(),
        );

        final result = await orchestrator.run('Open money');

        expect(result.handled, true);
        expect(result.isError, false);
        expect(result.message, 'Opening Money.');
        expect(result.route, '/money');
        expect(result.shouldNavigate, true);
        expect(
          result.traces.map((trace) => trace.detail),
          containsAll(['open-airo-feature', 'open_route']),
        );
      },
    );

    test('grounds a LifeTrack answer in the most recent logged op, and carries '
        'the health safety class', () async {
      final repository = _FakeLifeTrackRepository([
        _track(
          title: 'Flat purchase',
          milestones: [
            _milestone(
              name: 'Documents',
              items: [_item(summary: 'Upload sale agreement')],
            ),
          ],
        ),
      ]);
      final orchestrator = _buildOrchestrator(
        lifeTrackRepository: repository,
        operationLogPort: FixtureMindRuntime().log,
      );

      final result = await orchestrator.run(
        'What is pending on my flat track?',
      );

      expect(result.handled, true);
      expect(result.groundingState, GroundingState.grounded);
      expect(result.citations, hasLength(1));
      expect(result.citations.single.opSequence, 12481);
      expect(result.safetyClass, CapabilitySafetyClass.health);

      // The citation must resolve: it names a real op the log can serve.
      final citedOp = await FixtureMindRuntime().log.bySequence(
        result.citations.single.opSequence,
      );
      expect(citedOp, isNotNull);

      final executeTrace = result.traces.firstWhere(
        (trace) => trace.title == 'Execute action',
      );
      expect(executeTrace.dataVolume, isNotNull);
      expect(executeTrace.dataVolume!.bytesLeftDevice, 0);
      expect(executeTrace.dataVolume!.opsInLog, 12481);
      expect(executeTrace.dataVolume!.replayedOpSequence, 12481);
    });

    test(
      'labels a LifeTrack answer as ungrounded when no operation log is wired',
      () async {
        final repository = _FakeLifeTrackRepository([
          _track(
            title: 'Flat purchase',
            milestones: [
              _milestone(
                name: 'Documents',
                items: [_item(summary: 'Upload sale agreement')],
              ),
            ],
          ),
        ]);
        final orchestrator = _buildOrchestrator(
          lifeTrackRepository: repository,
        );

        final result = await orchestrator.run(
          'What is pending on my flat track?',
        );

        expect(result.handled, true);
        expect(result.groundingState, GroundingState.ungrounded);
        expect(result.citations, isEmpty);
        // The safety class is driven by the capability, independent of
        // whether the answer happened to resolve a citation.
        expect(result.safetyClass, CapabilitySafetyClass.health);

        final executeTrace = result.traces.firstWhere(
          (trace) => trace.title == 'Execute action',
        );
        expect(executeTrace.dataVolume, isNotNull);
        expect(executeTrace.dataVolume!.opsInLog, isNull);
      },
    );

    test(
      'a calendar answer carries no safety class and a navigation result carries no grounding claim',
      () async {
        final orchestrator = _buildOrchestrator();

        final scheduleResult = await orchestrator.run(
          'Check my schedule for today',
        );
        expect(scheduleResult.safetyClass, isNull);

        final routeOrchestrator = _buildOrchestrator(
          modelClient: _OpenRouteTypoModelClient(),
        );
        final routeResult = await routeOrchestrator.run('Open money');
        expect(routeResult.groundingState, GroundingState.notApplicable);
        expect(routeResult.citations, isEmpty);
      },
    );

    test(
      'a failed tool call is shown, not measured as if it succeeded',
      () async {
        final orchestrator = _buildOrchestrator(
          modelClient: _UnsupportedToolModelClient(),
        );

        final result = await orchestrator.run('Check my schedule for today');

        expect(result.isError, true);
        expect(
          result.traces
              .where((trace) => trace.title == 'Blocked action')
              .single
              .dataVolume,
          isNull,
        );
      },
    );
  });
}

AgentSkillOrchestrator _buildOrchestrator({
  Map<String, List<CalendarEventData>>? events,
  InMemoryNotificationScheduler? notificationScheduler,
  AgentSkillModelClient? modelClient,
  List<AgentSkill>? skills,
  LifeTrackRepository? lifeTrackRepository,
  bool useFallbackModelClient = true,
  int maxSteps = 4,
  OperationLogPort? operationLogPort,
}) {
  return AgentSkillOrchestrator(
    skillRegistry: AgentSkillRegistry(skills: skills),
    connectorRegistry: AgentConnectorRegistry(
      connectors: [
        DateTimeConnector(now: () => DateTime(2026, 6, 20, 9, 3)),
        InMemoryCalendarConnector(events: events),
        InMemoryCreateCalendarEventConnector(),
        ScheduleNotificationConnector(
          scheduler: notificationScheduler ?? InMemoryNotificationScheduler(),
        ),
        if (lifeTrackRepository != null)
          LifeTrackStatusConnector(repository: lifeTrackRepository),
        RouteConnector(),
        GuideBreathingConnector(),
        LogReflectionConnector(),
      ],
    ),
    modelClient: modelClient,
    useFallbackModelClient: useFallbackModelClient,
    maxSteps: maxSteps,
    operationLogPort: operationLogPort,
  );
}

LifeTrack _track({
  required String title,
  LifeTrackCategory category = LifeTrackCategory.realEstate,
  TrackStatus status = TrackStatus.active,
  List<Milestone>? milestones,
}) {
  final id =
      'track-${title.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]+'), '-').replaceAll(RegExp(r'^-+|-+$'), '')}';
  return LifeTrack(
    id: id,
    title: title,
    category: category,
    status: status,
    milestones:
        milestones ??
        [
          _milestone(
            name: 'Next steps',
            items: [_item(summary: 'Confirm documents')],
          ),
        ],
    createdAt: DateTime.utc(2026, 7, 1),
    updatedAt: DateTime.utc(2026, 7, 2),
  );
}

Milestone _milestone({required String name, required List<ActionItem> items}) {
  return Milestone(
    id: 'milestone-${name.toLowerCase().replaceAll(' ', '-')}',
    trackId: 'track-id',
    name: name,
    objective: '',
    sortOrder: 0,
    status: ItemStatus.todo,
    actionItems: items,
  );
}

ActionItem _item({
  required String summary,
  ItemStatus status = ItemStatus.todo,
}) {
  return ActionItem(
    id: 'item-${summary.toLowerCase().replaceAll(' ', '-')}',
    milestoneId: 'milestone-id',
    summary: summary,
    status: status,
    requirements: const [],
    createdAt: DateTime.utc(2026, 7, 1),
    updatedAt: DateTime.utc(2026, 7, 2),
  );
}

class _FakeLifeTrackRepository implements LifeTrackRepository {
  _FakeLifeTrackRepository(this.tracks);

  final List<LifeTrack> tracks;

  @override
  Future<Result<List<LifeTrack>>> listTracks({TrackStatus? status}) async => Ok(
    tracks.where((track) => status == null || track.status == status).toList(),
  );

  @override
  Future<Result<LifeTrack>> createTrack(LifeTrack track) async => Ok(track);

  @override
  Future<Result<void>> deleteTrack(String id) async => const Ok(null);

  @override
  Future<Result<LifeTrack>> getTrack(String id) async => Ok(tracks.first);

  @override
  Future<Result<void>> saveInputValue(
    String requirementId,
    String value,
  ) async => const Ok(null);

  @override
  Future<Result<void>> updateActionItem(ActionItem item) async =>
      const Ok(null);

  @override
  Future<Result<void>> updateItemStatus(
    String itemId,
    ItemStatus status,
  ) async => const Ok(null);

  @override
  Future<Result<void>> updateMilestone(Milestone milestone) async =>
      const Ok(null);

  @override
  Future<Result<void>> updateTrack(LifeTrack track) async => const Ok(null);

  @override
  Stream<List<LifeTrack>> watchTracks({TrackStatus? status}) =>
      Stream.value(tracks);
}

class _UnsupportedToolModelClient implements AgentSkillModelClient {
  @override
  Future<String?> selectSkill({
    required String prompt,
    required List<AgentSkill> enabledSkills,
  }) async {
    return 'read-calendar-events';
  }

  @override
  Future<SkillModelAction?> nextAction({
    required String prompt,
    required AgentSkill skill,
    required List<Map<String, dynamic>> toolResults,
  }) async {
    return const SkillModelAction.toolCall(tool: 'delete_calendar_events');
  }
}

class _FixedActionModelClient implements AgentSkillModelClient {
  _FixedActionModelClient({
    required this.selectedSkillId,
    required List<SkillModelAction> actions,
  }) : _actions = List.of(actions);

  final String selectedSkillId;
  final List<SkillModelAction> _actions;

  @override
  Future<String?> selectSkill({
    required String prompt,
    required List<AgentSkill> enabledSkills,
  }) async {
    return selectedSkillId;
  }

  @override
  Future<SkillModelAction?> nextAction({
    required String prompt,
    required AgentSkill skill,
    required List<Map<String, dynamic>> toolResults,
  }) async {
    if (_actions.isEmpty) return null;
    return _actions.removeAt(0);
  }
}

class _JsonModelClient implements AgentSkillModelClient {
  const _JsonModelClient({
    required this.selectedSkillJson,
    required this.actionJson,
  });

  final String selectedSkillJson;
  final String actionJson;

  @override
  Future<String?> selectSkill({
    required String prompt,
    required List<AgentSkill> enabledSkills,
  }) async {
    return parseSelectedSkillId(selectedSkillJson);
  }

  @override
  Future<SkillModelAction?> nextAction({
    required String prompt,
    required AgentSkill skill,
    required List<Map<String, dynamic>> toolResults,
  }) async {
    return parseSkillModelAction(actionJson);
  }
}

class _OpenRouteTypoModelClient implements AgentSkillModelClient {
  @override
  Future<String?> selectSkill({
    required String prompt,
    required List<AgentSkill> enabledSkills,
  }) async {
    return 'open-airo-feature';
  }

  @override
  Future<SkillModelAction?> nextAction({
    required String prompt,
    required AgentSkill skill,
    required List<Map<String, dynamic>> toolResults,
  }) async {
    return const SkillModelAction.toolCall(
      tool: 'Open_root',
      arguments: {'feature': 'money'},
    );
  }
}

class _NullActionModelClient implements AgentSkillModelClient {
  @override
  Future<String?> selectSkill({
    required String prompt,
    required List<AgentSkill> enabledSkills,
  }) async {
    return 'read-calendar-events';
  }

  @override
  Future<SkillModelAction?> nextAction({
    required String prompt,
    required AgentSkill skill,
    required List<Map<String, dynamic>> toolResults,
  }) async {
    return null;
  }
}

class _LoopingToolModelClient implements AgentSkillModelClient {
  @override
  Future<String?> selectSkill({
    required String prompt,
    required List<AgentSkill> enabledSkills,
  }) async {
    return 'read-calendar-events';
  }

  @override
  Future<SkillModelAction?> nextAction({
    required String prompt,
    required AgentSkill skill,
    required List<Map<String, dynamic>> toolResults,
  }) async {
    return const SkillModelAction.toolCall(tool: 'get_current_date_time');
  }
}
