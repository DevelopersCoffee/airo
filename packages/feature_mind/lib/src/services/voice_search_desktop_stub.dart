import 'voice_search_service.dart';

/// Web has no microphone encoder and no whisper dylib.
VoiceSearchService createDesktopWhisperVoiceSearchService() =>
    MockVoiceSearchService();
