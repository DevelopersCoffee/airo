import 'dart:convert';

import 'package:core_domain/core_domain.dart';
import 'package:dio/dio.dart';
import 'package:meta/meta.dart';

import 'openai_compatible_client.dart' show normalizeOpenAICompatibleBaseUrl;

@immutable
class ImageGenerationRequest {
  const ImageGenerationRequest({
    required this.prompt,
    this.negativePrompt,
    this.sourceImageBase64,
    this.model,
    this.width = 1024,
    this.height = 1024,
    this.steps = 20,
    this.seed,
  });

  final String prompt;
  final String? negativePrompt;
  final String? sourceImageBase64;
  final String? model;
  final int width;
  final int height;
  final int steps;
  final int? seed;

  bool get isImageToImage => sourceImageBase64?.trim().isNotEmpty == true;
}

@immutable
class GeneratedImage {
  const GeneratedImage({this.base64Data, this.url, this.revisedPrompt});

  final String? base64Data;
  final String? url;
  final String? revisedPrompt;

  bool get isValid =>
      base64Data?.trim().isNotEmpty == true || url?.trim().isNotEmpty == true;
}

/// Image generation adapter for local/private servers that expose an
/// OpenAI-compatible `/images/generations` endpoint.
class OpenAICompatibleImageClient {
  OpenAICompatibleImageClient({
    required String baseUrl,
    this._apiKey,
    Dio? dio,
    this._timeout = const Duration(seconds: 90),
  }) : _baseUrl = normalizeOpenAICompatibleBaseUrl(baseUrl),
       _dio = dio ?? Dio();

  final String _baseUrl;
  final String? _apiKey;
  final Dio _dio;
  final Duration _timeout;

  Map<String, String> get _headers => {
    'Content-Type': 'application/json',
    if (_apiKey?.trim().isNotEmpty == true)
      'Authorization': 'Bearer ${_apiKey!.trim()}',
  };

  Future<Result<GeneratedImage>> generate(
    ImageGenerationRequest request,
  ) async {
    if (request.prompt.trim().isEmpty) {
      return Failure(
        ValidationFailure(message: 'An image prompt is required.'),
      );
    }
    if (request.width <= 0 || request.height <= 0 || request.steps <= 0) {
      return Failure(
        ValidationFailure(
          message: 'Image dimensions and steps must be positive.',
        ),
      );
    }

    try {
      final response = await _dio.post<Map<String, dynamic>>(
        '$_baseUrl/images/generations',
        data: {
          'prompt': request.prompt,
          if (request.negativePrompt?.trim().isNotEmpty == true)
            'negative_prompt': request.negativePrompt!.trim(),
          if (request.sourceImageBase64?.trim().isNotEmpty == true)
            'image_base64': request.sourceImageBase64!.trim(),
          if (request.model?.trim().isNotEmpty == true) 'model': request.model,
          'size': '${request.width}x${request.height}',
          'width': request.width,
          'height': request.height,
          'steps': request.steps,
          'n': 1,
          if (request.seed != null) 'seed': request.seed,
        },
        options: Options(headers: _headers, receiveTimeout: _timeout),
      );
      final data = response.data?['data'];
      if (data is! List || data.isEmpty || data.first is! Map) {
        return Failure(
          ServerFailure(message: 'Image server returned no image data.'),
        );
      }
      final item = data.first as Map;
      final image = GeneratedImage(
        base64Data: item['b64_json'] as String?,
        url: item['url'] as String?,
        revisedPrompt: item['revised_prompt'] as String?,
      );
      if (!image.isValid) {
        return Failure(
          ServerFailure(message: 'Image server returned an invalid image.'),
        );
      }
      return Success(image);
    } on DioException catch (error) {
      return Failure(
        ServerFailure(
          message: 'Image server request failed: ${error.message}',
          cause: error,
        ),
      );
    } on Object catch (error) {
      return Failure(
        ServerFailure(
          message: 'Invalid image server response: $error',
          cause: error,
        ),
      );
    }
  }

  /// Extracts base64 payload from a data URL returned by a compatible server.
  static String? extractDataUrlBase64(String? value) {
    if (value == null || !value.startsWith('data:')) return null;
    final separator = value.indexOf(',');
    if (separator < 0) return null;
    final payload = value.substring(separator + 1).trim();
    try {
      base64.decode(payload);
      return payload;
    } on FormatException {
      return null;
    }
  }
}
