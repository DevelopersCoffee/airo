import 'package:flutter_rust_bridge/flutter_rust_bridge_for_generated.dart';

/// Web has no `dart:ffi`, so there is no native library to resolve. Returning
/// null hands over to the generated loader's own web path; if that also has
/// nothing to load, `RustLib.init` throws, and `MindService.initialize()`
/// surfaces that as `MindUnavailable.bridgeMissing` — the same status a build
/// with no native artifact linked in gets.
Future<ExternalLibrary?> resolveEngineLibrary(String stem) async => null;

/// Web has no process signals and no native speech dylib.
void listenForQuitSignals(void Function() onQuit) {}

void unloadWhisperSpeech() {}
