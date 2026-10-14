import 'dart:io';

import 'processor.dart';
import 'streaming_checksum.dart';

/// Processor verifying checksum integrity post-download.
class AiroChecksumProcessor implements AiroDownloadProcessor {
  const AiroChecksumProcessor();

  @override
  Future<AiroProcessorResult> process(AiroProcessorContext context) async {
    final checksum = context.download.request.checksum;
    if (checksum == null) {
      return AiroProcessorResult(
        success: true,
        outputFilePath: context.filePath,
      );
    }

    final file = File(context.filePath);
    if (!await file.exists()) {
      return AiroProcessorResult(
        success: false,
        outputFilePath: context.filePath,
        errorMessage: 'File not found for checksum verification',
      );
    }

    if (!await fileMatchesChecksum(file, checksum)) {
      return AiroProcessorResult(
        success: false,
        outputFilePath: context.filePath,
        errorMessage:
            '${checksum.algorithm.name} checksum did not match expected value',
      );
    }

    return AiroProcessorResult(success: true, outputFilePath: context.filePath);
  }
}
