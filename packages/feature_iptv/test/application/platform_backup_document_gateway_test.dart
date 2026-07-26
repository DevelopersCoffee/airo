import 'package:feature_iptv/feature_iptv.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:platform_playlist_export/platform_playlist_export.dart';

void main() {
  const document = AiroBackupDocument(
    fileName: 'backup.json',
    mediaType: 'application/json',
    contents: '{}',
  );

  test(
    'delegates save, share, pick and preserves picker cancellation',
    () async {
      final saved = <AiroBackupDocument>[];
      final shared = <AiroBackupDocument>[];
      var pickCount = 0;
      final gateway = PlatformBackupDocumentGateway(
        saver: (value) async => saved.add(value),
        sharer: (value) async => shared.add(value),
        picker: () async {
          pickCount++;
          return pickCount == 1 ? document : null;
        },
      );

      await gateway.save(document);
      await gateway.share(document);

      expect(await gateway.pick(), same(document));
      expect(await gateway.pick(), isNull);
      expect(saved, [document]);
      expect(shared, [document]);
    },
  );
}
