/// Airo Mind — a local-first personal intelligence runtime.
///
/// Two layers are exported here. The **runtime** is the port a surface binds
/// to: eight sub-ports, their models, and two implementations. The **meeting
/// recorder** is what shipped before the runtime existed, and it keeps working
/// while milestone 22 builds the real surfaces around it.
///
/// The generated bridges are not exported and must not be reached: a consumer
/// that imports `src/whisper/`, `src/llama/` or `frb_generated` has coupled
/// itself to a code generator's output. Only `rust_mind_runtime.dart` may touch
/// them.
///
/// There are two bridges because there are two engine libraries — whisper.cpp
/// and llama.cpp vendor incompatible copies of ggml and cannot share a linked
/// image (#1546). That split is an implementation detail: it stops at
/// `MindService`, and the names exported here are unchanged.
library;

export 'src/whisper/api/meetings.dart' show MeetingRecord, SearchHit;
export 'src/meeting_screen.dart' show MeetingScreen;
export 'src/mind_home_screen.dart' show MindHomeScreen;
export 'src/mind_service.dart'
    show MindProgress, MindService, MindStage, MindStatus, MindUnavailable;

// Model acquisition. A shell composes `DownloadModelProvider` with its own
// `downloadUrlFor` (hosting is a Dart-side decision, `ADR-0018 §1` — the
// registry pins a digest, not a URL) and passes it to `MindService`. Neither
// this package nor the shell is required to use it: `ModelInstaller` (the
// bundled-asset default) still works unchanged.
export 'src/model_installer.dart' show ModelInstaller;
export 'src/models/download_model_provider.dart' show DownloadModelProvider;
export 'src/models/model_provider.dart'
    show
        InstalledModel,
        ModelAcquisitionDone,
        ModelAcquisitionEvent,
        ModelAcquisitionProgress,
        ModelProvider,
        RequiredModel;

// Runtime — models.
export 'src/runtime/models/capability_models.dart';
export 'src/runtime/models/context_models.dart';
export 'src/runtime/models/log_models.dart';
export 'src/runtime/models/mesh_models.dart';
export 'src/runtime/models/model_models.dart';
export 'src/runtime/models/portability_models.dart';
export 'src/runtime/models/projection_models.dart';
export 'src/runtime/models/vault_models.dart';

// Runtime — the port milestone 19 implements against.
export 'src/runtime/mind_runtime.dart';
export 'src/runtime/ports/capability_port.dart';
export 'src/runtime/ports/context_port.dart';
export 'src/runtime/ports/mesh_port.dart';
export 'src/runtime/ports/model_port.dart';
export 'src/runtime/ports/operation_log_port.dart';
export 'src/runtime/ports/portability_port.dart';
export 'src/runtime/ports/projection_port.dart';
export 'src/runtime/ports/vault_port.dart';

// Runtime — the deterministic fixture every surface is built against.
export 'src/runtime/fixture/fixture_data.dart';
export 'src/runtime/fixture/fixture_mind_runtime.dart';
export 'src/runtime/rust/rust_mind_runtime.dart';

// Widgets that carry the design rules. Every Mind surface uses these rather
// than re-implementing a pip or a number strip that drifts from the rule.
export 'src/widgets/mind_context_chip.dart';
export 'src/widgets/mind_number_strip.dart';
export 'src/widgets/mind_op_row.dart';
export 'src/widgets/mind_palette.dart';
export 'src/widgets/mind_presence_pip.dart';
export 'src/widgets/mind_projection_switcher.dart';
