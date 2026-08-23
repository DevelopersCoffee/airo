/// Monotonic epoch bumped when add-on grants are revoked or materially changed.
class AddonPermissionEpoch {
  AddonPermissionEpoch._();

  static final AddonPermissionEpoch instance = AddonPermissionEpoch._();

  int _epoch = 0;

  int get current => _epoch;

  void bump() => _epoch++;
}
