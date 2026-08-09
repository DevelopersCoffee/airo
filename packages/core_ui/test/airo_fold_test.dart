import 'dart:ui';

import 'package:core_ui/core_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('AiroFold.of', () {
    testWidgets('no displayFeatures reports FoldPosture.none', (
      tester,
    ) async {
      late FoldInfo fold;
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) {
              fold = AiroFold.of(context);
              return const SizedBox.shrink();
            },
          ),
        ),
      );

      expect(fold.posture, FoldPosture.none);
      expect(fold.hingeBounds, isNull);
    });

    testWidgets('a flat hinge (postureFlat) still reports FoldPosture.none', (
      tester,
    ) async {
      late FoldInfo fold;
      await tester.pumpWidget(
        MediaQuery(
          data: MediaQueryData(
            size: const Size(2208, 1840),
            displayFeatures: const [
              DisplayFeature(
                bounds: Rect.fromLTWH(1090, 0, 28, 1840),
                type: DisplayFeatureType.hinge,
                state: DisplayFeatureState.postureFlat,
              ),
            ],
          ),
          child: MaterialApp(
            home: Builder(
              builder: (context) {
                fold = AiroFold.of(context);
                return const SizedBox.shrink();
              },
            ),
          ),
        ),
      );

      expect(fold.posture, FoldPosture.none);
    });

    testWidgets(
      'a vertical half-opened hinge reports FoldPosture.halfOpened and '
      'straddles() a rect spanning both sides',
      (tester) async {
        const hingeBounds = Rect.fromLTWH(1090, 0, 28, 1840);
        late FoldInfo fold;
        await tester.pumpWidget(
          MediaQuery(
            data: const MediaQueryData(
              size: Size(2208, 1840),
              displayFeatures: [
                DisplayFeature(
                  bounds: hingeBounds,
                  type: DisplayFeatureType.hinge,
                  state: DisplayFeatureState.postureHalfOpened,
                ),
              ],
            ),
            child: MaterialApp(
              home: Builder(
                builder: (context) {
                  fold = AiroFold.of(context);
                  return const SizedBox.shrink();
                },
              ),
            ),
          ),
        );

        expect(fold.posture, FoldPosture.halfOpened);
        expect(fold.hingeBounds, hingeBounds);

        expect(
          AiroFold.straddles(const Rect.fromLTWH(0, 0, 2208, 1840), fold),
          isTrue,
          reason: 'a full-width rect spans both sides of a vertical hinge',
        );
        expect(
          AiroFold.straddles(const Rect.fromLTWH(0, 0, 1090, 1840), fold),
          isFalse,
          reason: 'a rect confined to the left pane never crosses the hinge',
        );
        expect(
          AiroFold.straddles(const Rect.fromLTWH(1118, 0, 1090, 1840), fold),
          isFalse,
          reason:
              'a rect confined to the right pane never crosses the hinge',
        );
      },
    );

    testWidgets(
      'a horizontal half-opened hinge reports FoldPosture.tabletop',
      (tester) async {
        late FoldInfo fold;
        await tester.pumpWidget(
          MediaQuery(
            data: const MediaQueryData(
              size: Size(1840, 2208),
              displayFeatures: [
                DisplayFeature(
                  bounds: Rect.fromLTWH(0, 1090, 1840, 28),
                  type: DisplayFeatureType.hinge,
                  state: DisplayFeatureState.postureHalfOpened,
                ),
              ],
            ),
            child: MaterialApp(
              home: Builder(
                builder: (context) {
                  fold = AiroFold.of(context);
                  return const SizedBox.shrink();
                },
              ),
            ),
          ),
        );

        expect(fold.posture, FoldPosture.tabletop);
      },
    );
  });
}
