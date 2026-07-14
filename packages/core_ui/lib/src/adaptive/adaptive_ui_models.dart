enum AiroFormFactor {
  phone('phone'),
  tablet('tablet'),
  tv('tv'),
  desktop('desktop'),
  embedded('embedded');

  const AiroFormFactor(this.stableId);

  final String stableId;
}

enum AiroInputDevice {
  touch('touch'),
  pointer('pointer'),
  remote('remote'),
  keyboard('keyboard'),
  gamepad('gamepad'),
  voice('voice');

  const AiroInputDevice(this.stableId);

  final String stableId;
}

enum AiroViewingDistance {
  handheld('handheld'),
  desk('desk'),
  couch('couch'),
  wall('wall');

  const AiroViewingDistance(this.stableId);

  final String stableId;
}

enum AiroWindowClass {
  compact('compact'),
  medium('medium'),
  expanded('expanded'),
  fullBleed('full_bleed');

  const AiroWindowClass(this.stableId);

  final String stableId;
}

enum AiroOrientation {
  portrait('portrait'),
  landscape('landscape'),
  square('square');

  const AiroOrientation(this.stableId);

  final String stableId;
}

enum AiroProductUiProfileHint {
  full('full'),
  standardTv('standard_tv'),
  liteReceiver('lite_receiver'),
  embeddedReceiver('embedded_receiver'),
  experimentalLegacy('experimental_legacy'),
  companion('companion');

  const AiroProductUiProfileHint(this.stableId);

  final String stableId;

  bool get isConstrainedReceiver =>
      this == liteReceiver ||
      this == embeddedReceiver ||
      this == experimentalLegacy;
}

enum AiroInteractionMode {
  touch('touch'),
  pointer('pointer'),
  remote('remote'),
  keyboard('keyboard'),
  hybrid('hybrid');

  const AiroInteractionMode(this.stableId);

  final String stableId;
}

enum AiroUiDensity {
  comfortable('comfortable'),
  balanced('balanced'),
  compact('compact'),
  sparse('sparse');

  const AiroUiDensity(this.stableId);

  final String stableId;
}

enum AiroTypographyScale {
  compact('compact'),
  normal('normal'),
  large('large'),
  extraLarge('extra_large');

  const AiroTypographyScale(this.stableId);

  final String stableId;
}

enum AiroFocusBehavior {
  none('none'),
  pointerHover('pointer_hover'),
  dpadRequired('dpad_required'),
  hybridSafe('hybrid_safe');

  const AiroFocusBehavior(this.stableId);

  final String stableId;
}

enum AiroArtworkPolicy {
  rich('rich'),
  reduced('reduced'),
  minimal('minimal');

  const AiroArtworkPolicy(this.stableId);

  final String stableId;
}

enum AiroMotionPolicy {
  standard('standard'),
  reduced('reduced'),
  disabled('disabled');

  const AiroMotionPolicy(this.stableId);

  final String stableId;
}

enum AiroNavigationStyle {
  bottomBar('bottom_bar'),
  rail('rail'),
  sidebar('sidebar'),
  tvRows('tv_rows'),
  compactTabs('compact_tabs');

  const AiroNavigationStyle(this.stableId);

  final String stableId;
}

enum AiroLegacyUiBudgetId {
  companionDefault('companion_default'),
  standardTv('standard_tv'),
  liteReceiver('lite_receiver'),
  accessibilityConstrained('accessibility_constrained');

  const AiroLegacyUiBudgetId(this.stableId);

  final String stableId;
}

enum AiroLegacyUiPerformanceRule {
  dpadFocusRestoration('dpad_focus_restoration'),
  boundedFocusAnimation('bounded_focus_animation'),
  rapidDpadInput('rapid_dpad_input'),
  artworkLoadingIsolation('artwork_loading_isolation'),
  selectorScopedRebuilds('selector_scoped_rebuilds'),
  longListVirtualization('long_list_virtualization'),
  autoplayPreviewDisabled('autoplay_preview_disabled'),
  blurEffectsDisabled('blur_effects_disabled'),
  parallaxDisabled('parallax_disabled'),
  shaderEffectsDisabled('shader_effects_disabled');

  const AiroLegacyUiPerformanceRule(this.stableId);

  final String stableId;
}

class AiroAccessibilityPreferences {
  const AiroAccessibilityPreferences({
    this.requiresLargeTargets = false,
    this.requiresLargeText = false,
    this.reduceMotion = false,
    this.highContrast = false,
    this.screenReaderEnabled = false,
  });

  final bool requiresLargeTargets;
  final bool requiresLargeText;
  final bool reduceMotion;
  final bool highContrast;
  final bool screenReaderEnabled;

  bool get needsExpandedUi => requiresLargeTargets || requiresLargeText;
}

class AiroAdaptiveUiInput {
  AiroAdaptiveUiInput({
    required this.formFactor,
    required Set<AiroInputDevice> inputDevices,
    required this.viewingDistance,
    required this.windowClass,
    required this.orientation,
    this.accessibility = const AiroAccessibilityPreferences(),
    this.profileHint = AiroProductUiProfileHint.full,
  }) : inputDevices = Set.unmodifiable(inputDevices);

  final AiroFormFactor formFactor;
  final Set<AiroInputDevice> inputDevices;
  final AiroViewingDistance viewingDistance;
  final AiroWindowClass windowClass;
  final AiroOrientation orientation;
  final AiroAccessibilityPreferences accessibility;
  final AiroProductUiProfileHint profileHint;

  bool hasInput(AiroInputDevice input) => inputDevices.contains(input);
}

class AiroAdaptiveUiMode {
  const AiroAdaptiveUiMode({
    required this.interactionMode,
    required this.density,
    required this.typographyScale,
    required this.focusBehavior,
    required this.artworkPolicy,
    required this.motionPolicy,
    required this.navigationStyle,
    required this.minTargetSize,
    required this.requiresFocusPersistence,
  });

  final AiroInteractionMode interactionMode;
  final AiroUiDensity density;
  final AiroTypographyScale typographyScale;
  final AiroFocusBehavior focusBehavior;
  final AiroArtworkPolicy artworkPolicy;
  final AiroMotionPolicy motionPolicy;
  final AiroNavigationStyle navigationStyle;
  final double minTargetSize;
  final bool requiresFocusPersistence;
}

class AiroLegacyUiPerformanceBudget {
  AiroLegacyUiPerformanceBudget({
    required this.budgetId,
    required this.mode,
    required this.maxFocusResponseMs,
    required this.maxFocusAnimationMs,
    required this.minRapidDpadIntervalMs,
    required this.maxVisiblePosterCount,
    required this.maxArtworkCacheMb,
    required this.maxPreloadAheadItems,
    required this.requiresFocusRestore,
    required this.requiresStableKeys,
    required this.requiresSelectorScopedRebuilds,
    required this.requiresLongListVirtualization,
    required this.allowsAutoplayPreviews,
    required this.allowsBlurEffects,
    required this.allowsParallax,
    required this.allowsShaderEffects,
    required Set<AiroLegacyUiPerformanceRule> requiredRules,
  }) : requiredRules = Set.unmodifiable(requiredRules);

  final AiroLegacyUiBudgetId budgetId;
  final AiroAdaptiveUiMode mode;
  final int maxFocusResponseMs;
  final int maxFocusAnimationMs;
  final int minRapidDpadIntervalMs;
  final int maxVisiblePosterCount;
  final int maxArtworkCacheMb;
  final int maxPreloadAheadItems;
  final bool requiresFocusRestore;
  final bool requiresStableKeys;
  final bool requiresSelectorScopedRebuilds;
  final bool requiresLongListVirtualization;
  final bool allowsAutoplayPreviews;
  final bool allowsBlurEffects;
  final bool allowsParallax;
  final bool allowsShaderEffects;
  final Set<AiroLegacyUiPerformanceRule> requiredRules;

  bool get satisfiesLegacyFocusTarget => maxFocusResponseMs <= 100;

  Map<String, Object?> toPublicMap() {
    return {
      'budgetId': budgetId.stableId,
      'interactionMode': mode.interactionMode.stableId,
      'focusBehavior': mode.focusBehavior.stableId,
      'artworkPolicy': mode.artworkPolicy.stableId,
      'motionPolicy': mode.motionPolicy.stableId,
      'maxFocusResponseMs': maxFocusResponseMs,
      'maxFocusAnimationMs': maxFocusAnimationMs,
      'minRapidDpadIntervalMs': minRapidDpadIntervalMs,
      'maxVisiblePosterCount': maxVisiblePosterCount,
      'maxArtworkCacheMb': maxArtworkCacheMb,
      'maxPreloadAheadItems': maxPreloadAheadItems,
      'requiresFocusRestore': requiresFocusRestore,
      'requiresStableKeys': requiresStableKeys,
      'requiresSelectorScopedRebuilds': requiresSelectorScopedRebuilds,
      'requiresLongListVirtualization': requiresLongListVirtualization,
      'allowsAutoplayPreviews': allowsAutoplayPreviews,
      'allowsBlurEffects': allowsBlurEffects,
      'allowsParallax': allowsParallax,
      'allowsShaderEffects': allowsShaderEffects,
      'requiredRules': requiredRules
          .map((rule) => rule.stableId)
          .toList(growable: false),
    };
  }
}

class AiroAdaptiveUiPolicy {
  const AiroAdaptiveUiPolicy();

  AiroAdaptiveUiMode resolve(AiroAdaptiveUiInput input) {
    final interactionMode = _resolveInteractionMode(input);
    final focusBehavior = _resolveFocusBehavior(input, interactionMode);
    final accessibility = input.accessibility;
    final constrained = input.profileHint.isConstrainedReceiver;

    return AiroAdaptiveUiMode(
      interactionMode: interactionMode,
      density: _resolveDensity(input, interactionMode, constrained),
      typographyScale: _resolveTypographyScale(input),
      focusBehavior: focusBehavior,
      artworkPolicy: _resolveArtworkPolicy(input, constrained),
      motionPolicy: accessibility.reduceMotion
          ? AiroMotionPolicy.reduced
          : constrained
          ? AiroMotionPolicy.reduced
          : AiroMotionPolicy.standard,
      navigationStyle: _resolveNavigationStyle(input, interactionMode),
      minTargetSize: _resolveMinTargetSize(input, interactionMode),
      requiresFocusPersistence:
          focusBehavior == AiroFocusBehavior.dpadRequired ||
          focusBehavior == AiroFocusBehavior.hybridSafe,
    );
  }

  AiroLegacyUiPerformanceBudget resolveLegacyPerformanceBudget(
    AiroAdaptiveUiInput input,
  ) {
    final mode = resolve(input);
    final constrained = input.profileHint.isConstrainedReceiver;
    final remoteDriven =
        mode.interactionMode == AiroInteractionMode.remote ||
        mode.interactionMode == AiroInteractionMode.hybrid;
    final accessibilityConstrained =
        input.accessibility.reduceMotion ||
        input.accessibility.needsExpandedUi ||
        input.accessibility.screenReaderEnabled;

    if (!remoteDriven && input.formFactor != AiroFormFactor.tv) {
      return _companionBudget(mode);
    }
    if (constrained || accessibilityConstrained) {
      return _constrainedReceiverBudget(
        mode,
        accessibilityConstrained: accessibilityConstrained,
      );
    }
    return _standardTvBudget(mode);
  }

  AiroInteractionMode _resolveInteractionMode(AiroAdaptiveUiInput input) {
    final hasTouch = input.hasInput(AiroInputDevice.touch);
    final hasPointer = input.hasInput(AiroInputDevice.pointer);
    final hasRemote =
        input.hasInput(AiroInputDevice.remote) ||
        input.hasInput(AiroInputDevice.gamepad);
    final hasKeyboard = input.hasInput(AiroInputDevice.keyboard);

    final activeFamilies = [
      hasTouch,
      hasPointer,
      hasRemote,
      hasKeyboard,
    ].where((active) => active).length;
    if (activeFamilies > 1) return AiroInteractionMode.hybrid;
    if (hasRemote || input.formFactor == AiroFormFactor.tv) {
      return AiroInteractionMode.remote;
    }
    if (hasPointer) return AiroInteractionMode.pointer;
    if (hasKeyboard) return AiroInteractionMode.keyboard;
    return AiroInteractionMode.touch;
  }

  AiroFocusBehavior _resolveFocusBehavior(
    AiroAdaptiveUiInput input,
    AiroInteractionMode mode,
  ) {
    if (mode == AiroInteractionMode.hybrid &&
        (input.hasInput(AiroInputDevice.remote) ||
            input.hasInput(AiroInputDevice.gamepad))) {
      return AiroFocusBehavior.hybridSafe;
    }
    if (mode == AiroInteractionMode.remote) {
      return AiroFocusBehavior.dpadRequired;
    }
    if (mode == AiroInteractionMode.pointer) {
      return AiroFocusBehavior.pointerHover;
    }
    return AiroFocusBehavior.none;
  }

  AiroUiDensity _resolveDensity(
    AiroAdaptiveUiInput input,
    AiroInteractionMode mode,
    bool constrained,
  ) {
    if (input.accessibility.needsExpandedUi) return AiroUiDensity.sparse;
    if (constrained) return AiroUiDensity.compact;
    if (mode == AiroInteractionMode.remote ||
        input.viewingDistance == AiroViewingDistance.couch ||
        input.viewingDistance == AiroViewingDistance.wall) {
      return AiroUiDensity.comfortable;
    }
    if (mode == AiroInteractionMode.pointer &&
        input.windowClass == AiroWindowClass.expanded) {
      return AiroUiDensity.compact;
    }
    return AiroUiDensity.balanced;
  }

  AiroTypographyScale _resolveTypographyScale(AiroAdaptiveUiInput input) {
    if (input.accessibility.requiresLargeText ||
        input.accessibility.screenReaderEnabled) {
      return AiroTypographyScale.extraLarge;
    }
    if (input.formFactor == AiroFormFactor.tv ||
        input.viewingDistance == AiroViewingDistance.couch ||
        input.viewingDistance == AiroViewingDistance.wall) {
      return AiroTypographyScale.large;
    }
    if (input.windowClass == AiroWindowClass.compact) {
      return AiroTypographyScale.normal;
    }
    return AiroTypographyScale.normal;
  }

  AiroArtworkPolicy _resolveArtworkPolicy(
    AiroAdaptiveUiInput input,
    bool constrained,
  ) {
    if (constrained) return AiroArtworkPolicy.minimal;
    if (input.accessibility.highContrast) return AiroArtworkPolicy.reduced;
    if (input.formFactor == AiroFormFactor.tv) return AiroArtworkPolicy.reduced;
    return AiroArtworkPolicy.rich;
  }

  AiroNavigationStyle _resolveNavigationStyle(
    AiroAdaptiveUiInput input,
    AiroInteractionMode mode,
  ) {
    if (mode == AiroInteractionMode.remote ||
        input.formFactor == AiroFormFactor.tv) {
      return AiroNavigationStyle.tvRows;
    }
    if (input.windowClass == AiroWindowClass.compact) {
      return AiroNavigationStyle.bottomBar;
    }
    if (input.windowClass == AiroWindowClass.medium) {
      return AiroNavigationStyle.rail;
    }
    if (mode == AiroInteractionMode.pointer) {
      return AiroNavigationStyle.sidebar;
    }
    return AiroNavigationStyle.rail;
  }

  double _resolveMinTargetSize(
    AiroAdaptiveUiInput input,
    AiroInteractionMode mode,
  ) {
    if (input.accessibility.requiresLargeTargets ||
        input.accessibility.screenReaderEnabled) {
      return 64;
    }
    if (mode == AiroInteractionMode.remote) return 56;
    if (mode == AiroInteractionMode.hybrid) return 56;
    if (mode == AiroInteractionMode.pointer) return 40;
    return 48;
  }

  AiroLegacyUiPerformanceBudget _companionBudget(AiroAdaptiveUiMode mode) {
    return AiroLegacyUiPerformanceBudget(
      budgetId: AiroLegacyUiBudgetId.companionDefault,
      mode: mode,
      maxFocusResponseMs: 150,
      maxFocusAnimationMs: 150,
      minRapidDpadIntervalMs: 0,
      maxVisiblePosterCount: 30,
      maxArtworkCacheMb: 64,
      maxPreloadAheadItems: 6,
      requiresFocusRestore: false,
      requiresStableKeys: true,
      requiresSelectorScopedRebuilds: true,
      requiresLongListVirtualization: false,
      allowsAutoplayPreviews: false,
      allowsBlurEffects: true,
      allowsParallax: false,
      allowsShaderEffects: false,
      requiredRules: const {AiroLegacyUiPerformanceRule.selectorScopedRebuilds},
    );
  }

  AiroLegacyUiPerformanceBudget _standardTvBudget(AiroAdaptiveUiMode mode) {
    return AiroLegacyUiPerformanceBudget(
      budgetId: AiroLegacyUiBudgetId.standardTv,
      mode: mode,
      maxFocusResponseMs: 100,
      maxFocusAnimationMs: 100,
      minRapidDpadIntervalMs: 80,
      maxVisiblePosterCount: 24,
      maxArtworkCacheMb: 48,
      maxPreloadAheadItems: 4,
      requiresFocusRestore: true,
      requiresStableKeys: true,
      requiresSelectorScopedRebuilds: true,
      requiresLongListVirtualization: true,
      allowsAutoplayPreviews: false,
      allowsBlurEffects: false,
      allowsParallax: false,
      allowsShaderEffects: false,
      requiredRules: const {
        AiroLegacyUiPerformanceRule.dpadFocusRestoration,
        AiroLegacyUiPerformanceRule.boundedFocusAnimation,
        AiroLegacyUiPerformanceRule.rapidDpadInput,
        AiroLegacyUiPerformanceRule.artworkLoadingIsolation,
        AiroLegacyUiPerformanceRule.selectorScopedRebuilds,
        AiroLegacyUiPerformanceRule.longListVirtualization,
        AiroLegacyUiPerformanceRule.autoplayPreviewDisabled,
        AiroLegacyUiPerformanceRule.blurEffectsDisabled,
        AiroLegacyUiPerformanceRule.parallaxDisabled,
      },
    );
  }

  AiroLegacyUiPerformanceBudget _constrainedReceiverBudget(
    AiroAdaptiveUiMode mode, {
    required bool accessibilityConstrained,
  }) {
    return AiroLegacyUiPerformanceBudget(
      budgetId: accessibilityConstrained
          ? AiroLegacyUiBudgetId.accessibilityConstrained
          : AiroLegacyUiBudgetId.liteReceiver,
      mode: mode,
      maxFocusResponseMs: 80,
      maxFocusAnimationMs: accessibilityConstrained ? 0 : 80,
      minRapidDpadIntervalMs: 100,
      maxVisiblePosterCount: 12,
      maxArtworkCacheMb: 16,
      maxPreloadAheadItems: 2,
      requiresFocusRestore: true,
      requiresStableKeys: true,
      requiresSelectorScopedRebuilds: true,
      requiresLongListVirtualization: true,
      allowsAutoplayPreviews: false,
      allowsBlurEffects: false,
      allowsParallax: false,
      allowsShaderEffects: false,
      requiredRules: const {
        AiroLegacyUiPerformanceRule.dpadFocusRestoration,
        AiroLegacyUiPerformanceRule.boundedFocusAnimation,
        AiroLegacyUiPerformanceRule.rapidDpadInput,
        AiroLegacyUiPerformanceRule.artworkLoadingIsolation,
        AiroLegacyUiPerformanceRule.selectorScopedRebuilds,
        AiroLegacyUiPerformanceRule.longListVirtualization,
        AiroLegacyUiPerformanceRule.autoplayPreviewDisabled,
        AiroLegacyUiPerformanceRule.blurEffectsDisabled,
        AiroLegacyUiPerformanceRule.parallaxDisabled,
        AiroLegacyUiPerformanceRule.shaderEffectsDisabled,
      },
    );
  }
}
