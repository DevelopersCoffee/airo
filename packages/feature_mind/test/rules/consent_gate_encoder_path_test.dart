import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// #1459: no code path reaches the encoder without passing the consent gate.
///
/// Mirrors `r05_private_devices_test.dart`: a static gate script backed by a
/// mutation test that proves the check CAN fail, not just that it currently
/// passes. The gate asserts every call to `VoiceSearchService.startListening()`
/// under `packages/feature_mind/lib/src/assistant` -- the encoder entry point
/// Audio Scribe uses -- is wrapped by
/// `AudioScribeConsentGate.startRecording()`, the one method allowed to
/// invoke it.
void main() {
  late Directory root;
  late String gate;
  late File screen;

  setUp(() {
    root = Directory.current.parent.parent;
    gate = '${root.path}/scripts/check-mind-consent-gate.sh';
    screen = File(
      '${root.path}/packages/feature_mind/lib/src/assistant/presentation/'
      'screens/audio_scribe_screen.dart',
    );
  });

  test('the gate passes the current tree', () {
    final result = Process.runSync(gate, const []);

    expect(result.exitCode, 0, reason: result.stderr.toString());
  });

  test('the gate fails when a screen calls startListening() directly, '
      'bypassing the consent gate', () {
    final original = screen.readAsStringSync();

    // A direct call to the voice service, exactly the shape the real
    // encoder call in _capture() takes minus the gate wrapper. If the
    // static scan only matched the known-good line, this mutation would
    // slip through -- proving the check can fail is the point.
    final mutated = original.replaceFirst(
      '  Future<void> _capture() async {',
      '  Future<void> _capture() async {\n'
          '    // consent-gate mutation probe\n'
          '    // ignore: unused_local_variable\n'
          '    final bypass = ref.read(voiceSearchServiceProvider).startListening();\n',
    );
    expect(
      mutated,
      isNot(equals(original)),
      reason: 'the mutation must actually change the file',
    );
    screen.writeAsStringSync(mutated);

    try {
      final result = Process.runSync(gate, const []);
      expect(
        result.exitCode,
        isNonZero,
        reason:
            'The gate let a direct startListening() call through. That is '
            'a path to the microphone encoder that never checked consent.',
      );
      expect(result.stderr.toString(), contains('Consent gate violation'));
    } finally {
      screen.writeAsStringSync(original);
    }
  });

  test('the gate refuses to run when the guarded call site disappears '
      'entirely', () {
    // Not a bypass, but not verifiable either: if nothing routes
    // startListening() through startRecording() any more, the gate must
    // say it cannot confirm the guarded path is used rather than report a
    // clean tree it never actually checked.
    final original = screen.readAsStringSync();
    final mutated = original.replaceFirst(
      'result = await _consentGate.startRecording(\n'
          '        () => service.startListening(),\n'
          '      );',
      'result = await Future<VoiceSearchResult>.value(VoiceSearchResult.empty());',
    );
    expect(mutated, isNot(equals(original)));
    screen.writeAsStringSync(mutated);

    try {
      final result = Process.runSync(gate, const []);
      expect(result.exitCode, 127, reason: result.stdout.toString());
    } finally {
      screen.writeAsStringSync(original);
    }
  });

  test('the gate fails when startRecording() itself is deleted', () {
    final gateFile = File(
      '${root.path}/packages/feature_mind/lib/src/assistant/consent/'
      'audio_scribe_consent_gate.dart',
    );
    final original = gateFile.readAsStringSync();
    final mutated = original.replaceFirst(
      'Future<T> startRecording<T>(',
      'Future<T> _renamedStartRecording<T>(',
    );
    expect(mutated, isNot(equals(original)));
    gateFile.writeAsStringSync(mutated);

    try {
      final result = Process.runSync(gate, const []);
      expect(result.exitCode, 127, reason: result.stdout.toString());
    } finally {
      gateFile.writeAsStringSync(original);
    }
  });
}
