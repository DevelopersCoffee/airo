import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:dio/dio.dart';
import 'http/dio_client.dart';

/// HTTP client provider
final dioClientProvider = Provider<DioClient>((ref) {
  return DioClient(
    baseUrl: '', // Set your base URL here
    connectTimeout: const Duration(seconds: 10),
    receiveTimeout: const Duration(seconds: 30),
  );
});

/// Raw Dio provider for advanced usage
final dioProvider = Provider<Dio>((ref) {
  return ref.watch(dioClientProvider).dio;
});

// TODO: Add Drift database provider
// final appDbProvider = Provider<AppDb>((ref) {
//   return AppDb();
// });

// TODO: Add Hive boxes provider
// final hiveBoxesProvider = Provider<HiveBoxes>((ref) {
//   return HiveBoxes();
// });

// TODO: Add repository providers
// final accountsRepositoryProvider = Provider<AccountsRepository>((ref) {
//   return AccountsRepository(ref.watch(appDbProvider));
// });

// TODO: Add service providers
// final llmClientProvider = Provider<LLMClient>((ref) {
//   return FakeLLMClient(); // Start with fake, swap later
// });

// TODO: Add audio service provider
// final audioQueueProvider = Provider<AudioQueue>((ref) {
//   return AudioQueueImpl();
// });

