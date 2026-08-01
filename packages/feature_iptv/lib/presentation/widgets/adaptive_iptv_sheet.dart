import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

const double _kIptvSheetDialogBreakpoint = 720;

Future<T?> showAdaptiveIptvSheet<T>({
  required BuildContext context,
  required WidgetBuilder builder,
  double maxWidth = 640,
  double maxHeight = 720,
  bool isDismissible = true,
  bool absorbAndroidTvRawBack = false,
}) {
  final mediaQuery = MediaQuery.of(context);
  final useDialog = mediaQuery.size.width >= _kIptvSheetDialogBreakpoint;

  if (useDialog) {
    return showDialog<T>(
      context: context,
      barrierDismissible: isDismissible,
      builder: (context) {
        final viewInsets = MediaQuery.of(context).viewInsets;
        final dialog = Padding(
          padding: EdgeInsets.fromLTRB(24, 24, 24, 24 + viewInsets.bottom),
          child: Dialog(
            insetPadding: EdgeInsets.zero,
            clipBehavior: Clip.antiAlias,
            child: ConstrainedBox(
              constraints: BoxConstraints(
                maxWidth: maxWidth,
                maxHeight: maxHeight,
              ),
              child: SingleChildScrollView(child: builder(context)),
            ),
          ),
        );
        if (!absorbAndroidTvRawBack ||
            defaultTargetPlatform != TargetPlatform.android) {
          return dialog;
        }

        // Fire OS dispatches one remote BACK as a raw key followed by the
        // Android platform pop. Material's dialog shortcuts dismiss on the
        // raw half, which leaves the paired pop to close the underlying TV
        // activity. Absorb only that raw half; the platform pop still
        // dismisses this route exactly once.
        return Focus(
          canRequestFocus: false,
          onKeyEvent: (_, event) {
            if (event is KeyDownEvent &&
                (event.logicalKey == LogicalKeyboardKey.escape ||
                    event.logicalKey == LogicalKeyboardKey.goBack ||
                    event.logicalKey == LogicalKeyboardKey.browserBack)) {
              return KeyEventResult.handled;
            }
            return KeyEventResult.ignored;
          },
          child: dialog,
        );
      },
    );
  }

  return showModalBottomSheet<T>(
    context: context,
    isScrollControlled: true,
    isDismissible: isDismissible,
    useSafeArea: true,
    showDragHandle: true,
    builder: builder,
  );
}
