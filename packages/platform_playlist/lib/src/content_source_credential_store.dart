import 'package:core_data/core_data.dart';
import 'package:equatable/equatable.dart';

import 'content_source.dart';

/// A source's auth secret. Never persisted or logged outside
/// [ContentSourceCredentialStore] — [toString] is always redacted.
class ContentSourceCredentials extends Equatable {
  const ContentSourceCredentials({
    required this.username,
    required this.password,
  });

  final String username;
  final String password;

  @override
  List<Object?> get props => [username, password];

  @override
  String toString() => 'ContentSourceCredentials(redacted)';
}

/// Stores/retrieves [ContentSourceCredentials] behind a
/// [ContentSourceCredentialRef], backed by `core_data`'s [SecureStore]
/// (Keystore on Android, Keychain on iOS/macOS — see
/// `FlutterSecureStore` in `core_data`).
class ContentSourceCredentialStore {
  ContentSourceCredentialStore(this._secureStore);

  final SecureStore _secureStore;

  static String _usernameKey(ContentSourceCredentialRef ref) =>
      'content_source.${ref.key}.username';

  static String _passwordKey(ContentSourceCredentialRef ref) =>
      'content_source.${ref.key}.password';

  Future<void> save(
    ContentSourceCredentialRef ref,
    ContentSourceCredentials credentials,
  ) async {
    await _secureStore.write(
      key: _usernameKey(ref),
      value: credentials.username,
    );
    await _secureStore.write(
      key: _passwordKey(ref),
      value: credentials.password,
    );
  }

  Future<ContentSourceCredentials?> read(
    ContentSourceCredentialRef ref,
  ) async {
    final username = await _secureStore.read(key: _usernameKey(ref));
    final password = await _secureStore.read(key: _passwordKey(ref));
    if (username == null || password == null) {
      return null;
    }
    return ContentSourceCredentials(username: username, password: password);
  }

  Future<void> delete(ContentSourceCredentialRef ref) async {
    await _secureStore.delete(key: _usernameKey(ref));
    await _secureStore.delete(key: _passwordKey(ref));
  }
}
