import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';

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

class TvFocusManager extends ChangeNotifier {
  final Map<String, FocusMemoryEntry> _focusMemory = {};
  final Map<String, FocusNode> _registeredNodes = {};
  String? _currentSectionId;
  String? _currentItemId;

  String? get currentSectionId => _currentSectionId;
  String? get currentItemId => _currentItemId;

  void registerSection(String sectionId, FocusNode node) {
    _registeredNodes[sectionId] = node;
  }

  void unregisterSection(String sectionId) {
    _registeredNodes.remove(sectionId);
  }

  void focusSection(String sectionId) {
    final node = _registeredNodes[sectionId];
    if (node != null && node.canRequestFocus) {
      node.requestFocus();
      _currentSectionId = sectionId;
      notifyListeners();
    }
  }

  void saveFocusState({required String screenId, String? itemId, int? index}) {
    _focusMemory[screenId] = FocusMemoryEntry(
      screenId: screenId,
      itemId: itemId,
      index: index,
    );
  }

  FocusMemoryEntry? getFocusState(String screenId) => _focusMemory[screenId];

  void clearFocusState(String screenId) {
    _focusMemory.remove(screenId);
  }
}

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
    required this.safeZone,
  });

  factory TvUiDimensions.tv() => const TvUiDimensions._(
    minTargetSize: 56,
    cardPadding: 16,
    gridSpacing: 24,
    controlButtonSize: 64,
    textScaleFactor: 1.25,
    channelCardWidth: 200,
    channelCardHeight: 150,
    focusBorderWidth: 3,
    safeZone: EdgeInsets.zero,
  );

  factory TvUiDimensions.mobile() => const TvUiDimensions._(
    minTargetSize: 48,
    cardPadding: 12,
    gridSpacing: 16,
    controlButtonSize: 48,
    textScaleFactor: 1,
    channelCardWidth: 140,
    channelCardHeight: 100,
    focusBorderWidth: 2,
    safeZone: EdgeInsets.zero,
  );
}

final tvFocusManagerProvider = ChangeNotifierProvider<TvFocusManager>((ref) {
  return TvFocusManager();
});

final isTvModeProvider = Provider.family<bool, BuildContext>((ref, context) {
  return MediaQuery.maybeOf(context)?.navigationMode ==
      NavigationMode.directional;
});

final tvDimensionsProvider = Provider.family<TvUiDimensions, BuildContext>((
  ref,
  context,
) {
  return ref.watch(isTvModeProvider(context))
      ? TvUiDimensions.tv()
      : TvUiDimensions.mobile();
});
