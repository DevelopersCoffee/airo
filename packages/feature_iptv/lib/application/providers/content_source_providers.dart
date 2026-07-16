import 'package:core_data/core_data.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:platform_playlist/platform_playlist.dart';

/// Overridden with a real [SecureStore] in `main()`
/// (`SecureStoreFactory.createSecure()`); tests override with
/// [InMemorySecureStore].
final secureStoreProvider = Provider<SecureStore>((ref) {
  throw UnimplementedError('secureStoreProvider must be overridden');
});

final contentSourceCredentialStoreProvider =
    Provider<ContentSourceCredentialStore>((ref) {
      return ContentSourceCredentialStore(ref.watch(secureStoreProvider));
    });
