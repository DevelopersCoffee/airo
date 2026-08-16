import '../bridges/mind_speech_bridge.dart';
import '../whisper/api/meetings.dart' as rust;

/// Writes action-item status back through the MIND-LLM-16 / ADR-0022 path:
/// re-`save` the same meeting id with updated `actionItems` (append-only
/// store, latest wins on read). No new Rust API.
class MeetingIrStatusWriter {
  const MeetingIrStatusWriter(this._speech);

  final MindSpeechBridge _speech;

  /// Parses `m{recordedAtMs}` back to the millisecond identity `saveMeeting`
  /// used. Falls back to `recordedAt * 1000` for legacy ids.
  static int recordedAtMsFor(rust.MeetingRecord meeting) {
    final id = meeting.id;
    if (id.startsWith('m')) {
      final parsed = int.tryParse(id.substring(1));
      if (parsed != null) return parsed;
    }
    return meeting.recordedAt.toInt() * 1000;
  }

  /// Toggles / sets one action item's [status], re-saving the full meeting.
  Future<rust.MeetingRecord> updateActionStatus({
    required rust.MeetingRecord meeting,
    required String actionItemId,
    required rust.MeetingActionStatus status,
  }) async {
    final updatedItems = [
      for (final item in meeting.actionItems)
        if (item.id == actionItemId)
          rust.MeetingActionItemRecord(
            id: item.id,
            task: item.task,
            owner: item.owner,
            due: item.due,
            status: status,
            evidenceSegmentIds: item.evidenceSegmentIds,
          )
        else
          item,
    ];

    final doc = await _speech.getTranscript(meeting.id);
    final segments = doc == null
        ? const <TranscriptSegment>[]
        : doc.segments.map(toTranscriptSegment).toList(growable: false);
    final wavPath = doc?.audioPath ?? '';

    await _speech.save(
      title: meeting.title,
      recordedAtMs: recordedAtMsFor(meeting),
      transcript: meeting.transcript,
      minutes: meeting.minutes,
      model: meeting.model,
      segments: segments,
      wavPath: wavPath,
      decisions: meeting.decisions,
      actionItems: updatedItems,
      metrics: meeting.metrics,
    );

    return rust.MeetingRecord(
      id: meeting.id,
      title: meeting.title,
      recordedAt: meeting.recordedAt,
      transcript: meeting.transcript,
      minutes: meeting.minutes,
      model: meeting.model,
      decisions: meeting.decisions,
      actionItems: updatedItems,
      metrics: meeting.metrics,
    );
  }
}
