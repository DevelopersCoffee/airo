/// Raw-audio retention policy (#1656 AC5).
///
/// Product decision, not a hardcoded constant: a person who records meetings
/// may want the source audio kept (to re-play a moment the transcript
/// flattened) or deleted the moment a transcript exists (storage budget, or
/// just not wanting a room's raw audio sitting on disk indefinitely). Settings
/// exposes this as a toggle backed by [AudioRetentionPreference]; nothing in
/// the processing queue decides this on its own.
library;

/// What happens to a meeting's source `.m4a` once its transcript is durable.
enum AudioRetentionPolicy {
  /// Keep the raw audio alongside the transcript indefinitely.
  keepAfterTranscript,

  /// Delete the raw audio as soon as the transcript is saved. The transcript
  /// and minutes remain; only the source recording is reclaimed.
  deleteAfterTranscript;

  static const AudioRetentionPolicy fallback = keepAfterTranscript;

  String get storageValue => name;

  static AudioRetentionPolicy fromStorageValue(String? value) {
    return AudioRetentionPolicy.values.firstWhere(
      (policy) => policy.storageValue == value,
      orElse: () => fallback,
    );
  }
}
