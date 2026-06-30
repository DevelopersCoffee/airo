import 'package:flutter_test/flutter_test.dart';

class SchemaVerification {
  static void verifyDiagnosticKeys(Map<String, dynamic> diagnostics) {
    expect(diagnostics.containsKey('ttft'), isTrue);
    expect(diagnostics.containsKey('tokens_per_second'), isTrue);
    expect(diagnostics.containsKey('load_time'), isTrue);
    expect(diagnostics.containsKey('peak_memory'), isTrue);
  }
}
