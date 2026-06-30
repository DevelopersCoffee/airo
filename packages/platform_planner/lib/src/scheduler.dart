
import 'package:platform_pipeline/platform_pipeline.dart';
import 'package:platform_execution/platform_execution.dart';

class BatchConfig {
  final int batchSize;
  final Duration timeout;
  BatchConfig({required this.batchSize, required this.timeout});
}

class Scheduler {
  void schedule(PipelineDag dag, BatchConfig batchConfig) {}
}
