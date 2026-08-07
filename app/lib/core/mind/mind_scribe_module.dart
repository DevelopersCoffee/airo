import 'package:core_product_shell/core_product_shell.dart';
import 'package:feature_mind/feature_mind.dart';
import 'package:go_router/go_router.dart';

import 'mind_model_source.dart';

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
class MindScribeModule extends AppModule {
  MindScribeModule({MindService Function()? createService})
    : _createService = createService ?? _defaultService;

  /// The shell's actual default: models come from Airo's existing download
  /// pipeline, not the app bundle — neither this shell nor the super app
  /// ships model weights in the APK
  /// (`docs/superpowers/specs/2026-08-07-airo-mind-abstraction-layer.md`).
  static MindService _defaultService() =>
      MindService(modelProvider: buildMindModelProvider());

  final MindService Function() _createService;

  MindService? _service;

  /// The scribe's service, created on first use and torn down by [dispose].
  MindService get service => _service ??= _createService();

  @override
  String get id => 'mind_scribe';

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
  }

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
