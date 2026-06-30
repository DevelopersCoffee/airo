
import 'package:platform_content/platform_content.dart';

class IndexingJob {
  IndexingJob({required this.source, required this.format});
  final ContentDocument source;
  final String format;
}

class IndexingResult {
  IndexingResult({required this.success, this.error});
  final bool success;
  final String? error;
}

abstract class IndexingPipeline {
  Future<IndexingResult> execute(IndexingJob job);
}
