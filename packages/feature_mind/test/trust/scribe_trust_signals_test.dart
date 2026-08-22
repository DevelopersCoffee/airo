import 'package:feature_mind/src/trust/scribe_trust_signals.dart';
import 'package:feature_mind/src/trust/scribe_trust_state.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('ScribeTrustState', () {
    test('multilingual shows a language badge', () {
      const state = ScribeTrustState.meetingMultilingual();
      expect(state.showLanguageBadge, isTrue);
      expect(state.languageBadgeLabel, 'Multilingual · auto-detect');
      expect(state.offlineCopy, contains('on this device'));
      expect(state.offlineCopy.toLowerCase(), isNot(contains('cloud')));
    });

    test('english-only still shows an English badge (settings-driven)', () {
      final state = ScribeTrustState.forSpeechModel(multilingual: false);
      expect(state.showLanguageBadge, isTrue);
      expect(state.languageBadgeLabel, 'English');
      expect(state.honestyNote, isNull);
    });

    test('pinned language shows an explicit badge', () {
      final state = ScribeTrustState.forSpeechModel(
        multilingual: true,
        pinnedLanguageCode: 'hi',
      );
      expect(state.showLanguageBadge, isTrue);
      expect(state.languageBadgeLabel, 'Language: hi');
      expect(state.honestyNote, contains('on-device'));
    });

    test('model-missing stays honest and never claims cloud', () {
      final state = ScribeTrustState.forSpeechModel(
        multilingual: true,
        modelMissing: true,
      );
      expect(state.showLanguageBadge, isTrue);
      expect(state.languageBadgeLabel, 'Speech model missing');
      expect(state.offlineCopy, contains('ggml-tiny.bin'));
      expect(state.offlineCopy.toLowerCase(), isNot(contains('cloud')));
      expect(state.honestyNote, contains('will not pretend'));
    });

    test('unknown language warns about auto-detect', () {
      const state = ScribeTrustState(languageMode: ScribeLanguageMode.unknown);
      expect(state.showLanguageBadge, isTrue);
      expect(state.languageBadgeLabel, 'Language unknown');
      expect(state.offlineCopy, contains('auto-detect'));
      expect(state.honestyNote, contains('Translation is never applied'));
    });
  });

  group('ScribeTrustSignals', () {
    Future<void> pump(WidgetTester tester, ScribeTrustState state) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: ScribeTrustSignals(state: state),
            ),
          ),
        ),
      );
    }

    testWidgets('renders multilingual badge and on-device copy', (
      tester,
    ) async {
      await pump(tester, const ScribeTrustState.meetingMultilingual());

      expect(find.byKey(const Key('scribe_trust_signals')), findsOneWidget);
      expect(
        find.byKey(const Key('scribe_trust_language_badge')),
        findsOneWidget,
      );
      expect(find.text('Multilingual · auto-detect'), findsOneWidget);
      expect(find.text('On this device'), findsOneWidget);
      expect(
        find.byKey(const Key('scribe_trust_offline_copy')),
        findsOneWidget,
      );
      expect(
        find.textContaining('Sharing is always an explicit'),
        findsOneWidget,
      );
      expect(
        find.byKey(const Key('scribe_trust_honesty_note')),
        findsOneWidget,
      );
    });

    testWidgets('english-only shows English badge and offline copy', (
      tester,
    ) async {
      await pump(tester, ScribeTrustState.forSpeechModel(multilingual: false));

      expect(
        find.byKey(const Key('scribe_trust_language_badge')),
        findsOneWidget,
      );
      expect(find.text('English'), findsOneWidget);
      expect(find.text('On this device'), findsOneWidget);
      expect(find.byKey(const Key('scribe_trust_honesty_note')), findsNothing);
    });

    testWidgets('model-missing surfaces an honest error badge', (tester) async {
      await pump(
        tester,
        ScribeTrustState.forSpeechModel(multilingual: true, modelMissing: true),
      );

      expect(find.text('Speech model missing'), findsOneWidget);
      expect(find.textContaining('ggml-tiny.bin'), findsOneWidget);
      expect(find.textContaining('will not pretend'), findsOneWidget);
    });

    testWidgets('unknown language keeps auto-detect honesty', (tester) async {
      await pump(
        tester,
        const ScribeTrustState(languageMode: ScribeLanguageMode.unknown),
      );

      expect(find.text('Language unknown'), findsOneWidget);
      expect(find.textContaining('auto-detect'), findsOneWidget);
    });
  });
}
