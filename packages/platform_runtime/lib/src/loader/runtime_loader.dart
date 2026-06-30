// ignore_for_file: one_member_abstracts
import 'package:platform_engine_sdk/platform_engine_sdk.dart';
import 'package:platform_pipeline/platform_pipeline.dart';

abstract interface class RuntimeLoader {
  Future<EngineSession> load(Artifact artifact);
}
