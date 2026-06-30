import 'package:flutter_test/flutter_test.dart';
import 'package:platform_engine_testkit/src/cancellation/cancellation_tests.dart';
import 'package:platform_engine_testkit/src/capabilities/capabilities_tests.dart';
import 'package:platform_engine_testkit/src/embeddings/embedding_tests.dart';
import 'package:platform_engine_testkit/src/fixtures/engine_fixture.dart';
import 'package:platform_engine_testkit/src/generation/generation_tests.dart';
import 'package:platform_engine_testkit/src/lifecycle/lifecycle_tests.dart';
import 'package:platform_engine_testkit/src/streaming/streaming_tests.dart';
import 'package:platform_engine_testkit/src/vision/vision_tests.dart';

class EngineComplianceSuite {
  static void run(EngineFixture fixture) {
    group('Engine Compliance Suite', () {
      LifecycleTests.run(fixture);
      StreamingTests.run(fixture);
      GenerationTests.run(fixture);
      EmbeddingTests.run(fixture);
      VisionTests.run(fixture);
      CancellationTests.run(fixture);
      CapabilitiesTests.run(fixture);
    });
  }
}
