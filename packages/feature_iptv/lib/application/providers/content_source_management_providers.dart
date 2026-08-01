import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:platform_playlist/platform_playlist.dart';

import '../content_source_store.dart';
import '../mutable_xmltv_compact_epg_repository.dart';
import 'content_source_providers.dart';
import 'iptv_providers.dart';
import 'provider_health_providers.dart';

export 'content_source_providers.dart'
    show secureStoreProvider, contentSourceCredentialStoreProvider;

class XtreamAuthenticationException implements Exception {
  const XtreamAuthenticationException([
    this.message = 'Xtream credentials were not accepted.',
  ]);

  final String message;

  @override
  String toString() => message;
}

typedef XtreamAuthenticator =
    Future<XtreamAuthResult> Function({
      required String serverUrl,
      required String username,
      required String password,
    });

final xtreamAuthenticatorProvider = Provider<XtreamAuthenticator>((ref) {
  return ({
    required String serverUrl,
    required String username,
    required String password,
  }) {
    return XtreamClient(
      dio: ref.read(dioProvider),
      serverUrl: serverUrl,
      username: username,
      password: password,
    ).authenticate();
  };
});

typedef StalkerAuthenticator =
    Future<void> Function({
      required String portalUrl,
      required String macAddress,
    });

final stalkerAuthenticatorProvider = Provider<StalkerAuthenticator>((ref) {
  return ({required String portalUrl, required String macAddress}) async {
    await StalkerClient(
      dio: ref.read(dioProvider),
      serverUrl: portalUrl,
      macAddress: macAddress,
    ).handshake();
  };
});

Future<void> _activateSource(Ref ref, String id) async {
  await ref.read(contentSourceStoreProvider).setActiveSourceId(id);
  ref.invalidate(activeContentSourceProvider);
  ref.invalidate(iptvChannelsProvider);
}

/// Adds a new M3U [ContentSourceConfig] and invalidates
/// [configuredContentSourcesProvider].
final addM3uContentSourceProvider = FutureProvider.autoDispose
    .family<void, ({String label, String url})>((ref, args) async {
      // autoDispose has no external listener across this one-shot mutation
      // (callers only `ref.read(...).future` it once) — keepAlive prevents
      // the provider from being torn down mid-`await`, which would silently
      // truncate the write.
      final keepAlive = ref.keepAlive();
      try {
        final label = args.label.trim();
        final url = _validatedHttpUrl(args.url, fieldName: 'playlist URL');
        if (label.isEmpty) {
          throw ArgumentError.value(args.label, 'label', 'Enter a label.');
        }
        final existing = await ref.read(contentSourceStoreProvider).getAll();
        final legacyUrl = ref.read(m3uParserProvider).getPlaylistUrl();
        if (legacyUrl == url ||
            existing.any(
              (source) =>
                  source.kind == ContentSourceKind.m3u && source.url == url,
            )) {
          throw const DuplicatePlaylistSourceException();
        }
        final id = 'm3u-${DateTime.now().microsecondsSinceEpoch}';
        await ref
            .watch(contentSourceStoreProvider)
            .add(
              ContentSourceConfig(
                id: id,
                kind: ContentSourceKind.m3u,
                label: label,
                url: url,
              ),
            );
        await _activateSource(ref, id);
        ref.invalidate(iptvChannelsProvider);
        ref.invalidate(configuredM3uChannelsProvider);
        ref.invalidate(configuredXtreamChannelsProvider);
        ref.invalidate(configuredContentSourcesProvider);
      } finally {
        keepAlive.close();
      }
    }, retry: (_, _) => null);

/// Adds a new Xtream Codes [ContentSourceConfig] and stores its
/// credentials via [contentSourceCredentialStoreProvider], keyed on the
/// generated config id so [removeContentSourceProvider] deletes the same
/// credential slot.
final addXtreamContentSourceProvider =
    FutureProvider.family<
      void,
      ({String label, String url, String username, String password})
    >((ref, args) async {
      final keepAlive = ref.keepAlive();
      final id = 'xtream-${DateTime.now().microsecondsSinceEpoch}';
      final XtreamAuthResult auth;
      try {
        auth = await ref.read(xtreamAuthenticatorProvider)(
          serverUrl: args.url,
          username: args.username,
          password: args.password,
        );
      } catch (_) {
        throw const XtreamAuthenticationException(
          'Could not verify the Xtream account.',
        );
      }
      if (!auth.isAuthenticated ||
          auth.status.toLowerCase() == 'expired' ||
          (auth.expiresAt?.isBefore(DateTime.now().toUtc()) ?? false)) {
        throw const XtreamAuthenticationException();
      }
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
              accountStatus: auth.status,
              accountExpiresAt: auth.expiresAt,
              maxConnections: auth.maxConnections,
            ),
          );
      await _activateSource(ref, id);
      ref.invalidate(iptvChannelsProvider);
      ref.invalidate(configuredXtreamChannelsProvider);
      ref.invalidate(configuredContentSourcesProvider);
      keepAlive.close();
    }, retry: (_, _) => null);

/// Adds a new Stalker Portal [ContentSourceConfig]. The portal MAC is required
/// by the provider protocol and remains local; session tokens stay in memory.
final addStalkerContentSourceProvider =
    FutureProvider.family<
      void,
      ({String label, String url, String macAddress})
    >((ref, args) async {
      final keepAlive = ref.keepAlive();
      final id = 'stalker-${DateTime.now().microsecondsSinceEpoch}';
      try {
        final label = args.label.trim();
        final url = _validatedHttpUrl(args.url, fieldName: 'portal URL');
        final macAddress = args.macAddress.trim().toUpperCase();
        if (label.isEmpty) {
          throw ArgumentError.value(args.label, 'label', 'Enter a label.');
        }
        if (!RegExp(r'^[0-9A-F]{2}(?::[0-9A-F]{2}){5}$').hasMatch(macAddress)) {
          throw ArgumentError.value(
            args.macAddress,
            'macAddress',
            'Enter a MAC address such as AA:BB:CC:DD:EE:FF.',
          );
        }
        try {
          await ref.read(stalkerAuthenticatorProvider)(
            portalUrl: url,
            macAddress: macAddress,
          );
        } catch (_) {
          throw const ContentSourceRuntimeException(
            'Could not verify the Stalker Portal. '
            'Check the portal and MAC address.',
          );
        }
        await ref
            .watch(contentSourceStoreProvider)
            .add(
              ContentSourceConfig(
                id: id,
                kind: ContentSourceKind.stalker,
                label: label,
                url: url,
                macAddress: macAddress,
              ),
            );
        await _activateSource(ref, id);
        ref.invalidate(configuredContentSourcesProvider);
      } finally {
        keepAlive.close();
      }
    }, retry: (_, _) => null);

/// Adds a new Jellyfin [ContentSourceConfig] and stores its credentials
/// (username + password/api-key) via [contentSourceCredentialStoreProvider].
final addJellyfinContentSourceProvider = FutureProvider.autoDispose
    .family<
      void,
      ({String label, String url, String username, String password})
    >((ref, args) async {
      final keepAlive = ref.keepAlive();
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
      keepAlive.close();
    });

/// Removes a content source by id and deletes any credential stored for it
/// via [contentSourceCredentialStoreProvider] — otherwise a removed source
/// leaves an orphaned secret behind with no owner. Invalidates
/// [configuredContentSourcesProvider] afterwards.
final removeContentSourceProvider = FutureProvider.autoDispose
    .family<void, String>((ref, id) async {
      final keepAlive = ref.keepAlive();
      try {
        final sources = await ref.read(contentSourceStoreProvider).getAll();
        ContentSourceConfig? removed;
        for (final source in sources) {
          if (source.id == id) {
            removed = source;
            break;
          }
        }
        if (removed?.kind == ContentSourceKind.m3u) {
          final legacyParser = ref.read(m3uParserProvider);
          if (legacyParser.getPlaylistUrl() == removed!.url) {
            await legacyParser.clearPlaylist();
            ref.invalidate(userPlaylistUrlProvider);
          }
          await ref.read(m3uSourceParserFactoryProvider)(id).clearPlaylist();
        }
        final store = ref.watch(contentSourceStoreProvider);
        await store.remove(id);
        if (await store.getActiveSourceId() == id) {
          await store.setActiveSourceId(null);
        }
        await ref
            .watch(contentSourceCredentialStoreProvider)
            .delete(ContentSourceCredentialRef(id));
        ref.read(providerHealthTrackerProvider).clearFor(id);
        final epgRepository = ref.read(compactEpgRepositoryProvider);
        if (epgRepository is MutableXmltvCompactEpgRepository) {
          epgRepository.removeNamedSource('epg-$id');
        }
        ref.invalidate(iptvChannelsProvider);
        ref.invalidate(configuredM3uChannelsProvider);
        ref.invalidate(configuredXtreamChannelsProvider);
        ref.invalidate(configuredContentSourcesProvider);
        ref.invalidate(activeContentSourceProvider);
      } finally {
        keepAlive.close();
      }
    });

/// Selects the exclusive runtime source. Unsupported saved source kinds stay
/// visible for removal/migration but cannot become Live TV's active source.
final selectContentSourceProvider = FutureProvider.autoDispose
    .family<void, String>((ref, id) async {
      final keepAlive = ref.keepAlive();
      try {
        final sources = await ref.read(configuredContentSourcesProvider.future);
        final matches = sources.where((source) => source.id == id);
        if (matches.isEmpty) {
          throw const ContentSourceRuntimeException(
            'That content source is no longer available.',
          );
        }
        if (matches.single.kind == ContentSourceKind.jellyfin) {
          throw const ContentSourceRuntimeException(
            'Jellyfin is not available in Live TV yet.',
          );
        }
        await _activateSource(ref, id);
      } finally {
        keepAlive.close();
      }
    });

class DuplicatePlaylistSourceException implements Exception {
  const DuplicatePlaylistSourceException();

  @override
  String toString() => 'This playlist source is already configured.';
}

String _validatedHttpUrl(String value, {required String fieldName}) {
  final normalized = value.trim();
  final uri = Uri.tryParse(normalized);
  if (uri == null ||
      uri.host.isEmpty ||
      !(uri.isScheme('http') || uri.isScheme('https'))) {
    throw ArgumentError.value(value, fieldName, 'Enter a valid HTTP(S) URL.');
  }
  return normalized;
}
