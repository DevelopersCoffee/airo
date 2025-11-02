import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../domain/models/offer_models.dart';

/// Offers source provider
final offersSourceProvider = Provider<OffersSource>((ref) {
  return FakeOffersSource();
});

/// Fetch offers provider
final offersProvider = FutureProvider<List<Offer>>((ref) async {
  final source = ref.watch(offersSourceProvider);
  return await source.fetch(limit: 50);
});

/// Refresh offers provider
final refreshOffersProvider = FutureProvider<void>((ref) async {
  ref.refresh(offersProvider);
});

/// Saved offers provider
final savedOffersProvider = StateProvider<Set<String>>((ref) {
  return {};
});
