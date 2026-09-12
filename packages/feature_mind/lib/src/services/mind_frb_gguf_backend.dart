import 'package:core_completion/core_completion.dart';

import 'desktop_gguf_backend.dart';

/// FRB / desktop GGUF slot as a [GgufNativeBackend].
class MindFrbGgufBackend implements GgufNativeBackend {
  MindFrbGgufBackend(this._desktop);

  final DesktopGgufBackend _desktop;

  @override
  bool get isReady => _desktop.isEngineReady;

  @override
  Stream<String> generate({
    required String prompt,
    required int maxTokens,
    String? grammar,
  }) {
    return _desktop.generate(
      prompt: prompt,
      maxTokens: maxTokens,
      grammar: grammar,
    );
  }

  @override
  Future<void> stop() => _desktop.stop();
}
