import 'package:flutter/material.dart';
import '../adaptive/adaptive_ui_models.dart';
import 'empty_state_widget.dart';
import 'error_view.dart';
import 'loading_indicator.dart';

/// A platform-level responsive scaffold that automatically adapts to device form factor,
/// window orientation, text scaling, and interface density.
///
/// Integrates with the [AiroAdaptiveUiPolicy] to resolve layout styling and constraints.
/// Supports slot-based state handling for loading, empty, and error scenarios.
class AiroResponsiveScaffold extends StatelessWidget {
  const AiroResponsiveScaffold({
    super.key,
    required this.body,
    this.appBar,
    this.bottomNavigationBar,
    this.drawer,
    this.floatingActionButton,
    this.overrideFormFactor,
    this.isLoading = false,
    this.loadingWidget,
    this.isEmpty = false,
    this.emptyTitle,
    this.emptyMessage,
    this.emptyIcon,
    this.emptyAction,
    this.emptyWidget,
    this.errorMessage,
    this.errorWidget,
    this.onRetry,
    this.useResponsiveCenter = true,
    this.maxWidth = 1000.0,
    this.padding,
    this.resizeToAvoidBottomInset = true,
    this.backgroundColor,
  });

  /// The main content of the scaffold when in the normal/content state.
  final Widget body;

  /// Optional app bar to display at the top of the scaffold.
  final PreferredSizeWidget? appBar;

  /// Optional bottom navigation bar.
  final Widget? bottomNavigationBar;

  /// Optional drawer menu.
  final Widget? drawer;

  /// Optional floating action button.
  final Widget? floatingActionButton;

  /// Explicitly override the detected device form factor (e.g. force TV or Desktop).
  final AiroFormFactor? overrideFormFactor;

  /// When true, replaces the body with a loading state display.
  final bool isLoading;

  /// Custom widget to display when [isLoading] is true. Defaults to [LoadingIndicator].
  final Widget? loadingWidget;

  /// When true, replaces the body with an empty state display.
  final bool isEmpty;

  /// Optional title for the empty state display.
  final String? emptyTitle;

  /// Optional message details for the empty state display.
  final String? emptyMessage;

  /// Optional icon to represent the empty state.
  final IconData? emptyIcon;

  /// Optional action widget (such as a reload button) for the empty state.
  final Widget? emptyAction;

  /// Custom widget override for the empty state.
  final Widget? emptyWidget;

  /// When not null, replaces the body with an error state display showing this message.
  final String? errorMessage;

  /// Custom widget override for the error state.
  final Widget? errorWidget;

  /// Callback action for the "Retry" button when in the error state.
  final VoidCallback? onRetry;

  /// When true, constrains the content width on large screen sizes.
  final bool useResponsiveCenter;

  /// The maximum layout width of the content area. Defaults to 1000.0.
  final double maxWidth;

  /// Padding applied around the body content. If null, a responsive padding is calculated.
  final EdgeInsetsGeometry? padding;

  /// Whether the body should resize to avoid the software keyboard.
  final bool resizeToAvoidBottomInset;

  /// Optional background color. If null, Scaffold uses default theme background.
  final Color? backgroundColor;

  @override
  Widget build(BuildContext context) {
    final mediaQuery = MediaQuery.of(context);
    final width = mediaQuery.size.width;

    // 1. Resolve Adaptive UI Parameters using AiroAdaptiveUiPolicy
    final formFactor = overrideFormFactor ?? _resolveFormFactor(width);
    final windowClass = _resolveWindowClass(width);
    final orientation = mediaQuery.orientation == Orientation.portrait
        ? AiroOrientation.portrait
        : AiroOrientation.landscape;

    // Screen reader and accessibility traits detection
    final accessibility = AiroAccessibilityPreferences(
      requiresLargeTargets:
          mediaQuery.navigationMode == NavigationMode.directional ||
          formFactor == AiroFormFactor.tv,
      requiresLargeText: mediaQuery.textScaler.scale(10) > 12.5,
      reduceMotion: mediaQuery.disableAnimations,
      highContrast: mediaQuery.highContrast,
      screenReaderEnabled: mediaQuery.accessibleNavigation,
    );

    final Set<AiroInputDevice> inputDevices = {};
    if (formFactor == AiroFormFactor.tv) {
      inputDevices.add(AiroInputDevice.remote);
    } else if (formFactor == AiroFormFactor.desktop) {
      inputDevices.add(AiroInputDevice.pointer);
      inputDevices.add(AiroInputDevice.keyboard);
    } else {
      inputDevices.add(AiroInputDevice.touch);
    }

    final viewingDistance = formFactor == AiroFormFactor.tv
        ? AiroViewingDistance.couch
        : formFactor == AiroFormFactor.desktop
        ? AiroViewingDistance.desk
        : AiroViewingDistance.handheld;

    final input = AiroAdaptiveUiInput(
      formFactor: formFactor,
      inputDevices: inputDevices,
      viewingDistance: viewingDistance,
      windowClass: windowClass,
      orientation: orientation,
      accessibility: accessibility,
    );

    final mode = const AiroAdaptiveUiPolicy().resolve(input);

    // 2. Select state representation
    Widget content;
    if (isLoading) {
      content = loadingWidget ?? const Center(child: LoadingIndicator());
    } else if (errorMessage != null) {
      content =
          errorWidget ?? ErrorView(message: errorMessage!, onRetry: onRetry);
    } else if (isEmpty) {
      content =
          emptyWidget ??
          EmptyStateWidget(
            title: emptyTitle,
            message: emptyMessage ?? 'No items found.',
            icon: emptyIcon,
            action: emptyAction,
          );
    } else {
      // Normal state: Apply accessibility touch target sizing if needed
      content =
          mediaQuery.accessibleNavigation || accessibility.requiresLargeTargets
          ? Theme(
              data: Theme.of(
                context,
              ).copyWith(materialTapTargetSize: MaterialTapTargetSize.padded),
              child: body,
            )
          : body;
    }

    // 3. Apply responsive padding and centering
    final resolvedPadding = padding ?? _getResponsivePadding(width, mode);

    // Don't apply responsive centering constraints on TV
    if (useResponsiveCenter &&
        mode.navigationStyle != AiroNavigationStyle.tvRows &&
        formFactor != AiroFormFactor.tv) {
      content = Center(
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: maxWidth),
          child: Padding(padding: resolvedPadding, child: content),
        ),
      );
    } else {
      content = Padding(padding: resolvedPadding, child: content);
    }

    // 4. Wrap with screen-reader friendly Semantics tree container
    content = Semantics(container: true, child: content);

    return Scaffold(
      appBar: appBar,
      body: content,
      bottomNavigationBar: bottomNavigationBar,
      drawer: drawer,
      floatingActionButton: floatingActionButton,
      resizeToAvoidBottomInset: resizeToAvoidBottomInset,
      backgroundColor: backgroundColor,
    );
  }

  AiroFormFactor _resolveFormFactor(double width) {
    if (width >= 1024) return AiroFormFactor.desktop;
    if (width >= 600) return AiroFormFactor.tablet;
    return AiroFormFactor.phone;
  }

  AiroWindowClass _resolveWindowClass(double width) {
    if (width < 600) return AiroWindowClass.compact;
    if (width < 1024) return AiroWindowClass.medium;
    if (width < 1440) return AiroWindowClass.expanded;
    return AiroWindowClass.fullBleed;
  }

  EdgeInsetsGeometry _getResponsivePadding(
    double width,
    AiroAdaptiveUiMode mode,
  ) {
    final basePadding = mode.density == AiroUiDensity.sparse
        ? 24.0
        : mode.density == AiroUiDensity.comfortable
        ? 20.0
        : mode.density == AiroUiDensity.compact
        ? 12.0
        : 16.0;

    final horizontalPadding = (width * 0.05).clamp(basePadding, 48.0);
    return EdgeInsets.symmetric(
      horizontal: horizontalPadding,
      vertical: basePadding,
    );
  }
}
