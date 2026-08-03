import 'package:feature_mind/feature_mind.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('MindPortUnavailable names the port, not just the product', () {
    const failure = MindPortUnavailable('MeshPort', 'peer discovery is #1200');

    expect(failure.port, 'MeshPort');
    expect(failure.toString(), contains('MeshPort'));
    expect(failure.toString(), contains('#1200'));
  });

  test('MindRuntime exposes exactly the eight sub-ports', () {
    // A ninth port is an architecture change, not an implementation detail:
    // the freeze permits new capabilities, not new runtime surfaces.
    const expected = {
      'vault',
      'log',
      'contexts',
      'projections',
      'mesh',
      'capabilities',
      'models',
      'portability',
    };

    expect(MindRuntime.portNames, equals(expected));
  });
}
