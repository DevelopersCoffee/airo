import 'dart:convert';

import 'package:core_ai/core_ai.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:core_ai/src/huggingface/huggingface_catalog_service.dart';

void main() {
  group('HuggingFaceCatalogService', () {
    test('maps a litert-community repo to OfflineModelInfo', () async {
      final dio = Dio();
      dio.interceptors.add(
        InterceptorsWrapper(
          onRequest: (options, handler) {
            final path = options.uri.path;
            if (path == '/api/models') {
              handler.resolve(
                Response(
                  requestOptions: options,
                  data: [
                    {
                      'id': 'litert-community/Demo-1B',
                      'tags': [
                        'litert-lm',
                        'license:apache-2.0',
                        'text-generation',
                      ],
                      'pipeline_tag': 'text-generation',
                      'library_name': 'litert-lm',
                    },
                  ],
                ),
              );
              return;
            }
            if (path == '/api/models/litert-community/Demo-1B/tree/main') {
              handler.resolve(
                Response(
                  requestOptions: options,
                  data: [
                    {
                      'type': 'file',
                      'path': 'demo-1b.litertlm',
                      'size': 123456789,
                    },
                  ],
                ),
              );
              return;
            }
            handler.reject(
              DioException(
                requestOptions: options,
                response: Response(
                  requestOptions: options,
                  statusCode: 404,
                  data: jsonEncode([]),
                ),
              ),
            );
          },
        ),
      );

      final service = HuggingFaceCatalogService(dio: dio);
      final models = await service.fetchOrganizationModels(limit: 1);

      expect(models, hasLength(1));
      final model = models.single;
      expect(model.id, 'hf-Demo-1B');
      expect(model.huggingFaceId, 'litert-community/Demo-1B');
      expect(model.fileSizeBytes, 123456789);
      expect(
        model.downloadUrl,
        'https://huggingface.co/litert-community/Demo-1B/resolve/main/demo-1b.litertlm',
      );
      expect(model.credibility, ModelCredibility.official);
    });

    test('skips repos already in the bundled catalog', () async {
      final bundled = ModelCatalog.bundledModels.firstWhere(
        (m) => m.huggingFaceId != null,
      );
      final dio = Dio();
      dio.interceptors.add(
        InterceptorsWrapper(
          onRequest: (options, handler) {
            handler.resolve(
              Response(
                requestOptions: options,
                data: [
                  {'id': bundled.huggingFaceId},
                ],
              ),
            );
          },
        ),
      );

      final service = HuggingFaceCatalogService(dio: dio);
      final models = await service.fetchOrganizationModels(
        knownHuggingFaceIds: {bundled.huggingFaceId!},
      );

      expect(models, isEmpty);
    });
  });
}
