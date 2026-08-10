import 'package:feature_iptv/feature_iptv.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'channelLibraryMergerProvider defaults to exact id/URL merge',
    () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final merger = container.read(channelLibraryMergerProvider);
      final merged = merger([
        const [
          IPTVChannel(
            id: 'shared',
            name: 'Shared News',
            streamUrl: 'https://cdn.example.com/shared-hd.m3u8',
          ),
        ],
        const [
          IPTVChannel(
            id: 'shared',
            name: 'Shared News',
            streamUrl: 'https://cdn.example.com/shared-sd.m3u8',
          ),
        ],
      ]);

      expect(merged, hasLength(1));
      expect(merged.single.streamSources, hasLength(2));
    },
  );
}
