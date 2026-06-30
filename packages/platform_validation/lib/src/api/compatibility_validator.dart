// ignore_for_file: one_member_abstracts
import 'package:platform_core/platform_core.dart';
import 'package:platform_hardware/platform_hardware.dart';
import 'package:platform_validation/src/reports/validation_report.dart';

abstract interface class CompatibilityValidator {
  Future<Result<ValidationReport>> checkCompatibility(
    ValidationReport artifactReport, 
    HardwareProfile profile,
  );
}
