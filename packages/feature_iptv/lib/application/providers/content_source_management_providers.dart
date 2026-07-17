import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:core_data/core_data.dart';
import 'package:platform_playlist/platform_playlist.dart';

import '../content_source_store.dart';
import 'content_source_providers.dart';
import 'iptv_providers.dart';

export 'content_source_providers.dart'
    show secureStoreProvider, contentSourceCredentialStoreProvider;

/// Persists the user's configured content sources
/// ([ContentSourceConfig]/[ContentSourceStore], Task 1), backed by the same
/// [sharedPreferencesProvider] the rest of `feature_iptv` uses.
final contentSourceStoreProvider = Provider<ContentSourceStore>((ref) {
  return ContentSourceStore(
    PreferencesStore(ref.watch(sharedPreferencesProvider)),
  );
});

/// The list of configured content sources, as read from
/// [contentSourceStoreProvider]. Invalidated by
/// [addM3uContentSourceProvider] and [removeContentSourceProvider] so UI
/// consumers refresh after a mutation.
final configuredContentSourcesProvider =
    FutureProvider<List<ContentSourceConfig>>((ref) async {
      return ref.watch(contentSourceStoreProvider).getAll();
    });

/// Adds a new M3U [ContentSourceConfig] and invalidates
/// [configuredContentSourcesProvider].
final addM3uContentSourceProvider =
    FutureProvider.family<void, ({String label, String url})>((
      ref,
      args,
    ) async {
      final id = 'm3u-${DateTime.now().microsecondsSinceEpoch}';
      await ref
          .watch(contentSourceStoreProvider)
          .add(
            ContentSourceConfig(
              id: id,
              kind: ContentSourceKind.m3u,
              label: args.label,
              url: args.url,
            ),
          );
      ref.invalidate(configuredContentSourcesProvider);
    });

/// Adds a new Xtream Codes [ContentSourceConfig] and stores its
/// credentials via [contentSourceCredentialStoreProvider], keyed on the
/// generated config id so [removeContentSourceProvider] deletes the same
/// credential slot.
final addXtreamContentSourceProvider =
    FutureProvider.family<
      void,
      ({String label, String url, String username, String password})
    >((ref, args) async {
      final id = 'xtream-${DateTime.now().microsecondsSinceEpoch}';
      await ref
          .watch(contentSourceCredentialStoreProvider)
          .save(
            ContentSourceCredentialRef(id),
            ContentSourceCredentials(
              username: args.username,
              password: args.password,
            ),
          );
      await ref
          .watch(contentSourceStoreProvider)
          .add(
            ContentSourceConfig(
              id: id,
              kind: ContentSourceKind.xtream,
              label: args.label,
              url: args.url,
            ),
          );
      ref.invalidate(configuredContentSourcesProvider);
    });

/// Adds a new Stalker Portal [ContentSourceConfig]. Stalker auth uses the
/// device MAC address (persisted in the config itself, not a secret), so
/// no credential store write is needed.
final addStalkerContentSourceProvider =
    FutureProvider.family<
      void,
      ({String label, String url, String macAddress})
    >((ref, args) async {
      final id = 'stalker-${DateTime.now().microsecondsSinceEpoch}';
      await ref
          .watch(contentSourceStoreProvider)
          .add(
            ContentSourceConfig(
              id: id,
              kind: ContentSourceKind.stalker,
              label: args.label,
              url: args.url,
              macAddress: args.macAddress,
            ),
          );
      ref.invalidate(configuredContentSourcesProvider);
    });

/// Adds a new Jellyfin [ContentSourceConfig] and stores its credentials
/// (username + password/api-key) via [contentSourceCredentialStoreProvider].
final addJellyfinContentSourceProvider =
    FutureProvider.family<
      void,
      ({String label, String url, String username, String password})
    >((ref, args) async {
      final id = 'jellyfin-${DateTime.now().microsecondsSinceEpoch}';
      await ref
          .watch(contentSourceCredentialStoreProvider)
          .save(
            ContentSourceCredentialRef(id),
            ContentSourceCredentials(
              username: args.username,
              password: args.password,
            ),
          );
      await ref
          .watch(contentSourceStoreProvider)
          .add(
            ContentSourceConfig(
              id: id,
              kind: ContentSourceKind.jellyfin,
              label: args.label,
              url: args.url,
            ),
          );
      ref.invalidate(configuredContentSourcesProvider);
    });

/// Removes a content source by id and deletes any credential stored for it
/// via [contentSourceCredentialStoreProvider] — otherwise a removed source
/// leaves an orphaned secret behind with no owner. Invalidates
/// [configuredContentSourcesProvider] afterwards.
final removeContentSourceProvider = FutureProvider.family<void, String>((
  ref,
  id,
) async {
  await ref.watch(contentSourceStoreProvider).remove(id);
  await ref
      .watch(contentSourceCredentialStoreProvider)
      .delete(ContentSourceCredentialRef(id));
  ref.invalidate(configuredContentSourcesProvider);
});
