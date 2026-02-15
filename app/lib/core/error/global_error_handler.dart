import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../shared/widgets/bug_report_dialog.dart';
import '../utils/logger.dart';

/// Global error handler that captures unhandled exceptions and shows
/// the bug report dialog for critical errors.
class GlobalErrorHandler {
  GlobalErrorHandler._();

  static GlobalKey<NavigatorState>? _navigatorKey;
  static bool _isDialogShowing = false;
  static bool _isInitialized = false;

  /// Sets the navigator key for showing dialogs.
  /// Call this after the app is built with the router's navigator key.
  static void setNavigatorKey(GlobalKey<NavigatorState> navigatorKey) {
    _navigatorKey = navigatorKey;
  }

  /// Initialize the global error handler.
  ///
  /// Call this in main() before runApp():
  /// ```dart
  /// GlobalErrorHandler.initialize();
  /// runApp(MyApp());
  /// ```
  ///
  /// Then in your app, set the navigator key:
  /// ```dart
  /// GlobalErrorHandler.setNavigatorKey(router.routerDelegate.navigatorKey);
  /// ```
  static void initialize({GlobalKey<NavigatorState>? navigatorKey}) {
    if (_isInitialized) return;
    _isInitialized = true;

    if (navigatorKey != null) {
      _navigatorKey = navigatorKey;
    }

    // Handle Flutter framework errors
    FlutterError.onError = _handleFlutterError;

    // Handle errors outside of Flutter framework (async errors, etc.)
    PlatformDispatcher.instance.onError = _handlePlatformError;
  }

  /// Handle Flutter framework errors (widget build errors, etc.)
  static void _handleFlutterError(FlutterErrorDetails details) {
    // Log the error
    AppLogger.error(
      'Flutter error: ${details.exceptionAsString()}',
      tag: 'FLUTTER_ERROR',
      error: details.exception,
      stackTrace: details.stack,
    );

    // In debug mode, use the default handler to show the red error screen
    if (kDebugMode) {
      FlutterError.presentError(details);
      return;
    }

    // In release mode, show bug report dialog for critical errors
    _showBugReportDialogIfNeeded(
      error: details.exception,
      stackTrace: details.stack,
      context: details.context?.toDescription() ?? 'Flutter error',
    );
  }

  /// Handle platform errors (async errors, isolate errors, etc.)
  static bool _handlePlatformError(Object error, StackTrace stack) {
    // Log the error
    AppLogger.error(
      'Unhandled exception: $error',
      tag: 'PLATFORM_ERROR',
      error: error,
      stackTrace: stack,
    );

    // Show bug report dialog for critical errors
    _showBugReportDialogIfNeeded(
      error: error,
      stackTrace: stack,
      context: 'Unhandled exception',
    );

    // Return true to indicate the error was handled
    return true;
  }

  /// Shows the bug report dialog if conditions are met.
  static void _showBugReportDialogIfNeeded({
    required Object error,
    StackTrace? stackTrace,
    required String context,
  }) {
    // Don't show multiple dialogs
    if (_isDialogShowing) return;

    // Need a navigator to show dialog
    final navigatorState = _navigatorKey?.currentState;
    if (navigatorState == null) {
      AppLogger.warning(
        'Cannot show bug report dialog: no navigator available',
        tag: 'ERROR_HANDLER',
      );
      return;
    }

    // Get the current context
    final currentContext = navigatorState.context;

    // Mark dialog as showing
    _isDialogShowing = true;

    // Show the dialog
    BugReportDialog.show(
      currentContext,
      initialError: '$context\n\n$error',
      initialStackTrace: stackTrace?.toString(),
    ).then((_) {
      _isDialogShowing = false;
    });
  }

  /// Manually trigger the bug report dialog for a caught error.
  ///
  /// Use this when you catch an error and want to give the user
  /// the option to report it:
  /// ```dart
  /// try {
  ///   await riskyOperation();
  /// } catch (e, stack) {
  ///   GlobalErrorHandler.reportError(context, e, stack);
  /// }
  /// ```
  static void reportError(
    BuildContext context,
    Object error,
    StackTrace? stackTrace,
  ) {
    AppLogger.error(
      'User-triggered error report: $error',
      tag: 'USER_REPORT',
      error: error,
      stackTrace: stackTrace,
    );

    BugReportDialog.show(
      context,
      initialError: error.toString(),
      initialStackTrace: stackTrace?.toString(),
    );
  }
}

/// Runs the app with global error handling.
///
/// Usage in main.dart:
/// ```dart
/// void main() async {
///   WidgetsFlutterBinding.ensureInitialized();
///   final navigatorKey = GlobalKey<NavigatorState>();
///   runAppWithErrorHandling(
///     navigatorKey: navigatorKey,
///     app: MyApp(navigatorKey: navigatorKey),
///   );
/// }
/// ```
void runAppWithErrorHandling({
  required GlobalKey<NavigatorState> navigatorKey,
  required Widget app,
}) {
  GlobalErrorHandler.initialize(navigatorKey: navigatorKey);
  runApp(app);
}
