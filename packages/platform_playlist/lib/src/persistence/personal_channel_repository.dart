import 'dart:convert';

import 'package:core_data/core_data.dart';
import 'package:crypto/crypto.dart';
import 'package:platform_channels/platform_channels.dart';

final class PersonalChannelLimitException implements Exception {
  const PersonalChannelLimitException(this.maximum);

  final int maximum;

  @override
  String toString() => 'Personal channels are limited to $maximum entries.';
}

/// Local persistence for single streams received through Airo channel links.
///
/// This store is deliberately separate from M3U/Xtream content sources: a
/// master HLS manifest is a playable channel, not a playlist containing
/// `#EXTINF` channel records.
final class PersonalChannelRepository {
  PersonalChannelRepository(this._store);

  static const int maximumChannels = 100;
  static const int _schemaVersion = 1;
  static const String _indexKey = 'personal_channels.index.v1';
  static const String _recordPrefix = 'personal_channels.record.v1.';

  final KeyValueStore _store;

  Future<List<IPTVChannel>> list() async {
    final fingerprints = await _store.getStringList(_indexKey) ?? const [];
    final channels = <IPTVChannel>[];
    final validFingerprints = <String>[];

    for (final fingerprint in fingerprints) {
      final encoded = await _store.getString('$_recordPrefix$fingerprint');
      if (encoded == null) continue;
      try {
        final decoded = jsonDecode(encoded) as Map<String, dynamic>;
        if (decoded['version'] != _schemaVersion) continue;
        final channel = IPTVChannel.fromJson(
          decoded['channel'] as Map<String, dynamic>,
        );
        channels.add(channel);
        validFingerprints.add(fingerprint);
      } on Object {
        await _store.remove('$_recordPrefix$fingerprint');
      }
    }

    if (validFingerprints.length != fingerprints.length) {
      await _store.setStringList(_indexKey, validFingerprints);
    }
    return List.unmodifiable(channels);
  }

  Future<IPTVChannel?> findByStreamUrl(String streamUrl) async {
    final normalized = _normalize(streamUrl);
    if (normalized == null) return null;
    final fingerprint = _fingerprint(normalized);
    final encoded = await _store.getString('$_recordPrefix$fingerprint');
    if (encoded == null) return null;
    try {
      final decoded = jsonDecode(encoded) as Map<String, dynamic>;
      if (decoded['version'] != _schemaVersion) return null;
      return IPTVChannel.fromJson(decoded['channel'] as Map<String, dynamic>);
    } on Object {
      return null;
    }
  }

  IPTVChannel buildChannel({required String name, required String streamUrl}) {
    final normalizedName = name.trim();
    if (normalizedName.isEmpty || normalizedName.length > 120) {
      throw ArgumentError.value(name, 'name', 'Enter a valid channel name.');
    }
    final normalizedUrl = _normalize(streamUrl);
    if (normalizedUrl == null) {
      throw ArgumentError.value(
        streamUrl,
        'streamUrl',
        'Enter a valid public HTTP(S) stream URL.',
      );
    }
    final fingerprint = _fingerprint(normalizedUrl);
    return IPTVChannel.fromM3U(
      name: normalizedName,
      url: normalizedUrl,
      group: 'Personal channels',
    ).copyWith(
      id: 'personal:$fingerprint',
      provenance: ChannelImportProvenance.unmatched,
    );
  }

  Future<IPTVChannel> upsert({
    required String name,
    required String streamUrl,
  }) async {
    final channel = buildChannel(name: name, streamUrl: streamUrl);
    final fingerprint = channel.id.substring('personal:'.length);
    final fingerprints = [...?await _store.getStringList(_indexKey)];
    final exists = fingerprints.contains(fingerprint);
    if (!exists && fingerprints.length >= maximumChannels) {
      throw const PersonalChannelLimitException(maximumChannels);
    }

    final saved = await _store.setString(
      '$_recordPrefix$fingerprint',
      jsonEncode({'version': _schemaVersion, 'channel': channel.toJson()}),
    );
    if (!saved) {
      throw StateError('Could not save the personal channel record.');
    }
    if (!exists) {
      fingerprints.add(fingerprint);
      final indexed = await _store.setStringList(_indexKey, fingerprints);
      if (!indexed) {
        await _store.remove('$_recordPrefix$fingerprint');
        throw StateError('Could not index the personal channel record.');
      }
    }
    return channel;
  }

  Future<void> remove(String channelId) async {
    if (!channelId.startsWith('personal:')) return;
    final fingerprint = channelId.substring('personal:'.length);
    await _store.remove('$_recordPrefix$fingerprint');
    final fingerprints = [...?await _store.getStringList(_indexKey)]
      ..remove(fingerprint);
    await _store.setStringList(_indexKey, fingerprints);
  }

  static String? _normalize(String value) {
    final validation = AiroPlaylistUrlPolicy.validateShareStreamUrl(value);
    final uri = validation.uri;
    if (uri == null) return null;
    return uri
        .replace(scheme: uri.scheme.toLowerCase(), host: uri.host.toLowerCase())
        .toString();
  }

  static String _fingerprint(String normalizedUrl) =>
      sha256.convert(utf8.encode(normalizedUrl)).toString();
}
