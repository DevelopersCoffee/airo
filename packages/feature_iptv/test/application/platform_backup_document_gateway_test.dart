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
        saver: (value) async {
          saved.add(value);
          return true;
        },
        sharer: (value) async {
          shared.add(value);
          return true;
        },
        picker: () async {
          pickCount++;
          return pickCount == 1 ? document : null;
        },
      );

      expect(await gateway.save(document), isTrue);
      expect(await gateway.share(document), isTrue);

      expect(await gateway.pick(), same(document));
      expect(await gateway.pick(), isNull);
      expect(saved, [document]);
      expect(shared, [document]);
    },
  );

  test('reports failure when the platform writes nothing', () async {
    // The shape TV always takes: `file_picker` and `share_plus` are
    // dependency-overridden to stubs, so neither ever completes.
    const gateway = PlatformBackupDocumentGateway(
      saver: _refuse,
      sharer: _refuse,
    );

    expect(await gateway.save(document), isFalse);
    expect(await gateway.share(document), isFalse);
  });
}

Future<bool> _refuse(AiroBackupDocument document) async => false;
