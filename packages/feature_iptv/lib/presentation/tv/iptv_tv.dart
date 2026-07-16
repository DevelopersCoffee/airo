import 'package:core_ui/core_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';

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
