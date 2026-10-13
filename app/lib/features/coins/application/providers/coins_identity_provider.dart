import 'package:feature_coins_core/feature_coins_core.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// The identity implementation coins runs against.
///
/// Shell entrypoints override this provider: the super-app supplies
/// [AuthServiceCoinsIdentity] (see `auth_coins_identity.dart`); the standalone
/// Airo Coin shell supplies [LocalCoinsIdentity] from `core/coins`.
final coinsIdentityProvider = Provider<CoinsIdentity>(
  (ref) => throw UnimplementedError(
    'Override coinsIdentityProvider in the shell entrypoint',
  ),
);
