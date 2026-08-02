/// Airo Mind — a local-first personal intelligence runtime.
///
/// Two layers are exported here. The **runtime** is the port a surface binds
/// to: eight sub-ports, their models, and two implementations. The **meeting
/// recorder** is what shipped before the runtime existed, and it keeps working
/// while milestone 22 builds the real surfaces around it.
///
/// The generated bridge is not exported and must not be reached: a consumer
/// that imports `src/api/` or `frb_generated` has coupled itself to a code
/// generator's output. Only `rust_mind_runtime.dart` may touch it.
library;

export 'src/api/mind.dart' show MeetingRecord, SearchHit;
export 'src/meeting_screen.dart' show MeetingScreen;
export 'src/mind_home_screen.dart' show MindHomeScreen;
export 'src/mind_service.dart'
    show MindProgress, MindService, MindStage, MindStatus, MindUnavailable;

// Runtime — models.
export 'src/runtime/models/capability_models.dart';
export 'src/runtime/models/context_models.dart';
export 'src/runtime/models/log_models.dart';
export 'src/runtime/models/mesh_models.dart';
export 'src/runtime/models/model_models.dart';
export 'src/runtime/models/portability_models.dart';
export 'src/runtime/models/projection_models.dart';
export 'src/runtime/models/vault_models.dart';
