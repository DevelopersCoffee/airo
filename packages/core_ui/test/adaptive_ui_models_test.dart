import 'package:core_ui/core_ui.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('AiroAdaptiveUiPolicy', () {
    const policy = AiroAdaptiveUiPolicy();

    test('resolves TV remote input to remote-first focus mode', () {
      final mode = policy.resolve(
        AiroAdaptiveUiInput(
          formFactor: AiroFormFactor.tv,
          inputDevices: const {AiroInputDevice.remote},
          viewingDistance: AiroViewingDistance.couch,
          windowClass: AiroWindowClass.fullBleed,
          orientation: AiroOrientation.landscape,
          profileHint: AiroProductUiProfileHint.standardTv,
        ),
      );

      expect(mode.interactionMode, AiroInteractionMode.remote);
      expect(mode.focusBehavior, AiroFocusBehavior.dpadRequired);
      expect(mode.density, AiroUiDensity.comfortable);
      expect(mode.typographyScale, AiroTypographyScale.large);
      expect(mode.navigationStyle, AiroNavigationStyle.tvRows);
      expect(mode.minTargetSize, 56);
      expect(mode.requiresFocusPersistence, isTrue);
    });

    test('resolves phone touch input without D-pad focus requirements', () {
      final mode = policy.resolve(
        AiroAdaptiveUiInput(
          formFactor: AiroFormFactor.phone,
          inputDevices: const {AiroInputDevice.touch},
          viewingDistance: AiroViewingDistance.handheld,
          windowClass: AiroWindowClass.compact,
          orientation: AiroOrientation.portrait,
          profileHint: AiroProductUiProfileHint.companion,
        ),
      );

      expect(mode.interactionMode, AiroInteractionMode.touch);
      expect(mode.focusBehavior, AiroFocusBehavior.none);
      expect(mode.navigationStyle, AiroNavigationStyle.bottomBar);
      expect(mode.minTargetSize, 48);
      expect(mode.requiresFocusPersistence, isFalse);
    });

    test('resolves desktop pointer input to dense sidebar navigation', () {
      final mode = policy.resolve(
        AiroAdaptiveUiInput(
          formFactor: AiroFormFactor.desktop,
          inputDevices: const {AiroInputDevice.pointer},
          viewingDistance: AiroViewingDistance.desk,
          windowClass: AiroWindowClass.expanded,
          orientation: AiroOrientation.landscape,
        ),
      );

      expect(mode.interactionMode, AiroInteractionMode.pointer);
      expect(mode.focusBehavior, AiroFocusBehavior.pointerHover);
      expect(mode.density, AiroUiDensity.compact);
      expect(mode.navigationStyle, AiroNavigationStyle.sidebar);
      expect(mode.minTargetSize, 40);
    });

    test('resolves touch plus remote input to hybrid-safe focus mode', () {
      final mode = policy.resolve(
        AiroAdaptiveUiInput(
          formFactor: AiroFormFactor.tablet,
          inputDevices: const {AiroInputDevice.touch, AiroInputDevice.remote},
          viewingDistance: AiroViewingDistance.desk,
          windowClass: AiroWindowClass.medium,
          orientation: AiroOrientation.landscape,
        ),
      );

      expect(mode.interactionMode, AiroInteractionMode.hybrid);
      expect(mode.focusBehavior, AiroFocusBehavior.hybridSafe);
      expect(mode.minTargetSize, 56);
      expect(mode.requiresFocusPersistence, isTrue);
    });

    test(
      'accessibility preferences force larger targets and reduced motion',
      () {
        final mode = policy.resolve(
          AiroAdaptiveUiInput(
            formFactor: AiroFormFactor.phone,
            inputDevices: const {AiroInputDevice.touch},
            viewingDistance: AiroViewingDistance.handheld,
            windowClass: AiroWindowClass.compact,
            orientation: AiroOrientation.portrait,
            accessibility: const AiroAccessibilityPreferences(
              requiresLargeTargets: true,
              requiresLargeText: true,
              reduceMotion: true,
              screenReaderEnabled: true,
            ),
          ),
        );

        expect(mode.density, AiroUiDensity.sparse);
        expect(mode.typographyScale, AiroTypographyScale.extraLarge);
        expect(mode.motionPolicy, AiroMotionPolicy.reduced);
        expect(mode.minTargetSize, 64);
      },
    );

    test('constrained receiver profile reduces artwork and data density', () {
      final mode = policy.resolve(
        AiroAdaptiveUiInput(
          formFactor: AiroFormFactor.tv,
          inputDevices: const {AiroInputDevice.remote},
          viewingDistance: AiroViewingDistance.couch,
          windowClass: AiroWindowClass.fullBleed,
          orientation: AiroOrientation.landscape,
          profileHint: AiroProductUiProfileHint.experimentalLegacy,
        ),
      );

      expect(mode.density, AiroUiDensity.compact);
      expect(mode.artworkPolicy, AiroArtworkPolicy.minimal);
      expect(mode.motionPolicy, AiroMotionPolicy.reduced);
      expect(mode.focusBehavior, AiroFocusBehavior.dpadRequired);
    });
  });
}
