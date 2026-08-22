import 'package:flutter/foundation.dart';

/// Result of attempting to load a GGUF artifact into the native runtime.
@immutable
class GgufLoadOutcome {
  const GgufLoadOutcome._({
    required this.succeeded,
    this.reasonCode,
    this.technicalDetail,
    this.expectedBytes,
    this.foundBytes,
  });

  const GgufLoadOutcome.success() : this._(succeeded: true);

  const GgufLoadOutcome.fileMissing()
    : this._(succeeded: false, reasonCode: 'model_file_missing');

  const GgufLoadOutcome.incompleteDownload({
    required int expectedBytes,
    required int foundBytes,
  }) : this._(
         succeeded: false,
         reasonCode: 'model_file_incomplete',
         expectedBytes: expectedBytes,
         foundBytes: foundBytes,
       );

  const GgufLoadOutcome.engineError(String detail)
    : this._(
        succeeded: false,
        reasonCode: 'init_failed',
        technicalDetail: detail,
      );

  final bool succeeded;
  final String? reasonCode;
  final String? technicalDetail;
  final int? expectedBytes;
  final int? foundBytes;
}
