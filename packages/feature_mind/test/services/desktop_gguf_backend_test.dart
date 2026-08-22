import 'dart:io';

import 'package:core_ai/core_ai.dart';
import 'package:feature_mind/src/services/desktop_gguf_backend.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory tempDir;
  late _FakeLlamaSession session;
  late DesktopGgufBackend backend;

  setUp(() async {
    debugDefaultTargetPlatformOverride = TargetPlatform.macOS;
    tempDir = await Directory.systemTemp.createTemp('airo-mind-gguf-');
    session = _FakeLlamaSession();
    backend = DesktopGgufBackend(ensureBridge: () async {}, session: session);
  });

  tearDown(() async {
    debugDefaultTargetPlatformOverride = null;
    if (tempDir.existsSync()) {
      await tempDir.delete(recursive: true);
    }
  });

  OfflineModelInfo modelAt(String path) {
    return OfflineModelInfo(
      id: path.split(Platform.pathSeparator).last,
      name: 'Test model',
      family: ModelFamily.gemma,
      fileSizeBytes: 0,
      filePath: path,
    );
  }

  Future<File> writeWeight(String name) async {
    final file = File('${tempDir.path}/$name');
    await file.writeAsBytes(const [1, 2, 3]);
    return file;
  }

  test('loads the selected weight file, not its parent directory', () async {
    final gemma = await writeWeight('gemma-2-2b-it');
    final outcome = await backend.loadModel(modelAt(gemma.path));

    expect(outcome.succeeded, isTrue);
    expect(session.loadPaths, [gemma.path]);
    expect(session.unloadCount, 0);
  });

  test('skips reload when the same file is already loaded', () async {
    final gemma = await writeWeight('gemma-2-2b-it');
    await backend.loadModel(modelAt(gemma.path));
    session.loadPaths.clear();

    final outcome = await backend.loadModel(modelAt(gemma.path));

    expect(outcome.succeeded, isTrue);
    expect(session.loadPaths, isEmpty);
    expect(session.unloadCount, 0);
  });

  test('unloads and reloads when the selected file changes', () async {
    final gemma = await writeWeight('gemma-2-2b-it');
    final qwen = await writeWeight('qwen2.5-0.5b');
    await backend.loadModel(modelAt(gemma.path));

    final outcome = await backend.loadModel(modelAt(qwen.path));

    expect(outcome.succeeded, isTrue);
    expect(session.loadPaths, [gemma.path, qwen.path]);
    expect(session.unloadCount, 1);
  });

  test('does not report success from a previously loaded engine', () async {
    final gemma = await writeWeight('gemma-2-2b-it');
    final missing = '${tempDir.path}/not-on-disk';
    await backend.loadModel(modelAt(gemma.path));

    final outcome = await backend.loadModel(modelAt(missing));

    expect(outcome.succeeded, isFalse);
    expect(outcome.reasonCode, 'model_file_missing');
    expect(session.loadPaths, [gemma.path]);
  });

  test('the FFI llama slot is supported on Android, not iOS', () {
    expect(
      DesktopGgufBackend.supportedOn(
        platform: TargetPlatform.android,
        isWeb: false,
      ),
      isTrue,
    );
    expect(
      DesktopGgufBackend.supportedOn(
        platform: TargetPlatform.iOS,
        isWeb: false,
      ),
      isFalse,
    );
    expect(
      DesktopGgufBackend.supportedOn(
        platform: TargetPlatform.android,
        isWeb: true,
      ),
      isFalse,
    );
  });
}

class _FakeLlamaSession extends DesktopLlamaSession {
  final loadPaths = <String>[];
  var unloadCount = 0;
  var ready = false;

  @override
  Future<void> load({
    required String modelPath,
    required int memoryBudgetMb,
  }) async {
    loadPaths.add(modelPath);
    ready = true;
  }

  @override
  bool get isReady => ready;

  @override
  void unload() {
    unloadCount += 1;
    ready = false;
  }
}
