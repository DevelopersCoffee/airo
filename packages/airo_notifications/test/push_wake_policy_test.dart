import 'package:airo_notifications/airo_notifications.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const engine = PushWakePolicyEngine();

  test('local-only mode denies push wake when home node unavailable', () {
    const request = PushWakeRequest(
      requestId: 'req_1',
      targetDeviceId: 'dev_1',
      isTvProfile: false,
      isLocalOnlyMode: true,
      isExpired: false,
      isHomeNodeAvailable: false,
      hasPushProviderAvailable: true,
    );

    expect(engine.evaluate(request), PushWakeOutcome.deny);
  });

  test('local-only mode returns localReconnect when home node is available', () {
    const request = PushWakeRequest(
      requestId: 'req_2',
      targetDeviceId: 'dev_1',
      isTvProfile: false,
      isLocalOnlyMode: true,
      isExpired: false,
      isHomeNodeAvailable: true,
      hasPushProviderAvailable: true,
    );

    expect(engine.evaluate(request), PushWakeOutcome.localReconnect);
  });

  test('TV profiles return visibleNotification when push provider available', () {
    const request = PushWakeRequest(
      requestId: 'req_3',
      targetDeviceId: 'dev_tv',
      isTvProfile: true,
      isLocalOnlyMode: false,
      isExpired: false,
      isHomeNodeAvailable: false,
      hasPushProviderAvailable: true,
    );

    expect(engine.evaluate(request), PushWakeOutcome.visibleNotification);
  });

  test('expired requests return deny outcome', () {
    const request = PushWakeRequest(
      requestId: 'req_4',
      targetDeviceId: 'dev_1',
      isTvProfile: false,
      isLocalOnlyMode: false,
      isExpired: true,
      isHomeNodeAvailable: true,
      hasPushProviderAvailable: true,
    );

    expect(engine.evaluate(request), PushWakeOutcome.deny);
  });
}
