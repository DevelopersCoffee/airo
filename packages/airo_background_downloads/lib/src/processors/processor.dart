import '../models/download.dart';

/// Context provided to post-processors upon transfer completion.
class AiroProcessorContext {
  const AiroProcessorContext({required this.download, required this.filePath});

  final AiroDownload download;
  final String filePath;
}

/// Result of a post-processing stage.
class AiroProcessorResult {
  const AiroProcessorResult({
    required this.success,
    required this.outputFilePath,
    this.errorMessage,
  });

  final bool success;
  final String outputFilePath;
  final String? errorMessage;
}

/// Pluggable processor interface for pipeline steps (checksum, archive extraction, encryption).
abstract interface class AiroDownloadProcessor {
  Future<AiroProcessorResult> process(AiroProcessorContext context);
}
