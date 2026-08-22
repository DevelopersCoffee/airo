import 'dart:async';
import 'dart:math' show sqrt;
import 'dart:typed_data';

import 'package:record/record.dart';

import '../../whisper/api/meetings.dart' as rust;

/// Interim desktop shim: `record.startStream` → `push_live_pcm`.
///
/// Documented violation of ZC-1 in `LIVE_CAPTURE_FAN_OUT.md` §Interim shim.
/// Uses a second [AudioRecorder] beside the file encoder until native fan-out
/// lands on this platform.
class MeetingLivePcmShim {
  MeetingLivePcmShim({AudioRecorder? streamRecorder})
    : _recorder = streamRecorder ?? AudioRecorder();

  final AudioRecorder _recorder;
  StreamSubscription<Uint8List>? _subscription;

  /// Normalized RMS (0–1) for the live amplitude meter — not speaker identity.
  void Function(double normalizedRms)? onAmplitude;

  static const _streamConfig = RecordConfig(
    encoder: AudioEncoder.pcm16bits,
    sampleRate: 16000,
    numChannels: 1,
  );

  Future<void> start({required String sessionId}) async {
    final stream = await _recorder.startStream(_streamConfig);
    _subscription = stream.listen((chunk) {
      if (chunk.isEmpty) return;
      final samples = _bytesToInt16(chunk);
      final rms = _rmsEnergy(samples);
      onAmplitude?.call(_normalizeRms(rms));
      rust.pushLivePcm(sessionId: sessionId, samples: samples);
    });
  }

  Future<void> stop() async {
    await _subscription?.cancel();
    _subscription = null;
    await _recorder.stop();
  }

  Future<void> dispose() => _recorder.dispose();

  List<int> _bytesToInt16(Uint8List bytes) {
    final aligned = bytes.length.isEven ? bytes : bytes.sublist(0, bytes.length - 1);
    final view = ByteData.sublistView(aligned);
    final count = aligned.length ~/ 2;
    final out = List<int>.filled(count, 0);
    for (var i = 0; i < count; i++) {
      out[i] = view.getInt16(i * 2, Endian.little);
    }
    return out;
  }

  double _rmsEnergy(List<int> samples) {
    if (samples.isEmpty) return 0;
    var sum = 0.0;
    for (final sample in samples) {
      final v = sample / 32768.0;
      sum += v * v;
    }
    return sqrt(sum / samples.length);
  }

  /// Maps typical speech RMS (~0.01–0.15) into 0–1 for the meter.
  double _normalizeRms(double rms) => (rms / 0.15).clamp(0.0, 1.0);
}
