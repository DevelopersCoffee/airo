import 'package:flutter/foundation.dart';

import 'hotkey_combination.dart';

/// One caller's ask to own a global hotkey.
///
/// [id] namespaces registrations so two features -- Quick Capture (#1454)
/// and the Everything Browser palette (#1461) -- can each hold their own
/// binding through the same [GlobalHotkeyRegistrar] without colliding.
/// [description] is shown back to the user in permission-explanation and
/// conflict-rebind copy, so it should read as a sentence fragment naming the
/// action, e.g. "Open Quick Capture".
@immutable
class HotkeyRequest {
  const HotkeyRequest({
    required this.id,
    required this.combination,
    required this.description,
  });

  final String id;
  final HotkeyCombination combination;
  final String description;
}
