import 'package:airo_app/core/services/voice_search_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('unavailable voice service does not claim release readiness', () async {
    final service = MockVoiceSearchService();
    addTearDown(service.dispose);

    expect(await service.isAvailable(), isFalse);
    final result = await service.startListening();

    expect(result.isSuccess, isFalse);
    expect(result.errorMessage, contains('unavailable'));
    expect(service.state, VoiceSearchState.error);
  });

  test('stopListening returns the service to idle', () async {
    final service = MockVoiceSearchService();
    addTearDown(service.dispose);

    await service.startListening();
    await service.stopListening();

    expect(service.state, VoiceSearchState.idle);
  });
}
