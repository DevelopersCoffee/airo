/// Airo Mind — record a meeting, get searchable minutes, entirely on device.
///
/// The public surface is deliberately four names. Everything else, including
/// the generated bridge, is an implementation detail: a consumer that reaches
/// into `src/` has coupled itself to a code generator's output.
library;

export 'src/api/mind.dart' show MeetingRecord, SearchHit;
export 'src/meeting_screen.dart' show MeetingScreen;
export 'src/mind_home_screen.dart' show MindHomeScreen;
export 'src/mind_service.dart'
    show MindProgress, MindService, MindStage, MindStatus, MindUnavailable;
