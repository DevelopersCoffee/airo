import 'dart:io';

import 'package:core_completion/core_completion.dart';
import 'package:feature_anya/feature_anya.dart';
import 'package:flutter/foundation.dart';
import 'package:llama_flutter_android/llama_flutter_android.dart';
import 'package:path_provider/path_provider.dart';

import 'anya_gguf_path.dart';
import 'gguf_plan_repair_port.dart';

typedef AnyaGgufBinder = Future<PlanRepairPort?> Function(String modelPath);

Future<List<Directory>> defaultAnyaGgufSearchRoots() async {
  final support = await getApplicationSupportDirectory();
  final docs = await getApplicationDocumentsDirectory();
  return [Directory('${support.path}/models'), support, docs];
}

/// IO factory: GGUF on Android, otherwise [NoopPlanRepairPort].
Future<PlanRepairPort> createAnyaPlanRepairPort({
  CompletionClient? completion,
  String? configuredPath,
  Iterable<Directory>? searchRoots,
  AnyaGgufBinder? bindModel,
}) async {
  if (completion != null) {
    return GgufPlanRepairPort(completion);
  }
  final configured =
      (configuredPath ?? const String.fromEnvironment('ANYA_GGUF_PATH')).trim();
  final path = resolveAnyaGgufPath(
    configuredPath: configuredPath,
    searchRoots:
        searchRoots ??
        (configured.isEmpty
            ? await defaultAnyaGgufSearchRoots()
            : const <Directory>[]),
  );
  if (path == null) return const NoopPlanRepairPort();
  final binder = bindModel ?? bindAnyaGgufJni;
  return await binder(path) ?? const NoopPlanRepairPort();
}

/// Pixel JNI load. Desktop/web callers get null → no-op this slice.
Future<PlanRepairPort?> bindAnyaGgufJni(String modelPath) async {
  if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) {
    return null;
  }
  try {
    final jni = LlamaController();
    await jni.loadModel(modelPath: modelPath, contextSize: 2048);
    return GgufPlanRepairPort(
      GgufCompletionClient(jni: jni, jniIsLoaded: () => true),
    );
  } on Object {
    return null;
  }
}
