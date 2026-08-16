import 'dart:io';

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
