import 'package:core_ui/core_ui.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('sets cache size from rendered bounds and pixel ratio', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      const Directionality(
        textDirection: TextDirection.ltr,
        child: Center(
          child: SizedBox(
            width: 40,
            height: 30,
            child: AiroNetworkImage(url: 'https://example.com/logo.png'),
          ),
        ),
      ),
    );

    final image = tester.widget<Image>(find.byType(Image));
    final imageProvider = image.image as ResizeImage;
    expect(imageProvider.width, 80);
    expect(imageProvider.height, 60);
  });

  testWidgets('clamps very large decode dimensions', (tester) async {
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      const Directionality(
        textDirection: TextDirection.ltr,
        child: Center(
          child: SizedBox(
            width: 600,
            height: 500,
            child: AiroNetworkImage(
              url: 'https://example.com/logo.png',
              maxDecodeDimension: 256,
            ),
          ),
        ),
      ),
    );

    final image = tester.widget<Image>(find.byType(Image));
    final imageProvider = image.image as ResizeImage;
    expect(imageProvider.width, 256);
    expect(imageProvider.height, 256);
  });

  test('configures Android TV image cache budget', () {
    final imageCache = PaintingBinding.instance.imageCache;
    final originalMaximumSize = imageCache.maximumSize;
    final originalMaximumSizeBytes = imageCache.maximumSizeBytes;
    addTearDown(() {
      imageCache.maximumSize = originalMaximumSize;
      imageCache.maximumSizeBytes = originalMaximumSizeBytes;
    });

    AiroImageCacheBudget.configureAndroidTv(
      maximumSize: 12,
      maximumSizeBytes: 34,
    );

    expect(imageCache.maximumSize, 12);
    expect(imageCache.maximumSizeBytes, 34);
  });
}
