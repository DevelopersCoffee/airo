import 'package:meta/meta.dart';

/// User login credentials
@immutable
class Credentials {
  const Credentials({
    required this.username,
    required this.password,
  });

  final String username;
  final String password;

  /// Validates that credentials are not empty
  bool get isValid => username.isNotEmpty && password.isNotEmpty;

  @override
  String toString() => 'Credentials(username: $username)';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Credentials &&
          other.username == username &&
          other.password == password;

  @override
  int get hashCode => Object.hash(username, password);
}

