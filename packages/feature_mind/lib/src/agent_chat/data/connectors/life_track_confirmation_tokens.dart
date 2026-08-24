import '../../domain/services/confirmation_token_store.dart';
import '../../domain/services/lifetrack_confirmation_token_service.dart';

/// Shared LifeTrack confirmation token service for Mind connectors.
final LifeTrackConfirmationTokenService sharedLifeTrackConfirmationTokens =
    LifeTrackConfirmationTokenService(
      store: SecureConfirmationTokenStore(),
    );
