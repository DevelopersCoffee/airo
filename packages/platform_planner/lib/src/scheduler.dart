
import 'package:platform_pipeline/platform_pipeline.dart';

class BatchConfig {
  BatchConfig({required this.batchSize, required this.timeout});
  final int batchSize;
  final Duration timeout;
}

class Scheduler {
  void schedule(PipelineDag dag, BatchConfig batchConfig) {}
}
