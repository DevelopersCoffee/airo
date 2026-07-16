import 'package:equatable/equatable.dart';

/// The wire protocol a [ContentSource] speaks.
enum ContentSourceKind {
  m3u('m3u'),
  xtream('xtream'),
  stalker('stalker'),
  jellyfin('jellyfin');

  const ContentSourceKind(this.stableId);

  final String stableId;
}

/// What a source can supply, independent of how it's fetched.
class ContentSourceCapabilities extends Equatable {
  const ContentSourceCapabilities({
    this.hasEpg = false,
    this.hasVod = false,
    this.hasCatchup = false,
  });

  final bool hasEpg;
  final bool hasVod;
  final bool hasCatchup;

  @override
  List<Object?> get props => [hasEpg, hasVod, hasCatchup];
}

/// Opaque reference to credentials held in [ContentSourceCredentialStore].
///
/// Never carries the secret itself — only a lookup key — so a
/// [ContentSource] can be logged, compared, or stored without ever risking
/// an unredacted username/password. Mirrors `CompactEpgSourceRef` in
/// `platform_epg`.
class ContentSourceCredentialRef extends Equatable {
  const ContentSourceCredentialRef(this.key);

  final String key;

  @override
  List<Object?> get props => [key];

  @override
  String toString() => 'ContentSourceCredentialRef(redacted)';
}

/// A user-configured content source: where channels/VOD/EPG come from.
///
/// Subclasses hold only non-secret configuration (server URL, playlist URL)
/// plus a [ContentSourceCredentialRef] where auth is required — the actual
/// credentials live in [ContentSourceCredentialStore], never inline here.
abstract class ContentSource extends Equatable {
  const ContentSource({
    required this.id,
    required this.label,
    required this.capabilities,
  });

  final String id;
  final String label;
  final ContentSourceCapabilities capabilities;

  ContentSourceKind get kind;

  @override
  List<Object?> get props => [id, label, capabilities, kind];

  @override
  String toString() =>
      'ContentSource(kind: ${kind.stableId}, id: $id, label: $label)';
}
