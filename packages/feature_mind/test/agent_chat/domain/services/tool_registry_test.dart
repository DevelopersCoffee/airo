import 'package:core_ai/core_ai.dart';
import 'package:feature_mind/src/assistant/assistant_surface_policy.dart';
import 'package:feature_mind/src/agent_chat/domain/services/intent_parser.dart';
import 'package:feature_mind/src/agent_chat/domain/services/tool_registry.dart';
import 'package:feature_mind/src/meeting_archive/meeting_archive_port.dart';
import 'package:feature_mind/src/search/semantic_search_ranker.dart';
import 'package:feature_mind/src/services/device_actions_service.dart';
import 'package:feature_mind/src/whisper/api/meetings.dart' as rust;
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

class _FakeMeetingArchivePort implements MeetingArchivePort {
  _FakeMeetingArchivePort({
    this.hits = const [],
    this.items = const [],
    this.latestMeeting,
    this.minutesById = const {},
    this.aligned,
  });

  final List<rust.SearchHit> hits;
  final List<rust.MeetingActionItemRecord> items;
  final rust.MeetingRecord? latestMeeting;
  final Map<String, String> minutesById;
  final SemanticRankResult? aligned;

  @override
  Future<List<rust.MeetingActionItemRecord>> actionItemsForOwner(
    String ownerName,
  ) async => items;

  @override
  Future<rust.MeetingRecord?> meeting(String id) async {
    final minutes = minutesById[id];
    if (minutes == null) return null;
    return rust.MeetingRecord(
      id: id,
      title: 'Test meeting',
      recordedAt: BigInt.zero,
      transcript: '',
      minutes: minutes,
      model: 'test',
      decisions: const [],
      actionItems: const [],
      metrics: const [],
    );
  }

  @override
  Future<List<rust.SearchHit>> search(String query) async => hits;

  @override
  Future<SemanticRankResult> searchAligned(String query) async =>
      aligned ?? SemanticRankResult(hits: hits, alignments: const []);

  @override
  Future<rust.MeetingRecord?> latestWithMinutes() async => latestMeeting;

  @override
  Future<String?> minutesForMeeting(String meetingId) async =>
      minutesById[meetingId];
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('ToolRegistry', () {
    late ToolRegistry registry;

    setUp(() {
      registry = ToolRegistry();
    });

    test('exposes Gallery and Off Grid inspired skill cards', () {
      final cards = registry.getSkillCards();
      final titles = cards.map((card) => card.title).toList();

      expect(titles, contains('AI Chat'));
      expect(titles, contains('Agent Skills'));
      expect(titles, contains('Add-ons'));
      expect(titles, contains('Split Bill'));
      expect(titles, contains('Diet Plan'));
      expect(titles, contains('Ask Image'));
      expect(titles, contains('Audio Scribe'));
      expect(titles, contains('Mobile Actions'));
      expect(titles, contains('Tiny Garden'));
      expect(titles, contains('Intelligence'));
      expect(titles, contains('Arena Games'));
      expect(
        cards.singleWhere((card) => card.title == 'Ask Image').route,
        '/quest/new',
      );
      expect(
        cards.singleWhere((card) => card.title == 'Audio Scribe').route,
        '/assistant/audio-scribe',
      );
      expect(
        cards.singleWhere((card) => card.title == 'Tiny Garden').route,
        '/assistant/mobile-actions',
      );
    });

    test('mind desktop policy hides phone-only skill cards', () {
      final cards = registry.getSkillCards(
        policy: const AssistantSurfacePolicy.mindDesktop(),
      );
      final titles = cards.map((card) => card.title).toList();

      expect(titles, contains('AI Chat'));
      expect(titles, contains('Audio Scribe'));
      expect(titles, contains('Diet Plan'));
      expect(titles, isNot(contains('Ask Image')));
      expect(titles, isNot(contains('Mobile Actions')));
      expect(titles, isNot(contains('Tiny Garden')));
      expect(titles, isNot(contains('Arena Games')));
    });

    test(
      'splits bills directly in chat when amount and participants exist',
      () async {
        final result = await registry.executeIntent(
          IntentParser.parse('split this ₹2400 bill with Asha, Ben and Chen'),
        );

        expect(result.shouldNavigate, false);
        expect(result.message, contains('₹800.00'));
        expect(result.message, contains('Asha'));
        expect(result.message, contains('Ben'));
        expect(result.message, contains('Chen'));
      },
    );

    test('creates routine drafts inside chat', () async {
      final diet = await registry.executeIntent(
        IntentParser.parse('make me a 7 day vegetarian diet plan'),
      );
      final routine = await registry.executeIntent(
        IntentParser.parse('create a study routine for tomorrow'),
      );

      expect(diet.isError, isTrue);
      expect(routine.message, contains('routine'));
      expect(routine.shouldNavigate, false);
    });

    test('routes Audio Scribe to its capture workflow', () async {
      final result = await registry.executeIntent(
        IntentParser.parse('transcribe audio'),
      );

      expect(result.route, '/assistant/audio-scribe');
      expect(result.message, contains('on-device capture'));
    });

    test('searches the meeting archive when a port is configured', () async {
      registry.configureMeetingArchive(
        _FakeMeetingArchivePort(
          hits: [
            rust.SearchHit(
              meetingId: 'm1',
              title: 'Infra standup',
              recordedAt: BigInt.zero,
              snippet: 'Temporal signalling limit',
            ),
          ],
        ),
      );

      final result = await registry.executeIntent(
        IntentParser.parse('what did we decide about Temporal signalling'),
      );

      expect(result.shouldNavigate, isFalse);
      expect(result.message, contains('Temporal signalling'));
    });

    test(
      'warns when keyword and embedding scores diverge without PM codes',
      () async {
        registry.configureMeetingArchive(
          _FakeMeetingArchivePort(
            hits: [
              rust.SearchHit(
                meetingId: 'm1',
                title: 'Pricing review',
                recordedAt: BigInt.zero,
                snippet: 'Q3 seats',
              ),
            ],
            aligned: SemanticRankResult(
              hits: [
                rust.SearchHit(
                  meetingId: 'm1',
                  title: 'Pricing review',
                  recordedAt: BigInt.zero,
                  snippet: 'Q3 seats',
                ),
              ],
              alignments: const [
                RetrievalAlignment(
                  meetingId: 'm1',
                  keywordMatched: true,
                  semanticScore: 0.1,
                ),
              ],
            ),
          ),
        );

        final result = await registry.executeIntent(
          IntentParser.parse('what did we decide about pricing'),
        );

        expect(result.message, contains('Pricing review'));
        expect(result.message, contains(RetrievalAlignment.userNote));
        expect(result.message, isNot(contains('PM-05')));
      },
    );

    test('returns saved minutes when user asks for mom', () async {
      const mom = '# Minutes of Meeting\n\n**Meeting:** Infra standup';
      registry.configureMeetingArchive(
        _FakeMeetingArchivePort(
          latestMeeting: rust.MeetingRecord(
            id: 'm1',
            title: 'Infra standup',
            recordedAt: BigInt.from(1),
            transcript: '',
            minutes: mom,
            model: 'test',
            decisions: const [],
            actionItems: const [],
            metrics: const [],
          ),
        ),
      );

      final result = await registry.executeIntent(
        IntentParser.parse('give me mom'),
      );

      expect(result.shouldNavigate, isFalse);
      expect(result.message, contains('Infra standup'));
    });

    test('routes open scribe to /scribe', () async {
      registry.configureMeetingArchive(_FakeMeetingArchivePort());

      final result = await registry.executeIntent(
        IntentParser.parse('record meeting'),
      );

      expect(result.route, '/scribe');
    });

    test('routes game and model management requests to Airo screens', () async {
      final game = await registry.executeIntent(
        IntentParser.parse('start chess'),
      );
      final models = await registry.executeIntent(
        IntentParser.parse('manage offline models'),
      );

      expect(game.route, '/games');
      expect(game.message, contains('Arena'));
      expect(game.parameters['game'], 'chess');
      expect(models.route, '/agent/models');
      expect(models.message, contains('model manager'));
    });

    test(
      'executes the safe Wi-Fi device action through its platform boundary',
      () async {
        const channel = MethodChannel('test.tool-device-actions');
        final messenger =
            TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
        addTearDown(() => messenger.setMockMethodCallHandler(channel, null));
        messenger.setMockMethodCallHandler(
          channel,
          (call) async => const {'opened': true},
        );

        final result = await DeviceActionsTool(
          service: DeviceActionsService(channel: channel),
        ).handle(IntentParser.parse('open wifi settings'));

        expect(result?.isError, isFalse);
        expect(result?.message, 'Opened Wi-Fi settings.');
      },
    );

    test('executes typed Mobile Actions through the same boundary', () async {
      const channel = MethodChannel('test.tool-device-actions.typed');
      final messenger =
          TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
      addTearDown(() => messenger.setMockMethodCallHandler(channel, null));
      messenger.setMockMethodCallHandler(
        channel,
        (call) async => call.method == 'setFlashlight'
            ? const {'changed': true}
            : const {'opened': true},
      );

      final result = await DeviceActionsTool(
        service: DeviceActionsService(channel: channel),
      ).handle(IntentParser.parse('turn flashlight on'));

      expect(result?.isError, isFalse);
      expect(result?.message, 'Turned the flashlight on.');
    });
  });
}
