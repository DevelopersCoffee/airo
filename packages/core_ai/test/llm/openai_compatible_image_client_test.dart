import 'dart:convert';
import 'dart:io';

import 'package:core_ai/core_ai.dart';
import 'package:core_domain/core_domain.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'image client sends negative prompt and source image for image-to-image',
    () async {
      final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      addTearDown(server.close);
      Map<String, dynamic>? requestBody;
      server.listen((request) async {
        requestBody = jsonDecode(await utf8.decoder.bind(request).join());
        request.response
          ..headers.contentType = ContentType.json
          ..write(
            jsonEncode({
              'data': [
                {'b64_json': 'aGVsbG8=', 'revised_prompt': 'revised'},
              ],
            }),
          );
        await request.response.close();
      });

      final result =
          await OpenAICompatibleImageClient(
            baseUrl: 'http://127.0.0.1:${server.port}',
          ).generate(
            const ImageGenerationRequest(
              prompt: 'make it warmer',
              negativePrompt: 'blurry',
              sourceImageBase64: 'c291cmNl',
              width: 512,
              height: 768,
              steps: 12,
              seed: 7,
            ),
          );

      expect(result, isA<Success<GeneratedImage>>());
      expect((result as Success<GeneratedImage>).value.base64Data, 'aGVsbG8=');
      expect(requestBody?['negative_prompt'], 'blurry');
      expect(requestBody?['image_base64'], 'c291cmNl');
      expect(requestBody?['size'], '512x768');
      expect(requestBody?['seed'], 7);
    },
  );

  test(
    'image client validates prompts and dimensions before network I/O',
    () async {
      final client = OpenAICompatibleImageClient(baseUrl: 'http://127.0.0.1:1');
      final empty = await client.generate(
        const ImageGenerationRequest(prompt: ''),
      );
      final invalid = await client.generate(
        const ImageGenerationRequest(prompt: 'x', width: 0),
      );
      expect(empty, isA<Failure<GeneratedImage>>());
      expect(invalid, isA<Failure<GeneratedImage>>());
    },
  );
}
