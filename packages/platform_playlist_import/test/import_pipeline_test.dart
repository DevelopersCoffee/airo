import 'package:flutter_test/flutter_test.dart';
import 'package:platform_playlist_import/platform_playlist_import.dart';

class MockStringInputStage extends PipelineStage<String, String> {
  @override
  String get stageName => 'MockStringStage';

  @override
  Future<String> execute(String input) async {
    return '$input-processed';
  }
}

class MockLengthStage extends PipelineStage<String, int> {
  @override
  String get stageName => 'MockLengthStage';

  @override
  Future<int> execute(String input) async {
    return input.length;
  }
}

void main() {
  group('ImportPipeline Tests', () {
    test('Pipeline processes stages in order', () async {
      final pipeline = ImportPipeline([
        MockStringInputStage(),
        MockStringInputStage(),
        MockLengthStage(),
      ]);

      final result = await pipeline.run('test');
      // 'test' -> 'test-processed' -> 'test-processed-processed' -> length
      expect(result, equals(24));
    });
  });
}
