/// Entrypoint for the Anya nutrition planner shell.
///
/// Anya is a focused product — diet profile, weekly meals, grocery, and
/// PDF import — not a Mind chat plugin. Firebase is skipped: this slice
/// is local-first JSON in secure storage with no auth surface.
///
/// ```bash
/// cd app
/// cp pubspec_anya.yaml pubspec.yaml && flutter pub get
/// flutter run -d chrome -t lib/main_anya.dart --dart-define=APP_VARIANT=anya
/// # Pixel with a local GGUF:
/// flutter run -d <pixel> -t lib/main_anya.dart --dart-define=APP_VARIANT=anya \
///   --dart-define=ANYA_GGUF_PATH=/path/to/model.gguf
/// ```
library;

import 'package:core_app_shell/core_app_shell.dart';
import 'package:core_product_shell/core_product_shell.dart';
import 'package:core_ui/core_ui.dart';
import 'package:feature_anya/feature_anya.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'anya/anya_plan_repair_factory_stub.dart'
    if (dart.library.io) 'anya/anya_plan_repair_factory_io.dart'
    as anya_repair;
import 'core/pro/pro_bootstrap_runner.dart';

void main() {
  late ModuleRegistry registry;

  AiroBootstrap.run(
    shell: ShellId.anya,
    errorHandler: ErrorHandlerPolicy.disabled(
      reason:
          'lean standalone shell; GlobalErrorHandler needs image_picker/'
          'package_info_plus/url_launcher/core_data, none of which '
          'pubspec_anya.yaml carries today',
    ),
    firebase: FirebasePolicy.skip(
      reason:
          'pubspec_anya.yaml carries no firebase_core dependency; '
          'Anya MVP is local-first with no auth surface',
    ),
    composeApp: () async {
      registry = buildAnyaModuleRegistry();
      final prefs = await SharedPreferences.getInstance();
      final repairPort = await anya_repair.createAnyaPlanRepairPort();
      return AiroAnyaApp(
        registry: registry,
        repository: SecureAnyaRepository(
          secrets: FlutterAnyaSecretStore(),
          plaintextFallback: prefs,
        ),
        planRepairPort: repairPort,
      );
    },
    afterRunApp: () {
      scheduleDeferredStartupTask(
        debugName: 'anya_feature_initialization',
        task: registry.initializeAll,
      );
      scheduleDeferredProBootstrap();
    },
  );
}

/// Builds the Anya shell's module registry. Split out so tests can exercise
/// the exact registration this entrypoint performs.
@visibleForTesting
ModuleRegistry buildAnyaModuleRegistry() {
  return ModuleRegistry(shell: ShellId.anya)..register(AnyaModule());
}

class AiroAnyaApp extends StatefulWidget {
  const AiroAnyaApp({
    super.key,
    required this.registry,
    required this.repository,
    this.planRepairPort = const NoopPlanRepairPort(),
  });

  final ModuleRegistry registry;
  final AnyaRepository repository;
  final PlanRepairPort planRepairPort;

  @override
  State<AiroAnyaApp> createState() => _AiroAnyaAppState();
}

class _AiroAnyaAppState extends State<AiroAnyaApp> {
  late final GoRouter _router = GoRouter(
    initialLocation: '/',
    routes: widget.registry.allRoutes,
  );

  @override
  void dispose() {
    _router.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ProviderScope(
      overrides: [
        ...widget.registry.allProviderOverrides,
        anyaRepositoryProvider.overrideWithValue(widget.repository),
        planRepairPortProvider.overrideWithValue(widget.planRepairPort),
      ],
      child: MaterialApp.router(
        title: 'Anya',
        theme: AiroTheme.defaultDark,
        routerConfig: _router,
        builder: (context, child) => AiroDisplayScale(
          child: AiroDomainTheme(
            domain: AiroDomain.anya,
            child: child ?? const SizedBox.shrink(),
          ),
        ),
      ),
    );
  }
}
