import 'package:core_entitlements/core_entitlements.dart';
import 'package:feature_iptv/feature_iptv.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  testWidgets('CE default renders no richer-context surface', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final preferences = await SharedPreferences.getInstance();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [sharedPreferencesProvider.overrideWithValue(preferences)],
        child: const MaterialApp(
          home: Scaffold(body: RicherContextPrototypeConsentPanel()),
        ),
      ),
    );

    expect(find.textContaining('Internal richer context'), findsNothing);
  });

  testWidgets('explicit toggles unlock attributed internal surfaces', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    final preferences = await SharedPreferences.getInstance();
    final provider = _FixtureProvider();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(preferences),
          richerContextEntitlementsProvider.overrideWithValue(
            const LaunchPromoEntitlements(),
          ),
          richerContextAdapterProvider.overrideWithValue(provider),
        ],
        child: MaterialApp(
          home: Scaffold(
            body: ListView(
              children: [
                const RicherContextPrototypeConsentPanel(),
                ProgrammeEnrichmentPrototypeCard(request: _programmeRequest),
                SportsFixturesPrototypeShelf(request: _sportsRequest),
              ],
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Internal richer context · Fixture Provider'), findsOne);
    expect(provider.programmeCalls, 0);
    expect(provider.sportsCalls, 0);

    await tester.tap(find.byType(Switch).first);
    await tester.tap(find.byType(Switch).last);
    await tester.pumpAndSettle();

    expect(find.textContaining('A fixture synopsis.'), findsOne);
    expect(find.textContaining('2026 · 8.4 · Drama, Mystery'), findsOne);
    expect(find.text('India vs Australia'), findsOne);
    expect(find.textContaining('Prototype attribution'), findsWidgets);
    expect(
      find.byWidgetPredicate(
        (widget) =>
            widget is Semantics &&
            widget.properties.label == 'Poster for Example Programme',
      ),
      findsOneWidget,
    );
    expect(provider.programmeCalls, 1);
    expect(provider.sportsCalls, 1);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpAndSettle();
  });
}

final _programmeRequest = ProgrammeMetadataRequest(
  title: 'Example Programme',
  startsAt: DateTime.utc(2026, 7, 27, 12),
);

final _sportsRequest = SportsFixturesRequest(
  channelId: 'sports.in',
  isSportsChannel: true,
  from: DateTime.utc(2026, 7, 27),
  to: DateTime.utc(2026, 7, 28),
);

final class _FixtureProvider implements RicherContextProvider {
  _FixtureProvider()
    : descriptor = RicherContextProviderDescriptor(
        id: 'fixture',
        name: 'Fixture Provider',
        licenseDecision: ProviderLicenseDecision.approved,
        licenseReviewedAt: DateTime.utc(2026, 7, 27),
        attribution: RicherContextAttribution(
          providerId: 'fixture',
          providerName: 'Fixture Provider',
          notice: 'Prototype attribution',
          url: Uri.https('example.invalid', '/attribution'),
        ),
      );

  @override
  final RicherContextProviderDescriptor descriptor;
  int programmeCalls = 0;
  int sportsCalls = 0;

  @override
  Future<ProgrammeEnrichment?> enrichProgramme(
    ProgrammeMetadataRequest request,
  ) async {
    programmeCalls++;
    return ProgrammeEnrichment(
      providerItemId: 'programme-1',
      title: request.title,
      synopsis: 'A fixture synopsis.',
      year: 2026,
      rating: 8.4,
      genres: const ['Drama', 'Mystery'],
      posterUrl: Uri.https('example.invalid', '/poster.jpg'),
      attribution: descriptor.attribution,
    );
  }

  @override
  Future<AttributedSportsDeskRow?> fetchSportsFixtures(
    SportsFixturesRequest request,
  ) async {
    sportsCalls++;
    return AttributedSportsDeskRow(
      row: SportsDeskRow(
        rowId: 'fixtures',
        title: 'Live now / upcoming',
        fixtures: [
          SportsFixture(
            eventId: 'event-1',
            title: 'India vs Australia',
            sport: 'Cricket',
            startsAt: request.from,
          ),
        ],
      ),
      attribution: descriptor.attribution,
    );
  }
}
