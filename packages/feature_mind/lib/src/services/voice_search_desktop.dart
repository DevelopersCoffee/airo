import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';

import '../library_loader.dart';
import '../whisper/api/meetings.dart' as whisper;
import 'voice_search_service.dart';

/// Desktop chat/scribe mic: `package:record` + on-device whisper.
///
/// Apple's Speech framework (`speech_to_text`) is not used. A sandboxed
/// macOS app that probes it without a granted TCC prompt is killed.
VoiceSearchService createDesktopWhisperVoiceSearchService() {
  final recorder = AudioRecorder();
  return DesktopWhisperVoiceSearchService(
    hasPermission: recorder.hasPermission,
    startCapture: (path) => recorder.start(
      const RecordConfig(
        encoder: AudioEncoder.wav,
        sampleRate: 16000,
        numChannels: 1,
      ),
      path: path,
    ),
    stopCapture: recorder.stop,
    transcribe: _transcribeWithWhisper,
    tempPath: () async {
      final dir = await getTemporaryDirectory();
      return p.join(
        dir.path,
        'airo-voice-${DateTime.now().millisecondsSinceEpoch}.wav',
      );
    },
  );
}

Future<String> _transcribeWithWhisper(String path) async {
  await initializeWhisperBridge();
  if (!whisper.isReady()) {
    throw StateError(
      'On-device speech is not ready yet. Wait for Whisper to finish loading.',
    );
  }
  await for (final event in whisper.transcribeRecording(wavPath: path)) {
    switch (event) {
      case whisper.TranscriptEvent_TranscriptReady(:final text):
        return text.trim();
      case whisper.TranscriptEvent_Transcribing():
      case whisper.TranscriptEvent_Delta():
      case whisper.TranscriptEvent_Degraded():
      case whisper.TranscriptEvent_ConversationIr():
      case whisper.TranscriptEvent_Cancelled():
        break;
    }
  }
  return '';
}
