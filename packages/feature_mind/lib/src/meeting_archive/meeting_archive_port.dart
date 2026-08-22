import '../mind_service.dart';
import '../search/semantic_search_ranker.dart';
import '../whisper/api/meetings.dart' as rust;

/// Shell-provided seam for chat/tools to query the meeting archive (#1770).
///
/// Null when the composing shell did not mount the scribe (`createService`
/// absent). Tools degrade to navigation rather than inventing transcript text.
abstract class MeetingArchivePort {
  Future<List<rust.SearchHit>> search(String query);

  /// Keyword+semantic union plus PM-05 provenance. Cosine is not proof.
  Future<SemanticRankResult> searchAligned(String query);

  Future<rust.MeetingRecord?> meeting(String id);

  /// Action items assigned to [ownerName], case-insensitive; null owner matches
  /// unassigned rows only when [ownerName] is empty.
  Future<List<rust.MeetingActionItemRecord>> actionItemsForOwner(
    String ownerName,
  );

  /// Latest saved meeting with non-empty [rust.MeetingRecord.minutes], or null.
  Future<rust.MeetingRecord?> latestWithMinutes();

  /// Minutes for [meetingId], or null when missing or empty.
  Future<String?> minutesForMeeting(String meetingId);
}

/// Adapts [MindService] to [MeetingArchivePort].
class MindServiceMeetingArchivePort implements MeetingArchivePort {
  MindServiceMeetingArchivePort(this._service);

  final MindService _service;

  @override
  Future<List<rust.SearchHit>> search(String query) => _service.search(query);

  @override
  Future<SemanticRankResult> searchAligned(String query) =>
      _service.searchWithAlignment(query);

  @override
  Future<rust.MeetingRecord?> meeting(String id) => _service.meeting(id);

  @override
  Future<List<rust.MeetingActionItemRecord>> actionItemsForOwner(
    String ownerName,
  ) async {
    final meetings = await _service.meetings();
    final normalized = ownerName.trim().toLowerCase();
    final hits = <rust.MeetingActionItemRecord>[];
    for (final meeting in meetings) {
      for (final item in meeting.actionItems) {
        if (normalized == 'me') {
          if (item.status == rust.MeetingActionStatus.open ||
              item.status == rust.MeetingActionStatus.inProgress) {
            hits.add(item);
          }
          continue;
        }
        final owner = item.owner?.trim().toLowerCase() ?? '';
        if (owner == normalized) {
          hits.add(item);
        }
      }
    }
    return hits;
  }

  @override
  Future<rust.MeetingRecord?> latestWithMinutes() async {
    final meetings = await _service.meetings();
    if (meetings.isEmpty) return null;
    meetings.sort((a, b) => b.recordedAt.compareTo(a.recordedAt));
    for (final meeting in meetings) {
      if (meeting.minutes.trim().isNotEmpty) {
        return meeting;
      }
    }
    return null;
  }

  @override
  Future<String?> minutesForMeeting(String meetingId) async {
    final meeting = await _service.meeting(meetingId);
    final minutes = meeting?.minutes.trim() ?? '';
    return minutes.isEmpty ? null : minutes;
  }
}
