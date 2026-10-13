import 'package:airo_app/features/iptv/fire_tv_cast_overrides.dart';
import 'package:feature_iptv/feature_iptv.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('fireTvCastProviderOverrides wires unavailable cast transports', () {
    final container = ProviderContainer(
      overrides: fireTvCastProviderOverrides(),
    );
    addTearDown(container.dispose);

    expect(
      container.read(airoCastControllerProvider),
      isA<UnavailableAiroCastController>(),
    );
    expect(
      container.read(multiviewCastSenderTransportProvider),
      isA<UnavailableMultiviewCastSenderTransport>(),
    );
    expect(
      container.read(multiviewCastReceiverTransportProvider),
      isA<UnavailableMultiviewCastReceiverTransport>(),
    );
  });
}
