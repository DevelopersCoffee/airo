import 'package:flutter_test/flutter_test.dart';
import 'package:platform_epg/platform_epg.dart';

void main() {
  final now = DateTime.utc(2026, 7, 27, 18);

  CompactEpgWindow window({
    String title = 'India vs Australia',
    String? category = 'Cricket',
    DateTime? startsAt,
    DateTime? expiresAt,
  }) {
    return CompactEpgWindow(
      entries: [
        CompactEpgWindowEntry(
          channelId: 'sports-1',
          channelName: 'Sports One',
          programs: [
            CompactEpgProgram(
              programId: 'match-1',
              title: title,
              category: category,
              startsAt: startsAt ?? now.add(const Duration(minutes: 5)),
              endsAt: now.add(const Duration(hours: 2)),
              kind: CompactEpgProgramKind.sports,
            ),
          ],
        ),
      ],
      windowStart: now,
      windowEnd: now.add(const Duration(hours: 4)),
      generatedAt: now,
      expiresAt: expiresAt ?? now.add(const Duration(hours: 1)),
      source: CompactEpgSliceSource.localCache,
    );
  }

  IntelligentEpgNotificationPolicy policy({EpgQuietHours? quietHours}) {
    return IntelligentEpgNotificationPolicy(
      maxDeliveriesPerWindow: 2,
      frequencyWindow: const Duration(hours: 1),
      lookahead: const Duration(minutes: 15),
      quietHours: quietHours,
    );
  }

  test('favorite channel creates a program-start trigger', () {
    final result = const IntelligentEpgTriggerEngine().select(
      window: window(),
      signals: IntelligentEpgSignals(favoriteChannelIds: const {'sports-1'}),
      policy: policy(),
      now: now,
    );
    expect(result.single.type, IntelligentEpgTriggerType.programStart);
    expect(result.single.reason, IntelligentEpgTriggerReason.favoriteChannel);
  });

  test('followed title or category creates a followed-entity trigger', () {
    final byTitle = const IntelligentEpgTriggerEngine().select(
      window: window(),
      signals: IntelligentEpgSignals(followedEntities: const {'Australia'}),
      policy: policy(),
      now: now,
    );
    final byCategory = const IntelligentEpgTriggerEngine().select(
      window: window(title: 'Live match'),
      signals: IntelligentEpgSignals(followedEntities: const {'cricket'}),
      policy: policy(),
      now: now,
    );
    expect(
      byTitle.single.reason,
      IntelligentEpgTriggerReason.followedEntityTitle,
    );
    expect(
      byCategory.single.reason,
      IntelligentEpgTriggerReason.followedEntityCategory,
    );
  });

  test('duplicate signals dedupe and results remain stable', () {
    final signals = IntelligentEpgSignals(
      followedEntities: const {'Australia', 'australia'},
    );
    const engine = IntelligentEpgTriggerEngine();
    expect(
      engine.select(
        window: window(),
        signals: signals,
        policy: policy(),
        now: now,
      ),
      engine.select(
        window: window(),
        signals: signals,
        policy: policy(),
        now: now,
      ),
    );
  });

  test('daytime and overnight quiet hours suppress delivery', () {
    final signals = IntelligentEpgSignals(
      favoriteChannelIds: const {'sports-1'},
    );
    const engine = IntelligentEpgTriggerEngine();
    expect(
      engine.select(
        window: window(),
        signals: signals,
        policy: policy(
          quietHours: const EpgQuietHours(
            startMinuteOfDay: 18 * 60,
            endMinuteOfDay: 19 * 60,
          ),
        ),
        now: now,
      ),
      isEmpty,
    );
    expect(
      engine.select(
        window: window(startsAt: DateTime.utc(2026, 7, 27, 23, 30)),
        signals: signals,
        policy: IntelligentEpgNotificationPolicy(
          maxDeliveriesPerWindow: 2,
          frequencyWindow: const Duration(hours: 1),
          lookahead: const Duration(hours: 6),
          quietHours: const EpgQuietHours(
            startMinuteOfDay: 22 * 60,
            endMinuteOfDay: 7 * 60,
          ),
        ),
        now: now,
      ),
      isEmpty,
    );
  });

  test('rolling cap expires old receipts and suppresses duplicates', () {
    final signals = IntelligentEpgSignals(
      favoriteChannelIds: const {'sports-1'},
    );
    const engine = IntelligentEpgTriggerEngine();
    final candidate = engine
        .select(window: window(), signals: signals, policy: policy(), now: now)
        .single;

    expect(
      engine.select(
        window: window(),
        signals: signals,
        policy: policy(),
        now: now,
        deliveryReceipts: [
          EpgNotificationReceipt(
            triggerId: candidate.triggerId,
            deliveredAt: now.subtract(const Duration(minutes: 5)),
          ),
        ],
      ),
      isEmpty,
    );
    expect(
      engine.select(
        window: window(),
        signals: signals,
        policy: policy(),
        now: now,
        deliveryReceipts: [
          EpgNotificationReceipt(
            triggerId: 'old',
            deliveredAt: now.subtract(const Duration(hours: 2)),
          ),
        ],
      ),
      hasLength(1),
    );
  });

  test('stale and out-of-lookahead guide rows fail closed', () {
    final signals = IntelligentEpgSignals(
      favoriteChannelIds: const {'sports-1'},
    );
    const engine = IntelligentEpgTriggerEngine();
    expect(
      engine.select(
        window: window(expiresAt: now),
        signals: signals,
        policy: policy(),
        now: now,
      ),
      isEmpty,
    );
    expect(
      engine.select(
        window: window(startsAt: now.add(const Duration(hours: 1))),
        signals: signals,
        policy: policy(),
        now: now,
      ),
      isEmpty,
    );
  });
}
