import 'package:airo_app/features/quest/application/providers/quest_provider.dart';
import 'package:airo_app/features/quest/domain/models/quest_models.dart';
import 'package:airo_app/features/quest/presentation/screens/quest_list_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Widget buildScreen(List<Quest> quests) {
    return ProviderScope(
      overrides: [questListProvider.overrideWith((ref) async => quests)],
      child: const MaterialApp(home: QuestListScreen()),
    );
  }

  group('QuestListScreen', () {
    testWidgets(
      'shows progress, rewards, and streak sections for active quests',
      (tester) async {
        final now = DateTime.now();
        final quests = [
          Quest(
            id: 'daily',
            title: 'Daily planning',
            reminders: [
              QuestReminder(
                id: 'r1',
                questId: 'daily',
                title: 'Plan',
                description: 'Plan the day',
                scheduledTime: now.add(const Duration(hours: 2)),
                isRecurring: true,
                recurringPattern: 'daily',
                createdAt: now,
              ),
            ],
            createdAt: now.subtract(const Duration(hours: 5)),
            updatedAt: now.subtract(const Duration(hours: 1)),
          ),
          Quest(
            id: 'weekly',
            title: 'Weekly review',
            files: [
              QuestFile(
                id: 'f1',
                name: 'notes.pdf',
                path: '/tmp/notes.pdf',
                mimeType: 'application/pdf',
                sizeBytes: 1200,
                uploadedAt: now,
              ),
            ],
            messages: [
              QuestMessage(
                id: 'm1',
                questId: 'weekly',
                text: 'Review this',
                isUser: true,
                timestamp: now,
              ),
            ],
            createdAt: now.subtract(const Duration(days: 3)),
            updatedAt: now.subtract(const Duration(days: 2)),
            status: 'completed',
          ),
        ];

        await tester.pumpWidget(buildScreen(quests));
        await tester.pumpAndSettle();

        expect(find.text('Quest Progress'), findsOneWidget);
        expect(find.text('Active Quests'), findsOneWidget);
        expect(find.text('Rewards'), findsOneWidget);
        expect(find.text('Daily'), findsOneWidget);
        expect(find.text('Weekly'), findsOneWidget);
        expect(find.textContaining('% complete'), findsOneWidget);
        expect(find.textContaining('streak'), findsOneWidget);
        await tester.scrollUntilVisible(
          find.text('Progress Tracker'),
          250,
          scrollable: find.byType(Scrollable).first,
        );
        expect(find.text('Progress Tracker'), findsOneWidget);
        await tester.scrollUntilVisible(
          find.text('All Quests'),
          250,
          scrollable: find.byType(Scrollable).first,
        );
        expect(find.text('All Quests'), findsOneWidget);
        expect(find.text('Daily planning'), findsOneWidget);
        expect(find.text('Weekly review'), findsOneWidget);
      },
    );

    testWidgets(
      'keeps the progress-first layout even when there are no quests',
      (tester) async {
        await tester.pumpWidget(buildScreen(const []));
        await tester.pumpAndSettle();

        expect(find.text('Quest Progress'), findsOneWidget);
        expect(find.text('Active Quests'), findsOneWidget);
        expect(find.text('Rewards'), findsOneWidget);
        await tester.scrollUntilVisible(
          find.text('No Quests Yet'),
          250,
          scrollable: find.byType(Scrollable).first,
        );
        expect(find.text('No Quests Yet'), findsOneWidget);
        expect(find.text('Create Quest'), findsOneWidget);
      },
    );
  });
}
