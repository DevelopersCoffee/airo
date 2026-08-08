import '../whisper/api/setup.dart' as rust;
import 'model_provider.dart';

/// The pinned registry from `airo_mind_core::models`, translated across the
/// bridge into the shape a [ModelProvider] speaks.
///
/// One function rather than one per provider: `ADR-0018 §2` puts identity —
/// file name, size, digest — in Rust source and nowhere else, so every Dart
/// caller that needs it should be reading the same translation. A shell
/// composing [DownloadModelProvider] needs the same list `ModelInstaller`
/// needs, and neither of them should re-derive it.
///
/// Where the bytes are *hosted* is deliberately not here: the registry proves
/// which bytes are correct, not where to find them (`ADR-0018 §1` — the
/// runtime never acquires models). That is the shell's `downloadUrlFor`.
Future<List<RequiredModel>> pinnedRequiredModels() async => [
  for (final required in await rust.requiredModels())
    RequiredModel(
      fileName: required.fileName,
      sizeBytes: required.sizeBytes.toInt(),
      sha256: required.sha256,
    ),
];
