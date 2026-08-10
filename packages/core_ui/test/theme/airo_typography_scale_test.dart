import 'package:core_ui/core_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Future<double> headlineLargeSizeFor(
    WidgetTester tester, {
    required Size size,
  }) async {
    late double result;
    await tester.pumpWidget(
      MediaQuery(
        data: MediaQueryData(size: size),
        child: Builder(
          builder: (context) {
            result = AiroTypography.of(context).headlineLarge!.fontSize!;
            return const SizedBox.shrink();
          },
        ),
      ),
    );
    return result;
  }

  testWidgets('headlineLarge ("Display L") hits the documented px table', (
    tester,
  ) async {
    expect(
      await headlineLargeSizeFor(tester, size: const Size(375, 812)),
      32,
    );
    expect(
      await headlineLargeSizeFor(tester, size: const Size(768, 1024)),
      42,
    );
    expect(
      await headlineLargeSizeFor(tester, size: const Size(1920, 1080)),
      56,
    );
    expect(
      await headlineLargeSizeFor(tester, size: const Size(3840, 2160)),
      64,
    );
  });

  testWidgets('scaleFactorOf preserves an existing TextTheme font family', (
    tester,
  ) async {
    const customTheme = TextTheme(
      headlineLarge: TextStyle(fontFamily: 'AiroRulesExpanded', fontSize: 32),
    );
    late TextTheme scaled;
    await tester.pumpWidget(
      MediaQuery(
        data: const MediaQueryData(size: Size(1920, 1080)),
        child: Builder(
          builder: (context) {
            final factor = AiroTypography.scaleFactorOf(context);
            scaled = customTheme.apply(fontSizeFactor: factor);
            return const SizedBox.shrink();
          },
        ),
      ),
    );
    expect(scaled.headlineLarge!.fontFamily, 'AiroRulesExpanded');
    expect(scaled.headlineLarge!.fontSize, 56);
  });
}
