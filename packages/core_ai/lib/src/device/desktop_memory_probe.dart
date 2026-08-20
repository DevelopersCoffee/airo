import 'dart:io';

import 'package:meta/meta.dart';

import 'memory_severity.dart';

/// Best-effort host RAM probe for desktop shells without the Android AICore
/// channel (`com.airo.gemini_nano`).
Future<MemoryInfo?> probeDesktopMemory() async {
  if (Platform.isMacOS) {
    return _probeMacOSMemory();
  }
  if (Platform.isLinux) {
    return _probeLinuxMemory();
  }
  return null;
}

/// CPU / GPU / storage facts for the Device Capability Report on desktop.
Future<DesktopHostFacts?> probeDesktopHostFacts() async {
  if (Platform.isMacOS) {
    return _probeMacOSHostFacts();
  }
  if (Platform.isLinux) {
    return _probeLinuxHostFacts();
  }
  return null;
}

class DesktopHostFacts {
  const DesktopHostFacts({
    this.model,
    this.osVersion,
    this.cpuSummary,
    this.gpuSummary,
    this.npuSummary,
    this.storageSummary,
    this.thermalSummary,
  });

  final String? model;
  final String? osVersion;
  final String? cpuSummary;
  final String? gpuSummary;
  final String? npuSummary;
  final String? storageSummary;
  final String? thermalSummary;
}

Future<MemoryInfo?> _probeMacOSMemory() async {
  try {
    final totalResult = await Process.run('sysctl', ['-n', 'hw.memsize']);
    if (totalResult.exitCode != 0) return null;
    final totalBytes = int.tryParse('${totalResult.stdout}'.trim());
    if (totalBytes == null || totalBytes <= 0) return null;

    final pageSizeResult = await Process.run('sysctl', ['-n', 'hw.pagesize']);
    final pageSize = int.tryParse('${pageSizeResult.stdout}'.trim()) ?? 4096;

    final vmStat = await Process.run('vm_stat', const []);
    if (vmStat.exitCode != 0) {
      return MemoryInfo(
        totalBytes: totalBytes,
        availableBytes: totalBytes ~/ 2,
      );
    }

    var freePages = 0;
    var inactivePages = 0;
    for (final line in '${vmStat.stdout}'.split('\n')) {
      final match = RegExp(r'^Pages\s+([^:]+):\s+(\d+)\.').firstMatch(line);
      if (match == null) continue;
      final count = int.tryParse(match.group(2) ?? '') ?? 0;
      switch (match.group(1)?.trim()) {
        case 'free':
          freePages = count;
        case 'inactive':
          inactivePages = count;
      }
    }

    final availableBytes = (freePages + inactivePages) * pageSize;
    return MemoryInfo(
      totalBytes: totalBytes,
      availableBytes: availableBytes.clamp(0, totalBytes),
    );
  } catch (_) {
    return null;
  }
}

Future<DesktopHostFacts?> _probeMacOSHostFacts() async {
  try {
    final results = await Future.wait([
      _runCapture('sysctl', ['-n', 'machdep.cpu.brand_string']),
      _runCapture('sysctl', ['-n', 'hw.ncpu']),
      _runCapture('sysctl', ['-n', 'hw.model']),
      _runCapture('sysctl', ['-n', 'hw.optional.arm64']),
      _runCapture('sw_vers', ['-productVersion']),
      _runCapture('df', ['-k', '/']),
    ]);
    final cpuBrand = results[0];
    final ncpu = results[1];
    final hwModel = results[2];
    final arm64 = results[3] == '1';
    final osVersion = results[4];
    final appleSilicon = arm64 || cpuBrand.toLowerCase().contains('apple');
    return DesktopHostFacts(
      model: hwModel.isEmpty ? 'Mac' : hwModel,
      osVersion: osVersion.isEmpty ? null : osVersion,
      cpuSummary: formatDesktopCpuSummary(
        brand: cpuBrand,
        ncpu: ncpu,
        appleSilicon: appleSilicon,
      ),
      gpuSummary: appleSilicon
          ? 'Apple silicon GPU (Metal)'
          : 'Integrated GPU (Metal)',
      npuSummary: appleSilicon ? 'Apple Neural Engine' : 'None reported',
      storageSummary: formatStorageSummaryFromDf(results[5]),
      thermalSummary: 'Desktop adapter does not expose live thermal zones',
    );
  } catch (_) {
    return null;
  }
}

Future<DesktopHostFacts?> _probeLinuxHostFacts() async {
  try {
    String cpuBrand = '';
    try {
      cpuBrand = parseLinuxCpuBrand(await File('/proc/cpuinfo').readAsString());
    } catch (_) {}
    final ncpu = Platform.numberOfProcessors.toString();
    final df = await _runCapture('df', ['-k', '/']);
    return DesktopHostFacts(
      model: 'Linux desktop',
      osVersion: Platform.operatingSystemVersion,
      cpuSummary: formatDesktopCpuSummary(
        brand: cpuBrand,
        ncpu: ncpu,
        appleSilicon: false,
      ),
      gpuSummary: 'Not probed on this desktop adapter',
      npuSummary: 'None reported',
      storageSummary: formatStorageSummaryFromDf(df),
      thermalSummary: 'Desktop adapter does not expose live thermal zones',
    );
  } catch (_) {
    return null;
  }
}

Future<String> _runCapture(String executable, List<String> arguments) async {
  final result = await Process.run(executable, arguments);
  if (result.exitCode != 0) return '';
  return '${result.stdout}'.trim();
}

Future<MemoryInfo?> _probeLinuxMemory() async {
  try {
    final memInfo = await File('/proc/meminfo').readAsString();
    int? totalKb;
    int? availableKb;
    for (final line in memInfo.split('\n')) {
      if (line.startsWith('MemTotal:')) {
        totalKb = int.tryParse(line.split(RegExp(r'\s+')).elementAt(1));
      } else if (line.startsWith('MemAvailable:')) {
        availableKb = int.tryParse(line.split(RegExp(r'\s+')).elementAt(1));
      }
    }
    if (totalKb == null) return null;
    return MemoryInfo(
      totalBytes: totalKb * 1024,
      availableBytes: (availableKb ?? totalKb ~/ 2) * 1024,
    );
  } catch (_) {
    return null;
  }
}

@visibleForTesting
String formatDesktopCpuSummary({
  required String brand,
  required String ncpu,
  required bool appleSilicon,
}) {
  final cores = int.tryParse(ncpu.trim());
  final coreLabel = cores == null
      ? null
      : '$cores ${cores == 1 ? 'core' : 'cores'}';
  final chip = brand.trim().isEmpty
      ? (appleSilicon ? 'Apple silicon' : 'CPU')
      : brand.trim();
  if (coreLabel == null) return chip;
  return '$chip · $coreLabel';
}

@visibleForTesting
String parseLinuxCpuBrand(String cpuInfo) {
  for (final line in cpuInfo.split('\n')) {
    if (line.toLowerCase().startsWith('model name')) {
      final parts = line.split(':');
      if (parts.length >= 2) return parts.sublist(1).join(':').trim();
    }
  }
  return '';
}

@visibleForTesting
String? formatStorageSummaryFromDf(String stdout) {
  final lines = stdout
      .trim()
      .split('\n')
      .where((line) => line.trim().isNotEmpty)
      .toList();
  if (lines.length < 2) return null;
  var dataLine = lines.last.trim();
  var fields = dataLine.split(RegExp(r'\s+'));
  if (fields.length < 4 && lines.length >= 3) {
    dataLine = '${lines[lines.length - 2]} ${lines.last}'.trim();
    fields = dataLine.split(RegExp(r'\s+'));
  }
  if (fields.length < 4) return null;
  final totalKb = int.tryParse(fields[1]);
  final availableKb = int.tryParse(fields[3]);
  if (totalKb == null || availableKb == null) return null;
  return '${_formatGib(availableKb * 1024)} free of ${_formatGib(totalKb * 1024)}';
}

String _formatGib(int bytes) {
  final gib = bytes / (1024 * 1024 * 1024);
  return '${gib.toStringAsFixed(1)} GB';
}
