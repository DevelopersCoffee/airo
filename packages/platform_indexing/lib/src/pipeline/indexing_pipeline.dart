
import 'package:platform_documents/platform_documents.dart';

class IndexingJob {
  final DocumentSource source;
  final String format;
  IndexingJob({required this.source, required this.format});
}

class IndexingResult {
  final bool success;
  final String? error;
  IndexingResult({required this.success, this.error});
}

abstract class IndexingPipeline {
  Future<IndexingResult> execute(IndexingJob job);
}
