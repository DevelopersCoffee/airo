import 'package:core_ai/src/device/desktop_memory_probe.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('formats macOS df output as free / total storage', () {
    const stdout = '''
Filesystem     1024-blocks      Used Available Capacity iused      ifree %iused  Mounted on
/dev/disk3s1s1   239787536  11123456  45678901    20%  456789  234567890    0%   /
''';
    expect(formatStorageSummaryFromDf(stdout), '43.6 GB free of 228.7 GB');
  });

  test('formats CPU brand with core count', () {
    expect(
      formatDesktopCpuSummary(
        brand: 'Apple M4 Pro',
        ncpu: '12',
        appleSilicon: true,
      ),
      'Apple M4 Pro · 12 cores',
    );
  });

  test('reads Linux model name from cpuinfo', () {
    expect(
      parseLinuxCpuBrand('processor\t: 0\nmodel name\t: Intel(R) Core(TM)\n'),
      'Intel(R) Core(TM)',
    );
  });
}
