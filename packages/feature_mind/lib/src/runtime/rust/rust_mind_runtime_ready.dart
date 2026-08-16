import '../../whisper/api/meetings.dart' show isReady;

/// Whether the Mind Rust runtime is initialised without throwing when FRB is
/// not loaded (e.g. widget tests that never call `RustLib.init`).
bool mindRuntimeRustReady() {
  try {
    return isReady();
  } on Object {
    return false;
  }
}
