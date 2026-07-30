import 'package:flutter_test/flutter_test.dart';
import 'package:llama_flutter_android/llama_flutter_android.dart';

import 'package:airo_app/core/services/llama_gguf_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'accepts an injected native controller without probing the platform',
    () {
      final controller = LlamaController(
        binaryMessenger:
            TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger,
      );

      final service = LlamaGgufService(nativeController: controller);

      expect(service.generate(prompt: 'hello'), emitsError(isA<StateError>()));
    },
  );
}
