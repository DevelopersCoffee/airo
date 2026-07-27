import 'package:core_entitlements/core_entitlements.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:platform_epg/platform_epg.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'iptv_providers.dart';

/// Host/overlay swap points. CE deliberately has no provider adapter and no
/// entitlement, so it cannot make a richer-context request.
final richerContextEntitlementsProvider = Provider<Entitlements>(
  (ref) => const NoEntitlements(),
);

final richerContextAdapterProvider = Provider<RicherContextProvider?>(
  (ref) => null,
);

final richerContextConsentProvider =
    StateNotifierProvider<RicherContextConsentController, RicherContextConsent>(
      (ref) {
        final adapter = ref.watch(richerContextAdapterProvider);
        return RicherContextConsentController(
          providerId: adapter?.descriptor.id ?? '',
          preferences: ref.watch(sharedPreferencesProvider),
        );
      },
    );

final class RicherContextConsentController
    extends StateNotifier<RicherContextConsent> {
  RicherContextConsentController({
    required String providerId,
    required SharedPreferences preferences,
  }) : _preferences = preferences,
       super(
         RicherContextConsent(
           providerId: providerId,
           metadataEnabled:
               providerId.isNotEmpty &&
               (preferences.getBool(_metadataKey(providerId)) ?? false),
           sportsEnabled:
               providerId.isNotEmpty &&
               (preferences.getBool(_sportsKey(providerId)) ?? false),
         ),
       );

  final SharedPreferences _preferences;

  static String _metadataKey(String id) => 'richer_context.$id.metadata';
  static String _sportsKey(String id) => 'richer_context.$id.sports';

  Future<void> setMetadataEnabled(bool enabled) async {
    if (state.providerId.isEmpty) return;
    state = RicherContextConsent(
      providerId: state.providerId,
      metadataEnabled: enabled,
      sportsEnabled: state.sportsEnabled,
    );
    await _preferences.setBool(_metadataKey(state.providerId), enabled);
  }

  Future<void> setSportsEnabled(bool enabled) async {
    if (state.providerId.isEmpty) return;
    state = RicherContextConsent(
      providerId: state.providerId,
      metadataEnabled: state.metadataEnabled,
      sportsEnabled: enabled,
    );
    await _preferences.setBool(_sportsKey(state.providerId), enabled);
  }
}

final richerContextCoordinatorProvider = Provider<RicherContextCoordinator>((
  ref,
) {
  return RicherContextCoordinator(
    entitlements: ref.watch(richerContextEntitlementsProvider),
    provider: ref.watch(richerContextAdapterProvider),
    consent: ref.watch(richerContextConsentProvider),
  );
});

final programmeEnrichmentPrototypeProvider =
    FutureProvider.family<ProgrammeEnrichment?, ProgrammeMetadataRequest>((
      ref,
      request,
    ) {
      return ref
          .watch(richerContextCoordinatorProvider)
          .enrichProgramme(request);
    });

final sportsFixturesPrototypeProvider =
    FutureProvider.family<AttributedSportsDeskRow?, SportsFixturesRequest>((
      ref,
      request,
    ) {
      return ref
          .watch(richerContextCoordinatorProvider)
          .fetchSportsFixtures(request);
    });
