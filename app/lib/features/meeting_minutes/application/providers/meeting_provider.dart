import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../domain/models/meeting_models.dart';
import '../../domain/services/meeting_service.dart';

/// Meeting service provider - WIP
final meetingServiceProvider = Provider<MeetingService>((ref) {
  return FakeMeetingService();
});

/// Active recording provider - WIP
final activeRecordingProvider = StateProvider<MeetingRecording?>((ref) {
  return null;
});

/// Meeting minutes list provider - WIP
final meetingMinutesListProvider = FutureProvider<List<MeetingMinutes>>((
  ref,
) async {
  final service = ref.watch(meetingServiceProvider);
  return service.listMeetingMinutes();
});

/// Meeting minutes detail provider - WIP
final meetingMinutesDetailProvider =
    FutureProvider.family<MeetingMinutes?, String>((ref, id) async {
      final service = ref.watch(meetingServiceProvider);
      return service.getMeetingMinutes(id);
    });

/// Meeting controller provider
final meetingControllerProvider = Provider<MeetingController>((ref) {
  final service = ref.watch(meetingServiceProvider);
  return MeetingController(service, ref);
});

/// Meeting controller for managing meeting operations
class MeetingController {
  final MeetingService _service;
  final Ref _ref;

  MeetingController(this._service, this._ref);

  /// Start recording a meeting
  Future<void> startRecording(String title) async {
    final recording = await _service.startRecording(title);
    _ref.read(activeRecordingProvider.notifier).state = recording;
  }

  /// Stop recording
  Future<void> stopRecording() async {
    final recording = _ref.read(activeRecordingProvider);
    if (recording != null) {
      await _service.stopRecording(recording.id);
      _ref.read(activeRecordingProvider.notifier).state = null;
      // Refresh list
      _ref.refresh(meetingMinutesListProvider);
    }
  }

  /// Export to markdown
  Future<String> exportToMarkdown(String meetingId) async {
    return _service.exportToMarkdown(meetingId);
  }

  /// Export to PDF
  Future<String> exportToPdf(String meetingId) async {
    return _service.exportToPdf(meetingId);
  }

  /// Delete meeting
  Future<void> deleteMeeting(String id) async {
    await _service.deleteMeetingMinutes(id);
    _ref.refresh(meetingMinutesListProvider);
  }
}
