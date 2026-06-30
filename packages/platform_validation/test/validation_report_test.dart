import 'package:flutter_test/flutter_test.dart';
import 'package:platform_validation/platform_validation.dart';

void main() {
  test('ValidationReport correctly determines safety', () {
    const successReport = ValidationReport(
      status: ValidationStatus.success,
    );
    expect(successReport.isSafe, isTrue);

    const warningReport = ValidationReport(
      status: ValidationStatus.warnings,
      warnings: ['Missing optional metadata'],
    );
    expect(warningReport.isSafe, isTrue);

    const failedReport = ValidationReport(
      status: ValidationStatus.failed,
      errors: ['Invalid checksum'],
    );
    expect(failedReport.isSafe, isFalse);
  });
}
