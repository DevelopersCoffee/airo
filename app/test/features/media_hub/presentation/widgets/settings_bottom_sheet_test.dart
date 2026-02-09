import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:airo_app/features/media_hub/presentation/widgets/settings_bottom_sheet.dart';
import 'package:airo_app/features/media_hub/application/providers/quality_settings_provider.dart';
import 'package:airo_app/features/media_hub/domain/models/quality_settings.dart';
import 'package:airo_app/features/iptv/domain/models/iptv_channel.dart';
import 'package:airo_app/features/iptv/application/providers/iptv_providers.dart';

void main() {
  late SharedPreferences mockPrefs;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    mockPrefs = await SharedPreferences.getInstance();
  });

  Widget createTestWidget({
    List<String>? availableAudioLanguages,
    List<String>? availableSubtitleLanguages,
    String? selectedSubtitleLanguage,
    ValueChanged<String?>? onSubtitleLanguageChanged,
    bool showPlaybackSpeed = true,
    List<Override> overrides = const [],
  }) {
    return ProviderScope(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(mockPrefs),
        ...overrides,
      ],
      child: MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => ElevatedButton(
              onPressed: () => showModalBottomSheet<void>(
                context: context,
                isScrollControlled: true,
                builder: (_) => ProviderScope(
                  overrides: [
                    sharedPreferencesProvider.overrideWithValue(mockPrefs),
                    ...overrides,
                  ],
                  child: SettingsBottomSheet(
                    availableAudioLanguages: availableAudioLanguages,
                    availableSubtitleLanguages: availableSubtitleLanguages,
                    selectedSubtitleLanguage: selectedSubtitleLanguage,
                    onSubtitleLanguageChanged: onSubtitleLanguageChanged,
                    showPlaybackSpeed: showPlaybackSpeed,
                  ),
                ),
              ),
              child: const Text('Open Settings'),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> openBottomSheet(WidgetTester tester) async {
    await tester.tap(find.text('Open Settings'));
    await tester.pumpAndSettle();
  }

  group('SettingsBottomSheet', () {
    group('Rendering', () {
      testWidgets('renders header with title and close button', (tester) async {
        await tester.pumpWidget(createTestWidget());
        await openBottomSheet(tester);

        expect(find.text('Playback Settings'), findsOneWidget);
        expect(find.byIcon(Icons.settings), findsOneWidget);
        expect(find.byIcon(Icons.close), findsOneWidget);
      });

      testWidgets('renders drag handle', (tester) async {
        await tester.pumpWidget(createTestWidget());
        await openBottomSheet(tester);

        // Drag handle is a Container with specific dimensions
        final containers = tester.widgetList<Container>(find.byType(Container));
        final dragHandle = containers.where((c) {
          final constraints = c.constraints;
          return constraints?.maxWidth == 32 && constraints?.maxHeight == 4;
        });
        expect(dragHandle.isNotEmpty, isTrue);
      });

      testWidgets('renders video quality section header', (tester) async {
        await tester.pumpWidget(createTestWidget());
        await openBottomSheet(tester);

        expect(find.text('Video Quality'), findsOneWidget);
      });

      testWidgets('renders all video quality options', (tester) async {
        await tester.pumpWidget(createTestWidget());
        await openBottomSheet(tester);

        for (final quality in VideoQuality.values) {
          expect(find.text(quality.label), findsOneWidget);
        }
      });

      testWidgets('renders playback speed section when enabled', (
        tester,
      ) async {
        await tester.pumpWidget(createTestWidget(showPlaybackSpeed: true));
        await openBottomSheet(tester);

        expect(find.text('Playback Speed'), findsOneWidget);
      });

      testWidgets('hides playback speed section when disabled', (tester) async {
        await tester.pumpWidget(createTestWidget(showPlaybackSpeed: false));
        await openBottomSheet(tester);

        expect(find.text('Playback Speed'), findsNothing);
      });

      testWidgets('renders all playback speed options', (tester) async {
        await tester.pumpWidget(createTestWidget(showPlaybackSpeed: true));
        await openBottomSheet(tester);

        for (final speed in QualitySettings.availableSpeeds) {
          expect(find.text('${speed}x'), findsOneWidget);
        }
      });

      testWidgets('renders audio language section when available', (
        tester,
      ) async {
        await tester.pumpWidget(
          createTestWidget(
            availableAudioLanguages: ['English', 'Spanish', 'French'],
          ),
        );
        await openBottomSheet(tester);

        expect(find.text('Audio Language'), findsOneWidget);
        expect(find.text('English'), findsOneWidget);
        expect(find.text('Spanish'), findsOneWidget);
        expect(find.text('French'), findsOneWidget);
      });

      testWidgets('hides audio language section when not available', (
        tester,
      ) async {
        await tester.pumpWidget(createTestWidget());
        await openBottomSheet(tester);

        expect(find.text('Audio Language'), findsNothing);
      });

      testWidgets('renders subtitle section when available', (tester) async {
        await tester.pumpWidget(
          createTestWidget(availableSubtitleLanguages: ['English', 'Spanish']),
        );
        await openBottomSheet(tester);

        expect(find.text('Subtitles'), findsOneWidget);
        expect(find.text('Off'), findsOneWidget);
        expect(find.text('English'), findsOneWidget);
        expect(find.text('Spanish'), findsOneWidget);
      });
    });

    group('Video Quality Selection', () {
      testWidgets('auto quality is selected by default', (tester) async {
        await tester.pumpWidget(createTestWidget());
        await openBottomSheet(tester);

        // Find the Auto option's check_circle icon
        final autoTile = find.ancestor(
          of: find.text('Auto'),
          matching: find.byType(ListTile),
        );
        expect(autoTile, findsOneWidget);

        final checkIcon = find.descendant(
          of: autoTile,
          matching: find.byIcon(Icons.check_circle),
        );
        expect(checkIcon, findsOneWidget);
      });

      testWidgets('tapping quality option updates selection', (tester) async {
        await tester.pumpWidget(createTestWidget());
        await openBottomSheet(tester);

        // Tap on 720p
        await tester.tap(find.text('720p'));
        await tester.pumpAndSettle();

        // Verify 720p is now selected
        final hdTile = find.ancestor(
          of: find.text('720p'),
          matching: find.byType(ListTile),
        );
        final checkIcon = find.descendant(
          of: hdTile,
          matching: find.byIcon(Icons.check_circle),
        );
        expect(checkIcon, findsOneWidget);
      });

      testWidgets('auto quality shows description', (tester) async {
        await tester.pumpWidget(createTestWidget());
        await openBottomSheet(tester);

        expect(
          find.text('Adjusts automatically based on connection'),
          findsOneWidget,
        );
      });
    });

    group('Playback Speed Selection', () {
      testWidgets('1.0x is selected by default', (tester) async {
        await tester.pumpWidget(createTestWidget());
        await openBottomSheet(tester);

        final chip = tester.widget<ChoiceChip>(
          find.ancestor(
            of: find.text('1.0x'),
            matching: find.byType(ChoiceChip),
          ),
        );
        expect(chip.selected, isTrue);
      });

      testWidgets('tapping speed chip updates selection', (tester) async {
        await tester.pumpWidget(createTestWidget());
        await openBottomSheet(tester);

        // Tap on 1.5x
        await tester.tap(find.text('1.5x'));
        await tester.pumpAndSettle();

        final chip = tester.widget<ChoiceChip>(
          find.ancestor(
            of: find.text('1.5x'),
            matching: find.byType(ChoiceChip),
          ),
        );
        expect(chip.selected, isTrue);
      });
    });

    group('Audio Language Selection', () {
      testWidgets('tapping language updates selection', (tester) async {
        // Disable playback speed to make sheet shorter
        await tester.pumpWidget(
          createTestWidget(
            availableAudioLanguages: ['English', 'Spanish'],
            showPlaybackSpeed: false,
          ),
        );
        await openBottomSheet(tester);

        // Scroll to make Spanish visible
        await tester.scrollUntilVisible(
          find.text('Spanish'),
          100,
          scrollable: find.byType(Scrollable).last,
        );
        await tester.pumpAndSettle();

        // Tap on Spanish
        await tester.tap(find.text('Spanish'));
        await tester.pumpAndSettle();

        // Verify Spanish is now selected
        final spanishTile = find.ancestor(
          of: find.text('Spanish'),
          matching: find.byType(ListTile),
        );
        final checkIcon = find.descendant(
          of: spanishTile,
          matching: find.byIcon(Icons.check_circle),
        );
        expect(checkIcon, findsOneWidget);
      });
    });

    group('Subtitle Selection', () {
      testWidgets('Off is selected when no subtitle selected', (tester) async {
        // Disable playback speed to make sheet shorter
        await tester.pumpWidget(
          createTestWidget(
            availableSubtitleLanguages: ['English', 'Spanish'],
            selectedSubtitleLanguage: null,
            showPlaybackSpeed: false,
          ),
        );
        await openBottomSheet(tester);

        // Scroll to make Off visible
        await tester.scrollUntilVisible(
          find.text('Off'),
          100,
          scrollable: find.byType(Scrollable).last,
        );
        await tester.pumpAndSettle();

        final offTile = find.ancestor(
          of: find.text('Off'),
          matching: find.byType(ListTile),
        );
        final checkIcon = find.descendant(
          of: offTile,
          matching: find.byIcon(Icons.check_circle),
        );
        expect(checkIcon, findsOneWidget);
      });

      testWidgets('selected subtitle shows check icon', (tester) async {
        // Disable playback speed to make sheet shorter
        await tester.pumpWidget(
          createTestWidget(
            availableSubtitleLanguages: ['English', 'Spanish'],
            selectedSubtitleLanguage: 'English',
            showPlaybackSpeed: false,
          ),
        );
        await openBottomSheet(tester);

        // Scroll to make English visible
        await tester.scrollUntilVisible(
          find.text('English'),
          100,
          scrollable: find.byType(Scrollable).last,
        );
        await tester.pumpAndSettle();

        final englishTile = find.ancestor(
          of: find.text('English'),
          matching: find.byType(ListTile),
        );
        final checkIcon = find.descendant(
          of: englishTile,
          matching: find.byIcon(Icons.check_circle),
        );
        expect(checkIcon, findsOneWidget);
      });

      testWidgets('tapping subtitle calls callback', (tester) async {
        String? selectedLanguage = 'initial';
        // Disable playback speed to make sheet shorter
        await tester.pumpWidget(
          createTestWidget(
            availableSubtitleLanguages: ['English', 'Spanish'],
            onSubtitleLanguageChanged: (lang) => selectedLanguage = lang,
            showPlaybackSpeed: false,
          ),
        );
        await openBottomSheet(tester);

        // Scroll to make Spanish visible
        await tester.scrollUntilVisible(
          find.text('Spanish'),
          100,
          scrollable: find.byType(Scrollable).last,
        );
        await tester.pumpAndSettle();

        await tester.tap(find.text('Spanish'));
        await tester.pump();

        expect(selectedLanguage, 'Spanish');
      });

      testWidgets('tapping Off calls callback with null', (tester) async {
        String? selectedLanguage = 'English';
        // Disable playback speed to make sheet shorter
        await tester.pumpWidget(
          createTestWidget(
            availableSubtitleLanguages: ['English', 'Spanish'],
            selectedSubtitleLanguage: 'English',
            onSubtitleLanguageChanged: (lang) => selectedLanguage = lang,
            showPlaybackSpeed: false,
          ),
        );
        await openBottomSheet(tester);

        // Scroll to make Off visible
        await tester.scrollUntilVisible(
          find.text('Off'),
          100,
          scrollable: find.byType(Scrollable).last,
        );
        await tester.pumpAndSettle();

        await tester.tap(find.text('Off'));
        await tester.pump();

        expect(selectedLanguage, isNull);
      });
    });

    group('Close Button', () {
      testWidgets('close button dismisses bottom sheet', (tester) async {
        await tester.pumpWidget(createTestWidget());
        await openBottomSheet(tester);

        expect(find.text('Playback Settings'), findsOneWidget);

        await tester.tap(find.byIcon(Icons.close));
        await tester.pumpAndSettle();

        expect(find.text('Playback Settings'), findsNothing);
      });
    });

    group('Constants', () {
      test('animationDuration is 200ms', () {
        expect(
          SettingsBottomSheet.animationDuration,
          const Duration(milliseconds: 200),
        );
      });
    });

    group('Accessibility', () {
      testWidgets('settings icon has semantic label', (tester) async {
        await tester.pumpWidget(createTestWidget());
        await openBottomSheet(tester);

        final icon = tester.widget<Icon>(find.byIcon(Icons.settings));
        expect(icon.semanticLabel, 'Settings');
      });

      testWidgets('close button has tooltip', (tester) async {
        await tester.pumpWidget(createTestWidget());
        await openBottomSheet(tester);

        final closeButton = tester.widget<IconButton>(
          find.widgetWithIcon(IconButton, Icons.close),
        );
        expect(closeButton.tooltip, 'Close settings');
      });

      testWidgets('selected quality has semantic label', (tester) async {
        await tester.pumpWidget(createTestWidget());
        await openBottomSheet(tester);

        // Find check_circle icon in Auto tile
        final autoTile = find.ancestor(
          of: find.text('Auto'),
          matching: find.byType(ListTile),
        );
        final checkIcon = tester.widget<Icon>(
          find.descendant(
            of: autoTile,
            matching: find.byIcon(Icons.check_circle),
          ),
        );
        expect(checkIcon.semanticLabel, 'Selected');
      });

      testWidgets('unselected quality has semantic label', (tester) async {
        await tester.pumpWidget(createTestWidget());
        await openBottomSheet(tester);

        // Find circle_outlined icon in 720p tile
        final hdTile = find.ancestor(
          of: find.text('720p'),
          matching: find.byType(ListTile),
        );
        final circleIcon = tester.widget<Icon>(
          find.descendant(
            of: hdTile,
            matching: find.byIcon(Icons.circle_outlined),
          ),
        );
        expect(circleIcon.semanticLabel, 'Not selected');
      });
    });

    group('Static show method', () {
      testWidgets('show method opens bottom sheet', (tester) async {
        await tester.pumpWidget(
          ProviderScope(
            overrides: [sharedPreferencesProvider.overrideWithValue(mockPrefs)],
            child: MaterialApp(
              home: Scaffold(
                body: Builder(
                  builder: (context) => ElevatedButton(
                    onPressed: () => SettingsBottomSheet.show(context),
                    child: const Text('Show'),
                  ),
                ),
              ),
            ),
          ),
        );

        await tester.tap(find.text('Show'));
        await tester.pumpAndSettle();

        expect(find.text('Playback Settings'), findsOneWidget);
      });
    });
  });
}
