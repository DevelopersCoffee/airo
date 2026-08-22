import 'package:meta/meta.dart';

import 'addon_id.dart';

@immutable
class AddonIdentity {
  const AddonIdentity({
    required this.id,
    required this.version,
    this.manifestDigest = '',
    this.adapterDigest = '',
  });

  final AddonId id;
  final String version;
  final String manifestDigest;
  final String adapterDigest;

  @override
  bool operator ==(Object other) =>
      other is AddonIdentity &&
      other.id == id &&
      other.version == version &&
      other.manifestDigest == manifestDigest &&
      other.adapterDigest == adapterDigest;

  @override
  int get hashCode => Object.hash(id, version, manifestDigest, adapterDigest);

  @override
  String toString() => '${id.value}@$version';
}
