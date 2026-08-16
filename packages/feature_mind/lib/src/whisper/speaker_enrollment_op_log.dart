import '../runtime/mind_runtime.dart' show MindPortUnavailable;
import '../runtime/models/log_models.dart';
import '../runtime/ports/operation_log_port.dart';

/// Appends the timeline-visible half of a speaker enrollment (#504).
///
/// The embedding content is durable in [SpeakerEnrollmentOperationLog]; this
/// op makes "remembered speaker" visible on the Mind timeline the same way
/// [appendMeetingIrExtractedOp] does for Meeting IR.
Future<int?> appendSpeakerEnrolledOp({
  required OperationLogPort log,
  required String profileId,
  required String displayName,
  String contextId = '',
}) async {
  try {
    return await log.append(
      kind: MindOpKind.speakerEnrolled,
      title: 'Remembered $displayName',
      contextId: contextId,
      detail: '$profileId;$displayName',
    );
  } on MindPortUnavailable {
    return null;
  }
}
