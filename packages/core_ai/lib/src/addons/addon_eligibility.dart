import 'package:meta/meta.dart';

@immutable
class AddonEligibility {
  const AddonEligibility({
    this.enabled = false,
    this.pinned = false,
    this.grantedScopes = const {},
    this.quarantined = false,
    this.revoked = false,
  });

  final bool enabled;
  final bool pinned;
  final Set<String> grantedScopes;
  final bool quarantined;
  final bool revoked;

  bool get isEligible =>
      enabled && !quarantined && !revoked && grantedScopes.isNotEmpty;

  bool hasScope(String scope) => grantedScopes.contains(scope);

  AddonEligibility copyWith({
    bool? enabled,
    bool? pinned,
    Set<String>? grantedScopes,
    bool? quarantined,
    bool? revoked,
  }) => AddonEligibility(
    enabled: enabled ?? this.enabled,
    pinned: pinned ?? this.pinned,
    grantedScopes: grantedScopes ?? this.grantedScopes,
    quarantined: quarantined ?? this.quarantined,
    revoked: revoked ?? this.revoked,
  );
}
