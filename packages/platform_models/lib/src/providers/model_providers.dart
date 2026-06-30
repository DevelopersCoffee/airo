import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../catalog/model_catalog.dart';
import '../recommendation/recommendation_engine.dart';

final modelCatalogProvider = Provider<ModelCatalog>((ref) {
  return InMemoryModelCatalog();
});

final recommendationEngineProvider = Provider<RecommendationEngine>((ref) {
  final catalog = ref.watch(modelCatalogProvider);
  return RecommendationEngine(catalog);
});
