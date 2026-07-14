import 'package:flutter/material.dart';

const double _kIptvSheetDialogBreakpoint = 720;

Future<T?> showAdaptiveIptvSheet<T>({
  required BuildContext context,
  required WidgetBuilder builder,
  double maxWidth = 640,
  double maxHeight = 720,
  bool isDismissible = true,
}) {
  final mediaQuery = MediaQuery.of(context);
  final useDialog = mediaQuery.size.width >= _kIptvSheetDialogBreakpoint;

  if (useDialog) {
    return showDialog<T>(
      context: context,
      barrierDismissible: isDismissible,
      builder: (context) {
        final viewInsets = MediaQuery.of(context).viewInsets;
        return Padding(
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
