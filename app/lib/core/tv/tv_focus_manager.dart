import 'package:flutter/material.dart';

/// Focus memory entry for restoring focus when navigating back
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

/// TV Focus Manager for managing focus state across TV UI
///
/// Handles:
/// - Focus traversal between UI sections
/// - Focus memory (restore focus when returning to a screen)
/// - Focus trap prevention
/// - Visual focus state notifications
class TvFocusManager extends ChangeNotifier {
  final Map<String, FocusMemoryEntry> _focusMemory = {};
  final Map<String, FocusNode> _registeredNodes = {};
  String? _currentSectionId;
  String? _currentItemId;

  /// Current focused section ID
  String? get currentSectionId => _currentSectionId;

  /// Current focused item ID within the section
  String? get currentItemId => _currentItemId;

  /// Register a focus node for a section
  void registerSection(String sectionId, FocusNode node) {
    _registeredNodes[sectionId] = node;
  }

  /// Unregister a focus node
  void unregisterSection(String sectionId) {
    _registeredNodes.remove(sectionId);
  }

  /// Request focus for a section
  void focusSection(String sectionId) {
    final node = _registeredNodes[sectionId];
    if (node != null && node.canRequestFocus) {
      node.requestFocus();
      _currentSectionId = sectionId;
      notifyListeners();
    }
  }

  /// Save focus state for a screen
  void saveFocusState({required String screenId, String? itemId, int? index}) {
    _focusMemory[screenId] = FocusMemoryEntry(
      screenId: screenId,
      itemId: itemId,
      index: index,
    );
  }

  /// Get saved focus state for a screen
  FocusMemoryEntry? getFocusState(String screenId) {
    return _focusMemory[screenId];
  }

  /// Clear focus state for a screen
  void clearFocusState(String screenId) {
    _focusMemory.remove(screenId);
  }

  /// Update current focus position
  void updateFocus({String? sectionId, String? itemId}) {
    bool changed = false;
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

  /// Navigate focus in a direction
  /// Returns true if navigation was handled
  bool navigate(TraversalDirection direction) {
    // Get the primary focus and move it
    final currentFocus = FocusManager.instance.primaryFocus;
    if (currentFocus == null) return false;

    return currentFocus.focusInDirection(direction);
  }

  /// Move focus to next focusable widget
  bool focusNext() {
    final currentFocus = FocusManager.instance.primaryFocus;
    if (currentFocus == null) return false;
    return currentFocus.nextFocus();
  }

  /// Move focus to previous focusable widget
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

/// TV Focus constants
class TvFocusConstants {
  TvFocusConstants._();

  /// Default focus border width
  static const double focusBorderWidth = 3.0;

  /// Default focus border radius
  static const double focusBorderRadius = 8.0;

  /// Focus animation duration
  static const Duration focusAnimationDuration = Duration(milliseconds: 200);

  /// Focus scale factor (slight enlargement when focused)
  static const double focusScaleFactor = 1.05;

  /// Focus glow spread radius
  static const double focusGlowSpread = 4.0;
}

/// Configuration for focus wrap-around behavior
class TvFocusWrapConfig {
  /// Whether to wrap horizontally (left edge to right edge)
  final bool wrapHorizontal;

  /// Whether to wrap vertically (top edge to bottom edge)
  final bool wrapVertical;

  const TvFocusWrapConfig({
    this.wrapHorizontal = true,
    this.wrapVertical = false,
  });

  /// Default TV configuration with horizontal wrap
  static const TvFocusWrapConfig defaultTv = TvFocusWrapConfig(
    wrapHorizontal: true,
    wrapVertical: false,
  );

  /// Full wrap configuration (wraps in all directions)
  static const TvFocusWrapConfig fullWrap = TvFocusWrapConfig(
    wrapHorizontal: true,
    wrapVertical: true,
  );

  /// No wrap configuration
  static const TvFocusWrapConfig noWrap = TvFocusWrapConfig(
    wrapHorizontal: false,
    wrapVertical: false,
  );
}

/// Navigation hint messages for TV UI
class TvNavigationHints {
  TvNavigationHints._();

  /// Default hint for selection
  static const String selectHint = 'Press OK to select';

  /// Default hint for navigation
  static const String navigationHint = 'Use arrows to navigate';

  /// Combined hint for selection and navigation
  static const String combinedHint = 'Press OK to select • ← → ↑ ↓ to navigate';

  /// Hint for going back
  static const String backHint = 'Press Back to return';

  /// Hint for media playback
  static const String mediaHint = 'Press Play/Pause to control playback';

  /// Hint for Fire TV voice search
  static const String voiceSearchHint = 'Press mic button for voice search';
}
