// ignore_for_file: one_member_abstracts
import 'package:platform_hardware/platform_hardware.dart';
import 'package:platform_pipeline/platform_pipeline.dart';
import 'package:platform_runtime/src/registry/runtime_registry.dart';
import 'package:platform_runtime/src/selector/runtime_selection.dart';

abstract interface class RuntimeSelector {
  RuntimeSelection select(
    Artifact artifact,
    HardwareProfile hardwareProfile,
    RuntimeRegistry registry,
  );
}
