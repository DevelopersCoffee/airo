import 'dart:async';

import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';

import 'shell_id.dart';

/// How [AiroBootstrap.run] wires the global error handler for one shell.
///
/// Deliberately not a plain nullable callback. Issue #1680's audit found the
/// error handler wired in `main.dart` and `main_tv.dart` but silently absent
/// from `main_mind.dart`, `main_coins.dart`, and `main_qualification.dart` —
/// a gap nothing forced anyone to notice. [ErrorHandlerPolicy.disabled]
/// requires a [reason] so skipping crash reporting is a reviewable decision
/// left in the code, not an omission indistinguishable from a bug.
sealed class ErrorHandlerPolicy {
  const ErrorHandlerPolicy();

  /// Calls [initialize] once, before `runApp`. Pass the shell's
  /// `GlobalErrorHandler.initialize` (or an equivalent).
  const factory ErrorHandlerPolicy.enabled(VoidCallback initialize) =
      _EnabledErrorHandlerPolicy;

  /// Explicit, documented opt-out. [reason] is required so the omission
  /// reads as a decision in review and in `git blame`, never a silent gap.
  const factory ErrorHandlerPolicy.disabled({required String reason}) =
      _DisabledErrorHandlerPolicy;
}

final class _EnabledErrorHandlerPolicy extends ErrorHandlerPolicy {
  const _EnabledErrorHandlerPolicy(this.initialize);

  final VoidCallback initialize;
}

final class _DisabledErrorHandlerPolicy extends ErrorHandlerPolicy {
  const _DisabledErrorHandlerPolicy({required this.reason});

  final String reason;
}

/// Whether, when, and how [AiroBootstrap.run] initializes Firebase for one
/// shell.
///
/// The three pre-#1680 implementations (`main.dart`, `main_mind.dart`,
/// `main_tv.dart`) shared the same core algorithm — skip when the platform
/// isn't configured, treat an already-initialized app (web's `index.html`
/// bootstrap, or a hot-restart) as success, log and degrade gracefully on
/// failure — but differed in one load-bearing way: the super app and Airo
/// Mind `await` Firebase *before* `runApp` because their first frame can
/// gate on auth state, while Airo TV defers it to *after* the first frame so
/// a slow or unreachable Firebase backend never delays a TV boot straight to
/// the guide. That timing difference is preserved as
/// [FirebasePolicy.blocking] vs [FirebasePolicy.deferred] rather than
/// flattened into one behavior.
///
/// [isConfigured] and [variantName] are computed by the call site (each
/// flavor's generated `firebase_options.dart`, which this shared package
/// cannot import) rather than inside this policy, so each shell keeps its
/// own pre-existing "is this platform configured" check exactly as it was —
/// `main.dart`/`main_mind.dart` also reject placeholder per-option config
/// (`DefaultFirebaseOptions.isConfigured(options)`), a check `main_tv.dart`
/// never had; unifying the *algorithm* does not mean unifying that check.
sealed class FirebasePolicy {
  const FirebasePolicy();

  /// Initializes Firebase synchronously before `runApp`.
  const factory FirebasePolicy.blocking({
    required FirebaseOptions options,
    required bool isConfigured,
    void Function(bool initialized)? onResult,
    String? variantName,
    // Test seam only; production callers never pass this.
    Future<void> Function()? initializeApp,
  }) = _BlockingFirebasePolicy;

  /// Schedules Firebase initialization after the first frame so it never
  /// delays time-to-first-frame.
  const factory FirebasePolicy.deferred({
    required FirebaseOptions options,
    required bool isConfigured,
    void Function(bool initialized)? onResult,
    String? variantName,
    // Test seam only; production callers never pass this.
    Future<void> Function()? initializeApp,
  }) = _DeferredFirebasePolicy;

  /// Explicit, documented opt-out for a shell that ships no Firebase
  /// dependency at all (Airo Coins today — `pubspec_coins.yaml` carries no
  /// `firebase_core`). [reason] documents why, for the same audit reason as
  /// [ErrorHandlerPolicy.disabled].
  const factory FirebasePolicy.skip({required String reason}) =
      _SkipFirebasePolicy;
}

sealed class _FirebasePolicyWithOptions extends FirebasePolicy {
  const _FirebasePolicyWithOptions({
    required this.options,
    required this.isConfigured,
    this.onResult,
    this.variantName,
    this.initializeApp,
  });

  final FirebaseOptions options;
  final bool isConfigured;
  final void Function(bool initialized)? onResult;
  final String? variantName;

  /// Test seam: substitutes for the real `Firebase.initializeApp` call.
  /// Production callers never pass this.
  final Future<void> Function()? initializeApp;
}

final class _BlockingFirebasePolicy extends _FirebasePolicyWithOptions {
  const _BlockingFirebasePolicy({
    required super.options,
    required super.isConfigured,
    super.onResult,
    super.variantName,
    super.initializeApp,
  });
}

final class _DeferredFirebasePolicy extends _FirebasePolicyWithOptions {
  const _DeferredFirebasePolicy({
    required super.options,
    required super.isConfigured,
    super.onResult,
    super.variantName,
    super.initializeApp,
  });
}

final class _SkipFirebasePolicy extends FirebasePolicy {
  const _SkipFirebasePolicy({required this.reason});

  final String reason;
}

/// Shared bootstrap prologue for every Airo product shell (ADR-0011 SSOT
/// phase 2 — see issue #1680).
///
/// Before this, the code that runs ahead of `runApp` — Firebase init, the
/// global error handler, web semantics, deferred pro-module bootstrap — was
/// duplicated 3-4 different ways across `main.dart`, `main_mind.dart`,
/// `main_tv.dart`, `main_coins.dart`, and `main_qualification.dart`, and one
/// duplicate (the error handler) had silently drifted out of sync in three
/// of the five. [AiroBootstrap.run] owns the parts that were byte-identical
/// or should have been, and exposes explicit phase hooks — [earlyPhase],
/// [composeApp], [afterRunApp] — for the parts that are genuinely
/// ordering-sensitive per shell (Airo TV's image-cache budget → system
/// chrome → prefs → audio service → `runApp` sequence is load-bearing and
/// must not be flattened).
abstract final class AiroBootstrap {
  /// Runs the shared bootstrap prologue for [shell], then `runApp`.
  ///
  /// Fixed sequence:
  /// 1. `WidgetsFlutterBinding.ensureInitialized()`.
  /// 2. [earlyPhase] — setup that must run before even the error handler
  ///    (Airo TV's image-cache budget + memory-pressure observer, wired up
  ///    before anything else can allocate images).
  /// 3. [errorHandler] wiring.
  /// 4. Web semantics, if [enableWebSemantics] and running on web.
  /// 5. Blocking Firebase init, if [firebase] is [FirebasePolicy.blocking].
  /// 6. [composeApp] — everything ordering-sensitive between the fixed
  ///    prologue and `runApp` (Airo TV's system chrome → prefs → audio
  ///    service; the super app's prefs → module registry → router). Returns
  ///    the widget to run.
  /// 7. `runApp(...)`.
  /// 8. Deferred Firebase init, if [firebase] is [FirebasePolicy.deferred]
  ///    (scheduled for after the first frame; never blocks it).
  /// 9. [afterRunApp] — deferred/best-effort startup work (module
  ///    initialization, pro bootstrap, playlist/EPG warmups, lifecycle
  ///    listeners). Each shell composes its own list and order here, the
  ///    same as it did before #1680 — this hook exists so those ordering
  ///    choices stay with the shell that needs them instead of being forced
  ///    into one fixed sequence.
  static Future<void> run({
    required ShellId shell,
    required ErrorHandlerPolicy errorHandler,
    required FirebasePolicy firebase,
    required FutureOr<Widget> Function() composeApp,
    FutureOr<void> Function()? earlyPhase,
    FutureOr<void> Function()? afterRunApp,
    bool enableWebSemantics = true,
    void Function(String message)? log,
    // Test seams only; production callers never pass either. [runWidget]
    // substitutes for the real `runApp` — the real one asserts it is only
    // ever called from inside `testWidgets`' frame-pumping machinery, which
    // this method's own unit tests have no reason to spin up.
    // [schedulePostFrameCallback] substitutes for
    // `WidgetsBinding.instance.addPostFrameCallback` for the same reason.
    void Function(Widget widget)? runWidget,
    void Function(void Function(Duration timestamp) callback)?
    schedulePostFrameCallback,
  }) async {
    final logger = log ?? debugPrint;

    WidgetsFlutterBinding.ensureInitialized();

    if (earlyPhase != null) {
      await earlyPhase();
    }

    switch (errorHandler) {
      case _EnabledErrorHandlerPolicy(:final initialize):
        initialize();
      case _DisabledErrorHandlerPolicy(:final reason):
        logger(
          '⚠️ Global error handler disabled for shell "${shell.value}": '
          '$reason',
        );
    }

    if (enableWebSemantics && kIsWeb) {
      SemanticsBinding.instance.ensureSemantics();
      logger('🔧 Semantics enabled for "${shell.value}" web testing');
    }

    if (firebase case final _BlockingFirebasePolicy policy) {
      await _initializeFirebase(policy, logger);
    }

    final app = await composeApp();
    (runWidget ?? runApp)(app);

    if (firebase case final _DeferredFirebasePolicy policy) {
      _scheduleAfterFirstFrame(
        debugName: 'firebase_initialization',
        log: logger,
        task: () => _initializeFirebase(policy, logger),
        schedule: schedulePostFrameCallback,
      );
    }

    if (afterRunApp != null) {
      await afterRunApp();
    }
  }

  /// Shared Firebase init algorithm. See [FirebasePolicy] for why timing is
  /// a per-shell choice while this algorithm is not.
  static Future<bool> _initializeFirebase(
    _FirebasePolicyWithOptions policy,
    void Function(String message) log,
  ) async {
    try {
      if (Firebase.apps.isNotEmpty) {
        log('✅ Firebase already initialized');
        policy.onResult?.call(true);
        return true;
      }
      if (!policy.isConfigured) {
        log('⚠️ Firebase not configured for this platform; skipping init');
        policy.onResult?.call(false);
        return false;
      }
      await (policy.initializeApp ??
          () => Firebase.initializeApp(options: policy.options))();
      log(
        policy.variantName != null && policy.variantName!.isNotEmpty
            ? '✅ Firebase initialized (variant: ${policy.variantName})'
            : '✅ Firebase initialized successfully',
      );
      policy.onResult?.call(true);
      return true;
    } catch (e) {
      // On web, Firebase might already be initialized from index.html by
      // the time the exception (e.g. a duplicate-app error) surfaces.
      if (kIsWeb && Firebase.apps.isNotEmpty) {
        log('✅ Firebase available (initialized from index.html)');
        policy.onResult?.call(true);
        return true;
      }
      log('⚠️ Firebase initialization failed: $e');
      policy.onResult?.call(false);
      return false;
    }
  }

  /// Minimal post-first-frame scheduling, mirroring
  /// `core_app_shell`'s `scheduleDeferredStartupTask` without adding a
  /// dependency from this shared, shell-count-agnostic contract package onto
  /// that (heavier) app-shell infrastructure package.
  static void _scheduleAfterFirstFrame({
    required String debugName,
    required FutureOr<void> Function() task,
    required void Function(String message) log,
    void Function(void Function(Duration timestamp) callback)? schedule,
  }) {
    final schedulePostFrame =
        schedule ?? WidgetsBinding.instance.addPostFrameCallback;
    schedulePostFrame((_) {
      unawaited(
        Future<void>.sync(task).then(
          (_) => log('✅ Deferred startup task completed: $debugName'),
          onError: (Object error, StackTrace stackTrace) {
            log('⚠️ Deferred startup task failed: $debugName: $error');
          },
        ),
      );
    });
  }
}
