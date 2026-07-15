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

    test('lite receiver resolves strict D-pad focus performance budget', () {
      final budget = policy.resolveLegacyPerformanceBudget(
        AiroAdaptiveUiInput(
          formFactor: AiroFormFactor.tv,
          inputDevices: const {AiroInputDevice.remote},
          viewingDistance: AiroViewingDistance.couch,
          windowClass: AiroWindowClass.fullBleed,
          orientation: AiroOrientation.landscape,
          profileHint: AiroProductUiProfileHint.liteReceiver,
        ),
      );

      expect(budget.budgetId, AiroLegacyUiBudgetId.liteReceiver);
      expect(budget.satisfiesLegacyFocusTarget, isTrue);
      expect(budget.maxFocusResponseMs, 80);
      expect(budget.maxFocusAnimationMs, 80);
      expect(budget.maxArtworkCacheMb, 16);
      expect(budget.maxVisiblePosterCount, 12);
      expect(budget.maxPreloadAheadItems, 2);
      expect(budget.requiresFocusRestore, isTrue);
      expect(budget.requiresSelectorScopedRebuilds, isTrue);
      expect(budget.requiresLongListVirtualization, isTrue);
      expect(budget.allowsAutoplayPreviews, isFalse);
      expect(budget.allowsBlurEffects, isFalse);
      expect(budget.allowsParallax, isFalse);
      expect(budget.allowsShaderEffects, isFalse);
      expect(
        budget.requiredRules,
        containsAll(const {
          AiroLegacyUiPerformanceRule.dpadFocusRestoration,
          AiroLegacyUiPerformanceRule.artworkLoadingIsolation,
          AiroLegacyUiPerformanceRule.selectorScopedRebuilds,
        }),
      );
    });

    test(
      'standard TV keeps richer budget while preserving D-pad stability',
      () {
        final budget = policy.resolveLegacyPerformanceBudget(
          AiroAdaptiveUiInput(
            formFactor: AiroFormFactor.tv,
            inputDevices: const {AiroInputDevice.remote},
            viewingDistance: AiroViewingDistance.couch,
            windowClass: AiroWindowClass.fullBleed,
            orientation: AiroOrientation.landscape,
            profileHint: AiroProductUiProfileHint.standardTv,
          ),
        );

        expect(budget.budgetId, AiroLegacyUiBudgetId.standardTv);
        expect(budget.satisfiesLegacyFocusTarget, isTrue);
        expect(budget.maxFocusResponseMs, 100);
        expect(budget.maxArtworkCacheMb, 48);
        expect(budget.maxVisiblePosterCount, 24);
        expect(budget.requiresFocusRestore, isTrue);
        expect(budget.allowsAutoplayPreviews, isFalse);
        expect(budget.allowsBlurEffects, isFalse);
      },
    );

    test('accessibility preferences tighten TV motion and focus budget', () {
      final budget = policy.resolveLegacyPerformanceBudget(
        AiroAdaptiveUiInput(
          formFactor: AiroFormFactor.tv,
          inputDevices: const {AiroInputDevice.remote},
          viewingDistance: AiroViewingDistance.couch,
          windowClass: AiroWindowClass.fullBleed,
          orientation: AiroOrientation.landscape,
          accessibility: const AiroAccessibilityPreferences(
            requiresLargeTargets: true,
            reduceMotion: true,
          ),
          profileHint: AiroProductUiProfileHint.standardTv,
        ),
      );

      expect(budget.budgetId, AiroLegacyUiBudgetId.accessibilityConstrained);
      expect(budget.maxFocusAnimationMs, 0);
      expect(budget.mode.motionPolicy, AiroMotionPolicy.reduced);
      expect(budget.mode.minTargetSize, 64);
      expect(
        budget.requiredRules,
        contains(AiroLegacyUiPerformanceRule.shaderEffectsDisabled),
      );
    });

    test('companion touch mode avoids D-pad restoration requirements', () {
      final budget = policy.resolveLegacyPerformanceBudget(
        AiroAdaptiveUiInput(
          formFactor: AiroFormFactor.phone,
          inputDevices: const {AiroInputDevice.touch},
          viewingDistance: AiroViewingDistance.handheld,
          windowClass: AiroWindowClass.compact,
          orientation: AiroOrientation.portrait,
          profileHint: AiroProductUiProfileHint.companion,
        ),
      );

      expect(budget.budgetId, AiroLegacyUiBudgetId.companionDefault);
      expect(budget.requiresFocusRestore, isFalse);
      expect(
        budget.requiredRules,
        isNot(contains(AiroLegacyUiPerformanceRule.dpadFocusRestoration)),
      );
      expect(budget.requiresLongListVirtualization, isFalse);
    });

    test(
      'budget public map exposes stable thresholds without widget dumps',
      () {
        final budget = policy.resolveLegacyPerformanceBudget(
          AiroAdaptiveUiInput(
            formFactor: AiroFormFactor.tv,
            inputDevices: const {AiroInputDevice.remote},
            viewingDistance: AiroViewingDistance.couch,
            windowClass: AiroWindowClass.fullBleed,
            orientation: AiroOrientation.landscape,
            profileHint: AiroProductUiProfileHint.liteReceiver,
          ),
        );

        final publicMap = budget.toPublicMap();

        expect(publicMap, containsPair('budgetId', 'lite_receiver'));
        expect(publicMap, containsPair('maxFocusResponseMs', 80));
        expect(publicMap, isNot(contains('widgetTreeDump')));
        expect(publicMap, isNot(contains('screenshotPath')));
        expect(publicMap, isNot(contains('deviceSerial')));
      },
    );
  });
}
