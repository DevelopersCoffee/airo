import 'package:flutter_test/flutter_test.dart';
import 'package:platform_engine_sdk/platform_engine_sdk.dart';

void main() {
  test('EngineDescriptor holds attributes correctly', () {
    const descriptor = EngineDescriptor(
      identifier: 'llama_cpp',
      version: '1.0.0',
      vendor: 'ggerganov',
      supportedPlatforms: ['ios', 'android', 'macos'],
    );
    expect(descriptor.identifier, 'llama_cpp');
    expect(descriptor.version, '1.0.0');
    expect(descriptor.supportedPlatforms.length, 3);
  });
}
