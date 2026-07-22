// Pure progress math for guide program blocks (Live Grid Navigation), shared
// by phone and TV guide surfaces.

/// Progress of a program as a fraction in [0, 1].
///
/// Zero-duration or inverted programs return 0 to avoid division by zero.
double epgProgramProgress({
  required DateTime startsAt,
  required DateTime endsAt,
  required DateTime now,
}) {
  final total = endsAt.difference(startsAt).inMilliseconds;
  if (total <= 0) return 0;

  final elapsed = now.difference(startsAt).inMilliseconds;
  return (elapsed / total).clamp(0.0, 1.0);
}

/// Whether [now] falls inside `[startsAt, endsAt)`.
bool epgProgramIsAiring({
  required DateTime startsAt,
  required DateTime endsAt,
  required DateTime now,
}) {
  return !now.isBefore(startsAt) && now.isBefore(endsAt);
}

/// Whole minutes remaining until [endsAt], clamped at 0.
int epgProgramMinutesLeft({required DateTime endsAt, required DateTime now}) {
  final minutes = endsAt.difference(now).inMinutes;
  return minutes < 0 ? 0 : minutes;
}
