import 'dart:convert';

import 'package:core_ai/core_ai.dart';
import 'package:core_domain/core_domain.dart';
import 'package:feature_mind/src/agent_chat/data/connectors/calendar_connector.dart';
import 'package:feature_mind/src/agent_chat/data/connectors/date_time_connector.dart';
import 'package:feature_mind/src/agent_chat/data/connectors/device_actions_connectors.dart';
import 'package:feature_mind/src/agent_chat/data/connectors/life_track_record_connector.dart';
import 'package:feature_mind/src/agent_chat/data/connectors/notification_connector.dart';
import 'package:feature_mind/src/agent_chat/data/connectors/route_connector.dart';
import 'package:feature_mind/src/agent_chat/domain/models/agent_skill.dart';
import 'package:feature_mind/src/agent_chat/domain/services/agent_connector.dart';
import 'package:feature_mind/src/agent_chat/domain/services/agent_connector_registry.dart';
import 'package:feature_mind/src/reasoning/reasoning_models.dart';
import 'package:feature_mind/src/reasoning/reasoning_tool_loop.dart';
import 'package:feature_mind/src/services/device_actions_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const request = MindReasoningRequest(
    userQuery: "What's on tomorrow?",
    intentKind: 'calendar_retrieval',
  );

  test('a direct answer is forwarded without executing tools', () async {
    var reasonCalls = 0;
    final events = runReasoningToolLoop(
      request: request,
      reason: (_) {
        reasonCalls++;
        return Stream.fromIterable(const [
          MindReasoningCompleted(
            answer: 'Nothing on the calendar.',
            reasoningSummary: 'Looked at the calendar.',
            level: MindReasoningLevel.none,
          ),
        ]);
      },
      executeTool: (_, __) async => fail('should not execute'),
    );

    await expectLater(
      events,
      emitsInOrder([
        isA<MindReasoningCompleted>().having(
          (e) => e.answer,
          'answer',
          'Nothing on the calendar.',
        ),
        emitsDone,
      ]),
    );
    expect(reasonCalls, 1);
  });

  test('none level runs one tool and skips a second model call', () async {
    var reasonCalls = 0;
    final executed = <String>[];
    final events = runReasoningToolLoop(
      request: request,
      reason: (_) {
        reasonCalls++;
        return Stream.fromIterable(const [
          MindReasoningCompleted(
            answer: '',
            reasoningSummary: 'Need calendar.',
            level: MindReasoningLevel.none,
            toolCalls: [
              MindReasoningToolCall(
                name: 'read_calendar_events',
                argumentsJson: '{"day":"tomorrow"}',
              ),
            ],
          ),
        ]);
      },
      executeTool: (name, args) async {
        executed.add('$name $args');
        return 'Three meetings tomorrow.';
      },
    );

    await expectLater(
      events,
      emitsInOrder([
        isA<MindReasoningToolStarted>().having(
          (e) => e.tool,
          'tool',
          'read_calendar_events',
        ),
        isA<MindReasoningToolCompleted>().having(
          (e) => e.tool,
          'tool',
          'read_calendar_events',
        ),
        isA<MindReasoningCompleted>()
            .having((e) => e.answer, 'answer', 'Three meetings tomorrow.')
            .having(
              (e) => e.toolCalls.single.name,
              'tool',
              'read_calendar_events',
            ),
        emitsDone,
      ]),
    );
    expect(reasonCalls, 1);
    expect(executed, ['read_calendar_events {"day":"tomorrow"}']);
  });

  test('light level feeds tool output into a second reason() call', () async {
    var reasonCalls = 0;
    final events = runReasoningToolLoop(
      request: const MindReasoningRequest(
        userQuery: 'Summarise tomorrow',
        intentKind: 'summarization',
        intentComplexity: 0.4,
      ),
      reason: (req) {
        reasonCalls++;
        if (req.toolResults.isEmpty) {
          return Stream.fromIterable(const [
            MindReasoningCompleted(
              answer: '',
              reasoningSummary: 'Need calendar.',
              level: MindReasoningLevel.light,
              toolCalls: [
                MindReasoningToolCall(
                  name: 'read_calendar_events',
                  argumentsJson: '{}',
                ),
              ],
            ),
          ]);
        }
        expect(req.toolResults.single.text, contains('a, b, c'));
        expect(
          req.toolResults.single.text,
          contains(ContextCompiler.dataBegin),
        );
        return Stream.fromIterable(const [
          MindReasoningCompleted(
            answer: 'You have three meetings.',
            reasoningSummary: 'Used the calendar.',
            level: MindReasoningLevel.light,
          ),
        ]);
      },
      executeTool: (_, __) async => 'a, b, c',
    );

    await expectLater(
      events,
      emitsInOrder([
        isA<MindReasoningToolStarted>(),
        isA<MindReasoningToolCompleted>(),
        isA<MindReasoningCompleted>().having(
          (e) => e.answer,
          'answer',
          'You have three meetings.',
        ),
        emitsDone,
      ]),
    );
    expect(reasonCalls, 2);
  });

  test('the loop stops at five tools', () async {
    var executes = 0;
    final events = runReasoningToolLoop(
      request: const MindReasoningRequest(
        userQuery: 'Keep going',
        intentKind: 'summarization',
        intentComplexity: 0.4,
      ),
      reason: (_) {
        return Stream.fromIterable(const [
          MindReasoningCompleted(
            answer: '',
            reasoningSummary: 'Need calendar.',
            level: MindReasoningLevel.light,
            toolCalls: [
              MindReasoningToolCall(
                name: 'read_calendar_events',
                argumentsJson: '{}',
              ),
            ],
          ),
        ]);
      },
      executeTool: (_, __) async {
        executes++;
        return 'ok';
      },
    );

    final collected = await events.toList();
    expect(executes, kMaxReasoningToolIterations);
    expect(
      collected.whereType<MindReasoningError>().single.message,
      kReasoningToolBudgetMessage,
    );
    expect(collected.whereType<MindReasoningCompleted>(), isEmpty);
  });

  test('decodeToolArguments accepts objects and rejects junk', () {
    expect(decodeToolArguments('{"day":"tomorrow"}'), {'day': 'tomorrow'});
    expect(decodeToolArguments('not json'), isEmpty);
    expect(decodeToolArguments('[]'), isEmpty);
  });

  group('LiteRT tool selection by model id', () {
    late AgentConnectorRegistry registry;
    late InMemoryNotificationScheduler scheduler;
    late _FakeDeviceActionsService deviceService;

    setUp(() {
      scheduler = InMemoryNotificationScheduler();
      deviceService = _FakeDeviceActionsService();
      registry = AgentConnectorRegistry(
        connectors: [
          DateTimeConnector(),
          InMemoryCalendarConnector(
            events: {
              '2026-10-18': const [
                CalendarEventData(
                  title: 'Dentist',
                  start: '2026-10-18T10:00:00Z',
                  end: '2026-10-18T11:00:00Z',
                ),
              ],
            },
          ),
          InMemoryCalendarPermissionConnector(),
          InMemoryCreateCalendarEventConnector(),
          _FakeLifeTrackStatusConnector(),
          RouteConnector(),
          ScheduleNotificationConnector(scheduler: scheduler),
          LifeTrackRecordConnector(
            repository: _FakeLifeTrackRepository(),
            resolveTemplate: (_) async => const LifeTrackTemplate(
              templateId: 'insurance_claim_v1',
              title: 'Insurance Claim',
              description: 'Claim template',
              category: LifeTrackCategory.insurance,
              version: '1.0',
              milestones: [],
            ),
          ),
          ...createDeviceActionConnectors(service: deviceService),
        ],
      );
    });

    test('airo-actions-270m-litertlm selects only the 7 Airo action tools', () {
      final specs = liteRtToolSpecsForModel(
        modelId: 'airo-actions-270m-litertlm',
        registry: registry,
        supportsFunctionCalling: true,
      );
      final names = specs.map((s) => s.name).toList();

      expect(names, [
        'get_current_date_time',
        'read_calendar_events',
        'calendar_permission_status',
        'query_lifetrack_status',
        'open_route',
        'schedule_notification',
        'record_lifetrack_facts',
      ]);

      // Assert Google's seven tools are NOT included
      expect(names, isNot(contains('turn_on_flashlight')));
      expect(names, isNot(contains('turn_off_flashlight')));
      expect(names, isNot(contains('create_contact')));
      expect(names, isNot(contains('send_email')));
      expect(names, isNot(contains('show_map')));
      expect(names, isNot(contains('open_wifi_settings')));
      expect(names, isNot(contains('create_calendar_event')));
    });

    test('mobile-actions-270m-litertlm selects Google seven tools', () {
      final specs = liteRtToolSpecsForModel(
        modelId: 'mobile-actions-270m-litertlm',
        registry: registry,
        supportsFunctionCalling: true,
      );
      final names = specs.map((s) => s.name).toList();

      expect(names, [
        'turn_on_flashlight',
        'turn_off_flashlight',
        'create_contact',
        'send_email',
        'show_map',
        'open_wifi_settings',
        'create_calendar_event',
      ]);

      // Assert Airo navigation, notifications, and LifeTrack are NOT included
      expect(names, isNot(contains('open_route')));
      expect(names, isNot(contains('schedule_notification')));
      expect(names, isNot(contains('record_lifetrack_facts')));
      expect(names, isNot(contains('query_lifetrack_status')));
    });

    test('generic function-calling Gemma package selects the four lookup tools', () {
      final specs = liteRtToolSpecsForModel(
        modelId: 'gemma-4-e2b-it-litertlm',
        registry: registry,
        supportsFunctionCalling: true,
      );
      final names = specs.map((s) => s.name).toList();

      expect(names, [
        'get_current_date_time',
        'read_calendar_events',
        'calendar_permission_status',
        'query_lifetrack_status',
      ]);
    });

    test('non-function-calling package returns empty tool list', () {
      final specs = liteRtToolSpecsForModel(
        modelId: 'gemma-2-2b-it-q4',
        registry: registry,
        supportsFunctionCalling: false,
      );
      expect(specs, isEmpty);
    });

    test('liteRtToolSpecsForPackage delegates properly', () {
      const airoPackage = OfflineModelInfo(
        id: 'airo-actions-270m-litertlm',
        name: 'AiroActions-270M',
        family: ModelFamily.gemma,
        fileSizeBytes: 291398144,
        supportsFunctionCalling: true,
      );
      final specs = liteRtToolSpecsForPackage(airoPackage, registry);
      expect(specs.map((s) => s.name), [
        'get_current_date_time',
        'read_calendar_events',
        'calendar_permission_status',
        'query_lifetrack_status',
        'open_route',
        'schedule_notification',
        'record_lifetrack_facts',
      ]);
    });

    test('sample open_route call reaches RouteConnector', () async {
      final raw = await executeLiteRtTool(
        registry: registry,
        name: 'open_route',
        arguments: const {'target': 'budget'},
      );
      final decoded = jsonDecode(raw) as Map<String, dynamic>;
      expect(decoded['route'], '/money/budgets');
      expect(decoded['message'], contains('Budgets'));
    });

    test('sample schedule_notification call reaches ScheduleNotificationConnector', () async {
      final raw = await executeLiteRtTool(
        registry: registry,
        name: 'schedule_notification',
        arguments: const {
          'title': 'Medicine',
          'message': 'Take morning pill',
          'hour': 7,
          'minute': 30,
          'repeat_daily': true,
        },
      );
      final decoded = jsonDecode(raw) as Map<String, dynamic>;
      expect(decoded['title'], 'Medicine');
      expect(decoded['hour'], 7);
      expect(decoded['minute'], 30);
      expect(decoded['repeat_daily'], isTrue);
      expect(scheduler.scheduled, hasLength(1));
    });

    test('sample record_lifetrack_facts call reaches LifeTrackRecordConnector', () async {
      final raw = await executeLiteRtTool(
        registry: registry,
        name: 'record_lifetrack_facts',
        arguments: const {
          'query': 'Blood test completed on Friday',
        },
      );
      expect(raw, contains('Blood test completed on Friday'));
    });

    test('sample get_current_date_time call reaches DateTimeConnector', () async {
      final raw = await executeLiteRtTool(
        registry: registry,
        name: 'get_current_date_time',
        arguments: const {},
      );
      final decoded = jsonDecode(raw) as Map<String, dynamic>;
      expect(decoded, contains('date'));
      expect(decoded, contains('time'));
    });

    test('sample read_calendar_events call reaches InMemoryCalendarConnector', () async {
      final raw = await executeLiteRtTool(
        registry: registry,
        name: 'read_calendar_events',
        arguments: const {'date': '2026-10-18'},
      );
      final decoded = jsonDecode(raw) as Map<String, dynamic>;
      expect(decoded['date'], '2026-10-18');
      final events = decoded['events'] as List;
      expect(events, hasLength(1));
      expect(events.first['title'], 'Dentist');
    });

    test('sample calendar_permission_status call reaches InMemoryCalendarPermissionConnector', () async {
      final raw = await executeLiteRtTool(
        registry: registry,
        name: 'calendar_permission_status',
        arguments: const {},
      );
      final decoded = jsonDecode(raw) as Map<String, dynamic>;
      expect(decoded['status'], 'granted');
      expect(decoded['granted'], isTrue);
    });

    test('sample turn_on_flashlight call reaches TurnOnFlashlightConnector', () async {
      final raw = await executeLiteRtTool(
        registry: registry,
        name: 'turn_on_flashlight',
        arguments: const {},
      );
      final decoded = jsonDecode(raw) as Map<String, dynamic>;
      expect(decoded['action'], 'turn_on_flashlight');
      expect(decoded['success'], isTrue);
      expect(deviceService.flashlightEnabled, isTrue);
    });
  });
}

class _FakeLifeTrackStatusConnector implements AgentConnector {
  @override
  String get name => 'query_lifetrack_status';

  @override
  Set<SkillCapability> get requiredCapabilities => {SkillCapability.lifeTrackRead};

  @override
  Future<ConnectorResult> execute(Map<String, dynamic> arguments) async {
    return ConnectorResult(
      data: {'query': arguments['query'], 'status': 'ok'},
    );
  }
}

class _FakeLifeTrackRepository implements LifeTrackRepository {
  final List<LifeTrack> tracks = [];

  @override
  Future<Result<List<LifeTrack>>> listTracks({TrackStatus? status}) async =>
      Ok(List<LifeTrack>.from(tracks));

  @override
  Future<Result<LifeTrack>> createTrack(LifeTrack track) async {
    tracks.add(track);
    return Ok(track);
  }

  @override
  Future<Result<void>> deleteTrack(String id) async {
    tracks.removeWhere((t) => t.id == id);
    return const Ok(null);
  }

  @override
  Future<Result<LifeTrack>> getTrack(String id) async =>
      Ok(tracks.firstWhere((track) => track.id == id));

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
  Future<Result<void>> updateTrack(LifeTrack track) async {
    final index = tracks.indexWhere((item) => item.id == track.id);
    if (index >= 0) tracks[index] = track;
    return const Ok(null);
  }

  @override
  Stream<List<LifeTrack>> watchTracks({TrackStatus? status}) =>
      Stream.value(tracks);
}

class _FakeDeviceActionsService extends DeviceActionsService {
  bool flashlightEnabled = false;

  @override
  Future<bool> setFlashlight({required bool enabled}) async {
    flashlightEnabled = enabled;
    return true;
  }
}
