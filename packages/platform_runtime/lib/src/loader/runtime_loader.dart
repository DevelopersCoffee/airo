// ignore_for_file: one_member_abstracts
import 'package:platform_engine_sdk/platform_engine_sdk.dart';
import 'package:platform_validation/platform_validation.dart';

abstract interface class RuntimeLoader {
  Future<EngineSession> load(InstalledArtifact artifact);
}
