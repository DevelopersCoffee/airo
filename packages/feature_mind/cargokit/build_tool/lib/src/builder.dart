/// This is copied from Cargokit (which is the official way to use it currently)
/// Details: https://fzyzcjy.github.io/flutter_rust_bridge/manual/integrate/builtin

import 'dart:io';

import 'package:collection/collection.dart';
import 'package:logging/logging.dart';
import 'package:path/path.dart' as path;

import 'android_environment.dart';
import 'cargo.dart';
import 'environment.dart';
import 'options.dart';
import 'rustup.dart';
import 'target.dart';
import 'util.dart';

final _log = Logger('builder');

enum BuildConfiguration {
  debug,
  release,
  profile,
}

extension on BuildConfiguration {
  bool get isDebug => this == BuildConfiguration.debug;
  String get rustName => switch (this) {
        BuildConfiguration.debug => 'debug',
        BuildConfiguration.release => 'release',
        BuildConfiguration.profile => 'release',
      };
}

class BuildException implements Exception {
  final String message;

  BuildException(this.message);

  @override
  String toString() {
    return 'BuildException: $message';
  }
}

class BuildEnvironment {
  final BuildConfiguration configuration;
  final CargokitCrateOptions crateOptions;
  final String targetTempDir;
  final String manifestDir;
  final CrateInfo crateInfo;

  final bool isAndroid;
  final String? androidSdkPath;
  final String? androidNdkVersion;
  final int? androidMinSdkVersion;
  final String? javaHome;

  BuildEnvironment({
    required this.configuration,
    required this.crateOptions,
    required this.targetTempDir,
    required this.manifestDir,
    required this.crateInfo,
    required this.isAndroid,
    this.androidSdkPath,
    this.androidNdkVersion,
    this.androidMinSdkVersion,
    this.javaHome,
  });

  static BuildConfiguration parseBuildConfiguration(String value) {
    // XCode configuration adds the flavor to configuration name.
    final firstSegment = value.split('-').first;
    final buildConfiguration = BuildConfiguration.values.firstWhereOrNull(
      (e) => e.name == firstSegment,
    );
    if (buildConfiguration == null) {
      _log.warning('Unknown build configuraiton $value, will assume release');
      return BuildConfiguration.release;
    }
    return buildConfiguration;
  }

  static BuildEnvironment fromEnvironment({
    required bool isAndroid,
  }) {
    final buildConfiguration =
        parseBuildConfiguration(Environment.configuration);
    final manifestDir = Environment.manifestDir;
    final crateOptions = CargokitCrateOptions.load(
      manifestDir: manifestDir,
    );
    final crateInfo = CrateInfo.load(manifestDir);
    return BuildEnvironment(
      configuration: buildConfiguration,
      crateOptions: crateOptions,
      targetTempDir: Environment.targetTempDir,
      manifestDir: manifestDir,
      crateInfo: crateInfo,
      isAndroid: isAndroid,
      androidSdkPath: isAndroid ? Environment.sdkPath : null,
      androidNdkVersion: isAndroid ? Environment.ndkVersion : null,
      androidMinSdkVersion:
          isAndroid ? int.parse(Environment.minSdkVersion) : null,
      javaHome: isAndroid ? Environment.javaHome : null,
    );
  }
}

class RustBuilder {
  final Target target;
  final BuildEnvironment environment;

  RustBuilder({
    required this.target,
    required this.environment,
  });

  void prepare(
    Rustup rustup,
  ) {
    final toolchain = _toolchain;
    if (rustup.installedTargets(toolchain) == null) {
      rustup.installToolchain(toolchain);
    }
    if (toolchain == 'nightly') {
      rustup.installRustSrcForNightly();
    }
    if (!rustup.installedTargets(toolchain)!.contains(target.rust)) {
      rustup.installTarget(target.rust, toolchain: toolchain);
    }
  }

  CargoBuildOptions? get _buildOptions =>
      environment.crateOptions.cargo[environment.configuration];

  String get _toolchain => _buildOptions?.toolchain.name ?? 'stable';

  /// Returns the path of directory containing build artifacts.
  Future<String> build() async {
    final extraArgs = _ecapaArgs(_buildOptions?.flags ?? []);
    final manifestPath = path.join(environment.manifestDir, 'Cargo.toml');
    runCommand(
      'rustup',
      [
        'run',
        _toolchain,
        'cargo',
        'build',
        ...extraArgs,
        '--manifest-path',
        manifestPath,
        '-p',
        environment.crateInfo.packageName,
        if (!environment.configuration.isDebug) '--release',
        '--target',
        target.rust,
        '--target-dir',
        environment.targetTempDir,
      ],
      environment: await _buildEnvironment(),
    );
    return path.join(
      environment.targetTempDir,
      target.rust,
      environment.configuration.rustName,
    );
  }

  Future<Map<String, String>> _buildEnvironment() async {
    Map<String, String> buildEnv = {};
    if (target.android != null) {
      final sdkPath = environment.androidSdkPath;
      final ndkVersion = environment.androidNdkVersion;
      final minSdkVersion = environment.androidMinSdkVersion;
      if (sdkPath == null) {
        throw BuildException('androidSdkPath is not set');
      }
      if (ndkVersion == null) {
        throw BuildException('androidNdkVersion is not set');
      }
      if (minSdkVersion == null) {
        throw BuildException('androidMinSdkVersion is not set');
      }
      final env = AndroidEnvironment(
        sdkPath: sdkPath,
        ndkVersion: ndkVersion,
        minSdkVersion: minSdkVersion,
        targetTempDir: environment.targetTempDir,
        target: target,
      );
      if (!env.ndkIsInstalled() && environment.javaHome != null) {
        env.installNdk(javaHome: environment.javaHome!);
      }
      buildEnv = await env.buildEnvironment();
    }
    final ortLib = _resolveOrtLibLocation();
    if (ortLib != null) {
      buildEnv['ORT_LIB_LOCATION'] = ortLib;
      if (target.android != null) {
        buildEnv['ORT_CXX_STDLIB'] = 'c++_shared';
      }
    }
    final iosXcfwk = _resolveOrtIosXcfwkLocation();
    if (iosXcfwk != null) {
      buildEnv['ORT_IOS_XCFWK_LOCATION'] = iosXcfwk;
    }
    return buildEnv;
  }

  bool _ortAvailableForBuild() =>
      _resolveOrtLibLocation() != null || _resolveOrtIosXcfwkLocation() != null;

  /// When ORT static libs are installed for this target, link ECAPA into whisper.
  List<String> _ecapaArgs(List<String> flags) {
    if (!_ortAvailableForBuild()) {
      return flags;
    }
    if (environment.crateInfo.packageName != 'airo_mind_whisper') {
      return flags;
    }
    final args = List<String>.from(flags);
    final featureIndex = args.indexOf('--features');
    if (featureIndex >= 0 && featureIndex + 1 < args.length) {
      final current = args[featureIndex + 1];
      if (!current.contains('ecapa')) {
        args[featureIndex + 1] = '$current,ecapa,ecapa-bundle';
      }
    }
    return args;
  }

  String? _resolveOrtLibLocation() {
    final fromEnv = Platform.environment['ORT_LIB_LOCATION'];
    if (fromEnv != null && fromEnv.isNotEmpty) {
      final lib = path.join(fromEnv, 'lib', 'libonnxruntime.a');
      if (File(lib).existsSync() && _ortEnvMatchesTarget(fromEnv)) {
        return fromEnv;
      }
    }
    final home = Platform.environment['HOME'];
    if (home == null) return null;

    final candidates = <String>[];
    if (target.android != null) {
      candidates.add(
        path.join(
          home,
          '.airo',
          'onnxruntime',
          '1.20.0',
          'android-arm64',
          'onnxruntime-android-arm64-v8a-static_lib-1.20.0',
        ),
      );
    } else if (target.rust.contains('apple-darwin')) {
      if (target.rust.startsWith('aarch64')) {
        candidates.add(
          path.join(home, '.airo', 'onnxruntime', '1.20.0', 'macos-arm64'),
        );
      } else {
        candidates.add(
          path.join(home, '.airo', 'onnxruntime', '1.20.0', 'macos-x64'),
        );
      }
    } else if (target.rust.contains('linux-gnu')) {
      if (target.rust.startsWith('aarch64')) {
        candidates.add(
          path.join(home, '.airo', 'onnxruntime', '1.20.0', 'linux-arm64'),
        );
      } else {
        candidates.add(
          path.join(home, '.airo', 'onnxruntime', '1.20.0', 'linux-x64'),
        );
      }
    }

    for (final root in candidates) {
      final lib = path.join(root, 'lib', 'libonnxruntime.a');
      if (File(lib).existsSync()) {
        return root;
      }
    }
    return null;
  }

  /// ORT_LIB_LOCATION from install-onnxruntime.sh is host-arch specific; ignore
  /// it when cargokit is building a different macOS slice (e.g. x86_64 on arm64).
  bool _ortEnvMatchesTarget(String ortRoot) {
    if (target.rust.contains('apple-darwin')) {
      if (target.rust.startsWith('aarch64')) {
        return ortRoot.contains('arm64') || ortRoot.contains('aarch64');
      }
      return ortRoot.contains('x64') || ortRoot.contains('x86_64');
    }
    return true;
  }

  String? _resolveOrtIosXcfwkLocation() {
    final fromEnv = Platform.environment['ORT_IOS_XCFWK_LOCATION'];
    if (fromEnv != null && fromEnv.isNotEmpty) {
      return fromEnv;
    }
    if (!target.rust.contains('apple-ios')) {
      return null;
    }
    final home = Platform.environment['HOME'];
    if (home == null) return null;
    final root = path.join(home, '.airo', 'onnxruntime', '1.20.0', 'ios-xcframework');
    if (target.rust == 'aarch64-apple-ios') {
      final fw = path.join(root, 'ios-arm64', 'onnxruntime.framework');
      if (File(fw).existsSync()) return root;
    }
    if (target.rust.contains('apple-ios')) {
      final simFw = path.join(
        root,
        'ios-arm64_x86_64-simulator',
        'onnxruntime.framework',
      );
      if (File(simFw).existsSync()) return root;
    }
    return null;
  }
}
