import 'package:feature_iptv/feature_iptv.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('native edge intelligence resolves bundled IPTV pack', (
    tester,
  ) async {
    final container = ProviderContainer(
      overrides: [
        edgeIptvConfigProvider.overrideWithValue(
          EdgeIptvConfig.fromValues(
            backend: 'native',
            packAsset: 'assets/packs/media.iptv.airo-sample-0.1.0.pack',
          ),
        ),
      ],
    );
    addTearDown(container.dispose);

    final assistant = container.read(edgeIptvAssistantProvider);

    final resolution = await assistant.resolveNaturalLanguage('Play Aaj Tak');

    expect(resolution.message, isNull);
    expect(resolution.media?.title, 'Aaj Tak');
    expect(
      resolution.channel?.streamUrl,
      'https://example.com/aaj-tak/index.m3u8',
    );
  });
}
