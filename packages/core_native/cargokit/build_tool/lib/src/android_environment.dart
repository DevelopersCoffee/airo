/// This is copied from Cargokit (which is the official way to use it currently)
/// Details: https://fzyzcjy.github.io/flutter_rust_bridge/manual/integrate/builtin

import 'dart:io';
import 'dart:isolate';
import 'dart:math' as math;

import 'package:collection/collection.dart';
import 'package:path/path.dart' as path;
import 'package:version/version.dart';

import 'target.dart';
import 'util.dart';

class AndroidEnvironment {
  AndroidEnvironment({
    required this.sdkPath,
    required this.ndkVersion,
    required this.minSdkVersion,
    required this.targetTempDir,
    required this.target,
  });

  static void clangLinkerWrapper(List<String> args) {
    final clang = Platform.environment['_CARGOKIT_NDK_LINK_CLANG'];
    if (clang == null) {
      throw Exception(
          "cargo-ndk rustc linker: didn't find _CARGOKIT_NDK_LINK_CLANG env var");
    }
    final target = Platform.environment['_CARGOKIT_NDK_LINK_TARGET'];
    if (target == null) {
      throw Exception(
          "cargo-ndk rustc linker: didn't find _CARGOKIT_NDK_LINK_TARGET env var");
    }

    runCommand(clang, [
      target,
      ...args,
    ]);
  }

  /// Full path to Android SDK.
  final String sdkPath;

  /// Full version of Android NDK.
  final String ndkVersion;

  /// Minimum supported SDK version.
  final int minSdkVersion;

  /// Target directory for build artifacts.
  final String targetTempDir;

  /// Target being built.
  final Target target;

  bool ndkIsInstalled() {
    final ndkPath = path.join(sdkPath, 'ndk', ndkVersion);
    final ndkPackageXml = File(path.join(ndkPath, 'package.xml'));
    return ndkPackageXml.existsSync();
  }

  void installNdk({
    required String javaHome,
  }) {
    final sdkManagerExtension = Platform.isWindows ? '.bat' : '';
    final sdkManager = path.join(
      sdkPath,
      'cmdline-tools',
      'latest',
      'bin',
      'sdkmanager$sdkManagerExtension',
    );

    log.info('Installing NDK $ndkVersion');
    runCommand(sdkManager, [
      '--install',
      'ndk;$ndkVersion',
    ], environment: {
      'JAVA_HOME': javaHome,
    });
  }

  Future<Map<String, String>> buildEnvironment() async {
    final hostArch = Platform.isMacOS
        ? "darwin-x86_64"
        : (Platform.isLinux ? "linux-x86_64" : "windows-x86_64");

    final ndkPath = path.join(sdkPath, 'ndk', ndkVersion);
    final toolchainPath = path.join(
      ndkPath,
      'toolchains',
      'llvm',
      'prebuilt',
      hostArch,
      'bin',
    );

    final minSdkVersion =
        math.max(target.androidMinSdkVersion!, this.minSdkVersion);

    final exe = Platform.isWindows ? '.exe' : '';

    final arKey = 'AR_${target.rust}';
    final arValue = ['${target.rust}-ar', 'llvm-ar', 'llvm-ar.exe']
        .map((e) => path.join(toolchainPath, e))
        .firstWhereOrNull((element) => File(element).existsSync());
    if (arValue == null) {
      throw Exception('Failed to find ar for $target in $toolchainPath');
    }

    final targetArg = '--target=${target.rust}$minSdkVersion';

    final ccKey = 'CC_${target.rust}';
    final ccValue = path.join(toolchainPath, 'clang$exe');
    final cfFlagsKey = 'CFLAGS_${target.rust}';
    final cFlagsValue = targetArg;

    final cxxKey = 'CXX_${target.rust}';
    final cxxValue = path.join(toolchainPath, 'clang++$exe');
    final cxxFlagsKey = 'CXXFLAGS_${target.rust}';
    final cxxFlagsValue = targetArg;

    final linkerKey =
        'cargo_target_${target.rust.replaceAll('-', '_')}_linker'.toUpperCase();

    final ranlibKey = 'RANLIB_${target.rust}';
    final ranlibValue = path.join(toolchainPath, 'llvm-ranlib$exe');

    final ndkVersionParsed = Version.parse(ndkVersion);
    final rustFlagsKey = 'CARGO_ENCODED_RUSTFLAGS';
    var rustFlagsValue = _libGccWorkaround(targetTempDir, ndkVersionParsed);
    rustFlagsValue = _ggmlBlasWorkaround(targetTempDir, rustFlagsValue);

    final runRustTool =
        Platform.isWindows ? 'run_build_tool.cmd' : 'run_build_tool.sh';

    final packagePath = (await Isolate.resolvePackageUri(
            Uri.parse('package:build_tool/buildtool.dart')))!
        .toFilePath();
    final selfPath = path.canonicalize(path.join(
      packagePath,
      '..',
      '..',
      '..',
      runRustTool,
    ));

    // Make sure that run_build_tool is working properly even initially launched directly
    // through dart run.
    final toolTempDir =
        Platform.environment['CARGOKIT_TOOL_TEMP_DIR'] ?? targetTempDir;

    return {
      arKey: arValue,
      ccKey: ccValue,
      cfFlagsKey: cFlagsValue,
      cxxKey: cxxValue,
      cxxFlagsKey: cxxFlagsValue,
      ranlibKey: ranlibValue,
      rustFlagsKey: rustFlagsValue,
      linkerKey: selfPath,
      // llama-cpp-sys-2's build script locates the NDK itself rather than
      // using CC/CXX, and aborts with "Android NDK not found. Please set one
      // of: ANDROID_NDK, NDK_ROOT, ANDROID_NDK_ROOT" when none is set.
      // Cargokit knows the exact NDK it resolved, so it passes it on rather
      // than leaving each -sys crate to guess. Every host is affected,
      // including CI.
      'ANDROID_NDK': ndkPath,
      'ANDROID_NDK_ROOT': ndkPath,
      'NDK_ROOT': ndkPath,
      // Recognized by main() so we know when we're acting as a wrapper
      '_CARGOKIT_NDK_LINK_TARGET': targetArg,
      '_CARGOKIT_NDK_LINK_CLANG': ccValue,
      'CARGOKIT_TOOL_TEMP_DIR': toolTempDir,
    };
  }

  /// Workaround for an upstream bug in `whisper-rs-sys` 0.15.0.
  ///
  /// Its `build.rs` decides whether whisper.cpp was built with a BLAS backend
  /// using `cfg!(target_os = "macos")`. A build script is compiled for the
  /// HOST, so on a Mac that is true no matter what the *target* is, and the
  /// crate emits `cargo:rustc-link-lib=static=ggml-blas` for an Android build.
  /// CMake never produced that library -- `CMakeCache.txt` from the same build
  /// records `GGML_BLAS:BOOL=OFF` -- so the link fails with:
  ///
  ///     error: could not find native static library `ggml-blas`
  ///
  /// The same file gets it right elsewhere (`target.contains("apple")`), so
  /// this is an inconsistency rather than a deliberate choice. 0.15.0 is the
  /// latest release; there is no fixed version to move to.
  ///
  /// rustc resolves `-l static=` while *compiling the rlib*, not at final
  /// link, so a `cargo:rustc-link-search` from a dependent crate is too late.
  /// It has to arrive as a rustflag, which is also why this cannot live in
  /// `.cargo/config.toml`: cargokit sets `CARGO_ENCODED_RUSTFLAGS`, and that
  /// env var makes cargo ignore the config's `rustflags` entirely.
  ///
  /// An empty archive is a correct stand-in, not a lie: with BLAS off nothing
  /// in whisper.cpp references a `ggml_backend_blas_*` symbol, so there is
  /// nothing for the archive to provide. Same shape as the libgcc workaround
  /// below, which fabricates a `libgcc.a` for a library NDK 23+ dropped.
  ///
  /// Linux and Windows hosts never see the bad flag, so they never get the
  /// stub -- gating on the host keeps this from masking a genuine missing
  /// BLAS build on a platform that really did ask for one.
  String _ggmlBlasWorkaround(String buildDir, String rustFlags) {
    if (!Platform.isMacOS) {
      return rustFlags;
    }
    final workaroundDir = path.join(buildDir, 'cargokit', 'ggml_blas_stub');
    Directory(workaroundDir).createSync(recursive: true);
    // The 8-byte header of an archive with no members. `ar` writes exactly
    // this for an empty archive, and both ld.lld and rustc accept it.
    File(path.join(workaroundDir, 'libggml-blas.a'))
        .writeAsStringSync('!<arch>\n');
    return '$rustFlags\x1f-L\x1f$workaroundDir';
  }

  // Workaround for libgcc missing in NDK23, inspired by cargo-ndk
  String _libGccWorkaround(String buildDir, Version ndkVersion) {
    final workaroundDir = path.join(
      buildDir,
      'cargokit',
      'libgcc_workaround',
      '${ndkVersion.major}',
    );
    Directory(workaroundDir).createSync(recursive: true);
    if (ndkVersion.major >= 23) {
      File(path.join(workaroundDir, 'libgcc.a'))
          .writeAsStringSync('INPUT(-lunwind)');
    } else {
      // Other way around, untested, forward libgcc.a from libunwind once Rust
      // gets updated for NDK23+.
      File(path.join(workaroundDir, 'libunwind.a'))
          .writeAsStringSync('INPUT(-lgcc)');
    }

    var rustFlags = Platform.environment['CARGO_ENCODED_RUSTFLAGS'] ?? '';
    if (rustFlags.isNotEmpty) {
      rustFlags = '$rustFlags\x1f';
    }
    rustFlags = '$rustFlags-L\x1f$workaroundDir';
    return rustFlags;
  }
}
