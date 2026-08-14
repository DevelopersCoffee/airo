import '../runtime/mind_runtime.dart' show MindPortUnavailable;
import '../runtime/models/log_models.dart';
import '../runtime/ports/operation_log_port.dart';

/// Appends the log-visible half of a Meeting IR write (`ADR-0022 §1.2`).
///
/// A `MeetingIr` write has two halves: the content half — decisions, action
/// items and metrics landing as fields on the `Meeting` record via
/// `saveMeeting` — and this, the log-visible half: one
/// `MindOpKind.meetingIrExtracted` entry, so a future timeline projection
/// (#1213-#1220) can show "minutes extracted" without a history backfill,
/// the same reason `audio_scribe_consent_gate.dart` appends `MindOpKind
/// .consent` around every recording rather than treating it as inferable
/// after the fact.
///
/// Degrades gracefully, exactly like `quick_capture_controller.dart`'s
/// `_guessContext`/`commit`: [OperationLogPort.append] is a no-op today
/// (`RustMindRuntime`'s log is a `MindPortUnavailable` stub), and a missing
/// operation log must cost the timeline entry, never the meeting -- the IR
/// itself is already durable on the `Meeting` record by the time this is
/// called, independent of whether this call succeeds.
///
/// Returns the appended op's sequence number, or `null` when the log was
/// unavailable.
Future<int?> appendMeetingIrExtractedOp({
  required OperationLogPort log,
  required String meetingId,
  required String meetingTitle,
  required String contextId,
  required int decisionCount,
  required int actionItemCount,
  required int metricCount,
}) async {
  try {
    return await log.append(
      kind: MindOpKind.meetingIrExtracted,
      title: '$meetingTitle minutes extracted',
      contextId: contextId,
      detail:
          '$meetingId;decisions=$decisionCount;'
          'action_items=$actionItemCount;metrics=$metricCount',
    );
  } on MindPortUnavailable {
    return null;
  }
}
