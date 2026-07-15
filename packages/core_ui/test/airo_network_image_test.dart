import 'package:core_ui/core_ui.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:platform_device_profile/platform_device_profile.dart';

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

  testWidgets('trims supported URLs before creating network image', (
    tester,
  ) async {
    await tester.pumpWidget(
      const Directionality(
        textDirection: TextDirection.ltr,
        child: AiroNetworkImage(url: '  https://example.com/logo.png  '),
      ),
    );

    final image = tester.widget<Image>(find.byType(Image));
    final imageProvider = image.image as ResizeImage;
    final networkImage = imageProvider.imageProvider as NetworkImage;
    expect(networkImage.url, 'https://example.com/logo.png');
  });

  testWidgets('routes unsupported URLs to fallback without image request', (
    tester,
  ) async {
    Object? capturedError;

    await tester.pumpWidget(
      Directionality(
        textDirection: TextDirection.ltr,
        child: AiroNetworkImage(
          url: 'javascript:alert(1)',
          errorBuilder: (context, error, stackTrace) {
            capturedError = error;
            return const SizedBox(key: ValueKey('fallback'));
          },
        ),
      ),
    );

    expect(find.byType(Image), findsNothing);
    expect(find.byKey(const ValueKey('fallback')), findsOneWidget);
    expect(capturedError, isA<ArgumentError>());
    expect(
      capturedError.toString(),
      contains(AiroNetworkImageUrlPolicy.unsupportedUrlCode),
    );
    expect(capturedError.toString(), isNot(contains('javascript')));
  });

  test('URL policy accepts only absolute http and https URLs with hosts', () {
    expect(
      AiroNetworkImageUrlPolicy.accepts('https://example.com/a.png'),
      isTrue,
    );
    expect(
      AiroNetworkImageUrlPolicy.accepts('http://example.com/a.png'),
      isTrue,
    );
    expect(AiroNetworkImageUrlPolicy.accepts('file:///tmp/a.png'), isFalse);
    expect(AiroNetworkImageUrlPolicy.accepts('javascript:alert(1)'), isFalse);
    expect(AiroNetworkImageUrlPolicy.accepts('/relative/a.png'), isFalse);
    expect(AiroNetworkImageUrlPolicy.accepts(''), isFalse);
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

  test('configures Android TV image cache from runtime memory budget', () {
    final imageCache = PaintingBinding.instance.imageCache;
    final originalMaximumSize = imageCache.maximumSize;
    final originalMaximumSizeBytes = imageCache.maximumSizeBytes;
    addTearDown(() {
      imageCache.maximumSize = originalMaximumSize;
      imageCache.maximumSizeBytes = originalMaximumSizeBytes;
    });

    AiroImageCacheBudget.configureAndroidTv(
      memoryBudget: AiroRuntimeMemoryBudgetPolicy.androidTvStandardBudget,
    );

    expect(
      imageCache.maximumSize,
      AiroRuntimeMemoryBudgetPolicy.standardTvImageCacheEntries,
    );
    expect(
      imageCache.maximumSizeBytes,
      AiroRuntimeMemoryBudgetPolicy.standardTvImageCacheMb *
          AiroRuntimeMemoryBudgetPolicy.bytesPerMb,
    );
  });
}
