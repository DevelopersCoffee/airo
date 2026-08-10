import 'package:core_ui/core_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Future<AiroDisplayProfile> resolveIn(
    WidgetTester tester, {
    required Size size,
    double textScale = 1.0,
    bool highContrast = false,
  }) async {
    late AiroDisplayProfile captured;
    await tester.pumpWidget(
      MediaQuery(
        data: MediaQueryData(
          size: size,
          textScaler: TextScaler.linear(textScale),
          highContrast: highContrast,
        ),
        child: Builder(
          builder: (context) {
            captured = AiroDisplayProfile.resolve(context);
            return const SizedBox.shrink();
          },
        ),
      ),
    );
    return captured;
  }

  testWidgets('resolves compact for phone-sized viewport', (tester) async {
    final profile = await resolveIn(tester, size: const Size(375, 812));
    expect(profile, AiroDisplayProfile.compact);
  });

  testWidgets('resolves tablet for tablet-sized viewport', (tester) async {
    final profile = await resolveIn(tester, size: const Size(768, 1024));
    expect(profile, AiroDisplayProfile.tablet);
  });

  testWidgets('resolves tv for tv-sized viewport (1080p)', (tester) async {
    final profile = await resolveIn(tester, size: const Size(1920, 1080));
    expect(profile, AiroDisplayProfile.tv);
  });

  testWidgets('resolves largeDisplay for 4K tv viewport', (tester) async {
    final profile = await resolveIn(tester, size: const Size(3840, 2160));
    expect(profile, AiroDisplayProfile.largeDisplay);
  });

  testWidgets('resolves accessible when text scale is elevated regardless of size', (
    tester,
  ) async {
    final profile = await resolveIn(
      tester,
      size: const Size(375, 812),
      textScale: 1.5,
    );
    expect(profile, AiroDisplayProfile.accessible);
  });

  testWidgets('resolves highContrast when OS high contrast is on, wins over size', (
    tester,
  ) async {
    final profile = await resolveIn(
      tester,
      size: const Size(1920, 1080),
      highContrast: true,
    );
    expect(profile, AiroDisplayProfile.highContrast);
  });
}
