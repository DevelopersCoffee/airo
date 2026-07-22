import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import "package:platform_channels/platform_channels.dart";

import 'iptv_providers.dart';

/// SharedPreferences key for the CV-028 "Play on TV" prompt's cooldown.
/// Exposed for tests; not part of the public provider API.
const kIptvCastPromptDismissedUntilKey = 'iptv_cast_prompt_dismissed_until';

/// How long dismissing the "Play on TV" prompt (rule 5: "bounded cooldown")
/// suppresses it before it can be shown again.
const kIptvCastPromptCooldown = Duration(hours: 24);

/// Whether [channel] can produce a Cast media request at all (rule 3: don't
/// show the prompt for a stream that's known to be uncastable). Uses the
/// same [IptvCastMediaAdapter] the actual cast flow uses, so this can never
/// drift from what casting the channel would actually do.
final iptvCastPromptCastableProvider = Provider.family<bool, IPTVChannel>((
  ref,
  channel,
) {
  final adapter = ref.watch(iptvCastMediaAdapterProvider);
  return adapter.toCastRequest(channel).isCastable;
});

/// Persisted "Not now" dismissal for the CV-028 "Play on TV" prompt. Stores
/// only a cooldown expiry timestamp -- never shown again in this window once
/// dismissed (rule 5), independent of app restarts.
class IptvCastPromptCooldown extends Notifier<DateTime?> {
  @override
  DateTime? build() {
    final raw = ref
        .watch(sharedPreferencesProvider)
        .getString(kIptvCastPromptDismissedUntilKey);
    if (raw == null) return null;
    return DateTime.tryParse(raw);
  }

  /// User dismissed the prompt ("Not now"): suppress it for
  /// [kIptvCastPromptCooldown].
  void dismiss() {
    final until = DateTime.now().add(kIptvCastPromptCooldown);
    state = until;
    unawaited(
      ref
          .read(sharedPreferencesProvider)
          .setString(kIptvCastPromptDismissedUntilKey, until.toIso8601String()),
    );
  }
}

final iptvCastPromptCooldownProvider =
    NotifierProvider<IptvCastPromptCooldown, DateTime?>(
      IptvCastPromptCooldown.new,
    );

/// Whether the prompt is currently suppressed by an active cooldown.
final iptvCastPromptDismissedProvider = Provider<bool>((ref) {
  final until = ref.watch(iptvCastPromptCooldownProvider);
  if (until == null) return false;
  return DateTime.now().isBefore(until);
});

/// Single source of truth for whether the CV-028 "Play on TV" prompt should
/// render: an active, castable channel, no Cast session already underway,
/// and no active cooldown from a prior dismissal.
final iptvCastPromptVisibleProvider = Provider<bool>((ref) {
  final channel = ref.watch(currentChannelProvider);
  if (channel == null) return false;
  if (ref.watch(iptvCastPromptDismissedProvider)) return false;

  final isCasting = ref.watch(
    iptvCastProvider.select((state) => state.isCasting),
  );
  if (isCasting) return false;

  return ref.watch(iptvCastPromptCastableProvider(channel));
});
