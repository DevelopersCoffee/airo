import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

/// One-time brand asset generator, not a behavioral test.
///
/// Run with:
///   flutter test test/asset_gen --update-goldens
/// then copy the emitted PNGs from test/asset_gen/goldens/ into
/// app/android/app/src/tv/res/ (banner) and .../main/res/ (launch logo).
///
/// Uses a host system font for the wordmark (test fonts render as blocks),
/// so it self-skips on machines without it (e.g. Linux CI).
const _fontPath = '/System/Library/Fonts/Supplemental/Arial Bold.ttf';

const _airoNavy = Color(0xFF020419);
const _airoGreen = Color(0xFF3DDC84);

class _BrandMark extends StatelessWidget {
  const _BrandMark({required this.scale, this.subtitle = false});

  /// 1.0 == sized for the 320x180 banner.
  final double scale;
  final bool subtitle;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: _airoNavy,
      child: Center(
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 84 * scale,
              height: 84 * scale,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: _airoGreen,
                borderRadius: BorderRadius.circular(22 * scale),
                boxShadow: [
                  BoxShadow(
                    color: _airoGreen.withValues(alpha: 0.45),
                    blurRadius: 34 * scale,
                  ),
                ],
              ),
              child: Text(
                'A',
                style: TextStyle(
                  fontFamily: 'BrandFont',
                  fontSize: 52 * scale,
                  fontWeight: FontWeight.w700,
                  color: _airoNavy,
                ),
              ),
            ),
            SizedBox(width: 22 * scale),
            Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'AIRO TV',
                  style: TextStyle(
                    fontFamily: 'BrandFont',
                    fontSize: 40 * scale,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 2.4 * scale,
                    color: Colors.white,
                  ),
                ),
                if (subtitle)
                  Text(
                    'LIVE TV PLAYER',
                    style: TextStyle(
                      fontFamily: 'BrandFont',
                      fontSize: 12 * scale,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 5.2 * scale,
                      color: _airoGreen,
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

Future<void> _pumpAtSize(
  WidgetTester tester,
  Size size,
  Widget child,
) async {
  await tester.binding.setSurfaceSize(size);
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  await tester.pumpWidget(
    MediaQuery(
      data: const MediaQueryData(),
      child: Directionality(textDirection: TextDirection.ltr, child: child),
    ),
  );
}

void main() {
  final hasFont = File(_fontPath).existsSync();

  setUpAll(() async {
    if (!hasFont) return;
    final loader = FontLoader('BrandFont')
      ..addFont(
        Future.value(
          File(_fontPath).readAsBytesSync().buffer.asByteData(),
        ),
      );
    await loader.load();
  });

  tearDown(() async {
    await TestWidgetsFlutterBinding.instance.setSurfaceSize(null);
  });

  testWidgets('tv banner 320x180 (xhdpi)', (tester) async {
    await _pumpAtSize(
      tester,
      const Size(320, 180),
      const _BrandMark(scale: 1),
    );
    await expectLater(
      find.byType(_BrandMark),
      matchesGoldenFile('goldens/tv_banner_xhdpi.png'),
    );
  }, skip: !hasFont);

  testWidgets('tv banner 480x270 (xxhdpi)', (tester) async {
    await _pumpAtSize(
      tester,
      const Size(480, 270),
      const _BrandMark(scale: 1.5),
    );
    await expectLater(
      find.byType(_BrandMark),
      matchesGoldenFile('goldens/tv_banner_xxhdpi.png'),
    );
  }, skip: !hasFont);

  testWidgets('launch logo 640x360', (tester) async {
    await _pumpAtSize(
      tester,
      const Size(640, 360),
      const _BrandMark(scale: 1.6, subtitle: true),
    );
    await expectLater(
      find.byType(_BrandMark),
      matchesGoldenFile('goldens/launch_logo.png'),
    );
  }, skip: !hasFont);
}
