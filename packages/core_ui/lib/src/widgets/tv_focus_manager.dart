import 'package:flutter/material.dart';

/// Focus memory entry for restoring focus when navigating back to a screen.
class FocusMemoryEntry {
  final String screenId;
  final String? itemId;
  final int? index;
  final DateTime timestamp;

  FocusMemoryEntry({
    required this.screenId,
    this.itemId,
    this.index,
    DateTime? timestamp,
  }) : timestamp = timestamp ?? DateTime.now();
}

/// TV focus manager for tracking and restoring D-pad focus state across
/// screens/sections. Handles focus traversal, focus memory, and section
/// registration for TV navigation.
class TvFocusManager extends ChangeNotifier {
  final Map<String, FocusMemoryEntry> _focusMemory = {};
  final Map<String, FocusNode> _registeredNodes = {};
  String? _currentSectionId;
  String? _currentItemId;

  /// Current focused section ID.
  String? get currentSectionId => _currentSectionId;

  /// Current focused item ID within the section.
  String? get currentItemId => _currentItemId;

  /// Register a focus node for a section.
  void registerSection(String sectionId, FocusNode node) {
    _registeredNodes[sectionId] = node;
  }

  /// Unregister a focus node.
  void unregisterSection(String sectionId) {
    _registeredNodes.remove(sectionId);
  }

  /// Request focus for a section.
  void focusSection(String sectionId) {
    final node = _registeredNodes[sectionId];
    if (node != null && node.canRequestFocus) {
      node.requestFocus();
      _currentSectionId = sectionId;
      notifyListeners();
    }
  }

  /// Save focus state for a screen.
  void saveFocusState({required String screenId, String? itemId, int? index}) {
    _focusMemory[screenId] = FocusMemoryEntry(
      screenId: screenId,
      itemId: itemId,
      index: index,
    );
  }

  /// Get saved focus state for a screen.
  FocusMemoryEntry? getFocusState(String screenId) => _focusMemory[screenId];

  /// Clear focus state for a screen.
  void clearFocusState(String screenId) {
    _focusMemory.remove(screenId);
  }

  /// Update current focus position.
  void updateFocus({String? sectionId, String? itemId}) {
    var changed = false;
    if (sectionId != null && sectionId != _currentSectionId) {
      _currentSectionId = sectionId;
      changed = true;
    }
    if (itemId != null && itemId != _currentItemId) {
      _currentItemId = itemId;
      changed = true;
    }
    if (changed) notifyListeners();
  }

  /// Navigate focus in a direction. Returns true if handled.
  bool navigate(TraversalDirection direction) {
    final currentFocus = FocusManager.instance.primaryFocus;
    if (currentFocus == null) return false;
    return currentFocus.focusInDirection(direction);
  }

  /// Move focus to the next focusable widget.
  bool focusNext() {
    final currentFocus = FocusManager.instance.primaryFocus;
    if (currentFocus == null) return false;
    return currentFocus.nextFocus();
  }

  /// Move focus to the previous focusable widget.
  bool focusPrevious() {
    final currentFocus = FocusManager.instance.primaryFocus;
    if (currentFocus == null) return false;
    return currentFocus.previousFocus();
  }

  @override
  void dispose() {
    _registeredNodes.clear();
    _focusMemory.clear();
    super.dispose();
  }
}

/// Configuration for focus wrap-around behavior.
class TvFocusWrapConfig {
  final bool wrapHorizontal;
  final bool wrapVertical;

  const TvFocusWrapConfig({
    this.wrapHorizontal = true,
    this.wrapVertical = false,
  });

  static const TvFocusWrapConfig defaultTv = TvFocusWrapConfig(
    wrapHorizontal: true,
    wrapVertical: false,
  );

  static const TvFocusWrapConfig fullWrap = TvFocusWrapConfig(
    wrapHorizontal: true,
    wrapVertical: true,
  );

  static const TvFocusWrapConfig noWrap = TvFocusWrapConfig(
    wrapHorizontal: false,
    wrapVertical: false,
  );
}

/// Standard navigation hint messages for TV UI.
class TvNavigationHints {
  TvNavigationHints._();

  static const String selectHint = 'Press OK to select';
  static const String navigationHint = 'Use arrows to navigate';
  static const String combinedHint = 'Press OK to select • ← → ↑ ↓ to navigate';
  static const String backHint = 'Press Back to return';
  static const String mediaHint = 'Press Play/Pause to control playback';
  static const String voiceSearchHint = 'Press mic button for voice search';
}

/// TV-specific UI dimensions (10-foot UI sizing).
class TvUiDimensions {
  final double minTargetSize;
  final double cardPadding;
  final double gridSpacing;
  final double controlButtonSize;
  final double textScaleFactor;
  final double channelCardWidth;
  final double channelCardHeight;
  final double focusBorderWidth;
  final EdgeInsets safeZone;

  const TvUiDimensions._({
    required this.minTargetSize,
    required this.cardPadding,
    required this.gridSpacing,
    required this.controlButtonSize,
    required this.textScaleFactor,
    required this.channelCardWidth,
    required this.channelCardHeight,
    required this.focusBorderWidth,
    this.safeZone = EdgeInsets.zero,
  });

  /// TV dimensions (10-foot UI). Pass [safeZone] for platforms that need
  /// extra padding (e.g. Fire TV's overscan-safe area).
  factory TvUiDimensions.tv({EdgeInsets safeZone = EdgeInsets.zero}) =>
      TvUiDimensions._(
        minTargetSize: 56,
        cardPadding: 16,
        gridSpacing: 24,
        controlButtonSize: 64,
        textScaleFactor: 1.25,
        channelCardWidth: 200,
        channelCardHeight: 150,
        focusBorderWidth: 3,
        safeZone: safeZone,
      );

  /// Mobile/touch dimensions.
  factory TvUiDimensions.mobile() => const TvUiDimensions._(
    minTargetSize: 48,
    cardPadding: 12,
    gridSpacing: 16,
    controlButtonSize: 48,
    textScaleFactor: 1,
    channelCardWidth: 140,
    channelCardHeight: 100,
    focusBorderWidth: 2,
  );
}
