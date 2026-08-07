import 'package:core_ai/core_ai.dart';
import 'package:core_product_shell/core_product_shell.dart';
import 'package:feature_mind/feature_mind.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:go_router/go_router.dart';

import 'mind_model_catalog.dart';
import 'mind_model_sources.dart';

/// Wraps the `feature_mind` scribe journey — record a meeting, transcribe it,
/// read the minutes, search what was said — as a shell-registrable module,
/// the same way `CoinVaultModule` wraps `feature_coin`.
///
/// `feature_mind` itself is untouched: it exposes a screen and a service, and
/// this module is the only thing that knows they compose into a shell route.
///
/// The module owns the [MindService] lifecycle because the service holds the
/// loaded models and the microphone, neither of which survives being
/// recreated on a widget rebuild. The service is created lazily rather than in
/// the constructor: [ModuleRegistry.initializeAll] runs after the first frame,
/// so the route builder can legitimately need the service before
/// [initialize] has been awaited.
///
/// Loading the models is *not* this module's job — [MindHomeScreen] calls
/// `MindService.initialize()` itself and renders the resulting status
/// (models missing, bridge missing, ready) as its opening state.
///
/// Choosing *where the models come from* is, though, and it is this module
/// alone: [buildMindDownloadService] composes the service over `core_ai`'s
/// download pipeline with the shell's pinned URLs. `MindService`'s own default
/// is the bundled-asset installer, and this app ships no bundled weights — so
/// before this wiring existed a fresh install had no path to a working app
/// (#1554).
class MindScribeModule extends AppModule {
  MindScribeModule({MindService Function()? createService})
    : this._(createService);

  MindScribeModule._(this._createService);

  /// Null means the production composition, which also hands back the
  /// download service so [dispose] can close it. A test-supplied builder
  /// brings its own collaborators and has nothing here to tear down.
  final MindService Function()? _createService;

  MindService? _service;
  ModelDownloadService? _downloadService;

  /// The scribe's service, created on first use and torn down by [dispose].
  MindService get service => _service ??=
      _createService?.call() ??
      buildMindDownloadService(onDownloadService: (s) => _downloadService = s);

  /// The registry id, named so the shell can ask for this module's routes by
  /// constant rather than by a literal that drifts.
  static const String moduleId = 'mind_scribe';

  @override
  String get id => moduleId;

  /// The standalone Airo Mind shell only. The super app reaches the scribe
  /// through the assistant hub's audio-scribe screen instead, and the TV
  /// shell has no microphone journey at all.
  @override
  Set<ShellId> get supportedShells => {ShellId.mind};

  @override
  Future<void> initialize() async {
    // Touching the getter is the initialization: it builds the recorder and
    // the installer so the first tap on Record is not also the first time the
    // platform channel is opened.
    service;
  }

  @override
  Future<void> dispose() async {
    await _service?.dispose();
    _service = null;
    // The download service holds a live subscription to the platform download
    // stream and a controller per model; the provider that owns it is not
    // reachable from here, so the composition root kept the handle.
    await _downloadService?.dispose();
    _downloadService = null;
  }

  /// Puts the scribe's weights in the shell's shared model explorer.
  ///
  /// Without this the Mind shell's Profile → AI preferences screen listed the
  /// super app's chat models and said nothing about the two models this app
  /// actually runs on. The override reads install state from [service]'s own
  /// models directory, so the screen reports what is really on disk rather
  /// than what the download service would have installed elsewhere.
  @override
  List<Override> providerOverridesFor(ShellId shell) =>
      mindModelRegistryOverrides(
        modelsDirectory: () => service.modelsDirectory(),
      );

  /// The scribe is the Mind shell's home, so it mounts at the root.
  @override
  List<RouteBase> routesFor(ShellId shell) => [
    GoRoute(
      path: '/',
      name: 'mind_scribe',
      builder: (context, state) => MindHomeScreen(service: service),
    ),
  ];
}
