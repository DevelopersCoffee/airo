import 'dart:io';

import 'package:airo_app/anya/anya_gguf_path.dart';
import 'package:airo_app/anya/anya_plan_repair_factory_io.dart';
import 'package:airo_app/anya/gguf_plan_repair_port.dart';
import 'package:core_completion/core_completion.dart';
import 'package:feature_anya/feature_anya.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late Directory tmp;

  setUp(() async {
    tmp = await Directory.systemTemp.createTemp('anya_gguf_');
  });

  tearDown(() async {
    if (tmp.existsSync()) await tmp.delete(recursive: true);
  });

  test('resolveAnyaGgufPath returns a configured file that exists', () async {
    final file = File('${tmp.path}/model.gguf');
    await file.writeAsString('not-a-real-model');

    expect(resolveAnyaGgufPath(configuredPath: file.path), file.path);
  });

  test('resolveAnyaGgufPath is null when the configured file is missing', () {
    expect(
      resolveAnyaGgufPath(configuredPath: '${tmp.path}/missing.gguf'),
      isNull,
    );
  });

  test('resolveAnyaGgufPath finds the first gguf under search roots', () async {
    final models = Directory('${tmp.path}/models')..createSync();
    final file = File('${models.path}/gemma.gguf');
    await file.writeAsString('gguf');

    expect(
      resolveAnyaGgufPath(
        searchRoots: [Directory('${tmp.path}/empty'), models],
      ),
      file.path,
    );
  });

  test('factory returns NoopPlanRepairPort when no GGUF is found', () async {
    final port = await createAnyaPlanRepairPort(
      configuredPath: '${tmp.path}/missing.gguf',
      searchRoots: [tmp],
    );

    expect(port, isA<NoopPlanRepairPort>());
    expect(port.isAvailable, isFalse);
  });

  test('factory returns NoopPlanRepairPort when bind fails', () async {
    final file = File('${tmp.path}/model.gguf');
    await file.writeAsString('gguf');

    final port = await createAnyaPlanRepairPort(
      configuredPath: file.path,
      bindModel: (_) async => null,
    );

    expect(port, isA<NoopPlanRepairPort>());
  });

  test('factory wraps an injected available CompletionClient', () async {
    final port = await createAnyaPlanRepairPort(
      completion: FakeCompletionClient(tokens: const ['{}']),
    );

    expect(port, isA<GgufPlanRepairPort>());
    expect(port.isAvailable, isTrue);
  });

  test('factory returns the bound port when bind succeeds', () async {
    final file = File('${tmp.path}/model.gguf');
    await file.writeAsString('gguf');
    final bound = GgufPlanRepairPort(FakeCompletionClient());

    final port = await createAnyaPlanRepairPort(
      configuredPath: file.path,
      bindModel: (path) async {
        expect(path, file.path);
        return bound;
      },
    );

    expect(identical(port, bound), isTrue);
  });
}
