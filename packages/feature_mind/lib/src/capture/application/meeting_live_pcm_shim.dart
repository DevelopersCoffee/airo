import 'dart:async';
import 'dart:math' show sqrt;
import 'dart:typed_data';

import 'package:record/record.dart';

import '../../whisper/api/meetings.dart' as rust;
import 'live_pcm_shim_port.dart';

/// Interim desktop shim: `record.startStream` → `push_live_pcm`.
///
/// Documented violation of ZC-1 in `LIVE_CAPTURE_FAN_OUT.md` §Interim shim.
/// Uses a second [AudioRecorder] beside the file encoder until native fan-out
/// lands on this platform.
class MeetingLivePcmShim implements LivePcmShimPort {
  MeetingLivePcmShim({AudioRecorder? streamRecorder})
    : _recorder = streamRecorder ?? AudioRecorder();

  final AudioRecorder _recorder;
  StreamSubscription<Uint8List>? _subscription;
  bool _paused = false;

  @override
  void Function(double normalizedRms)? onAmplitude;

  static const _streamConfig = RecordConfig(
    encoder: AudioEncoder.pcm16bits,
    sampleRate: 16000,
    numChannels: 1,
  );

  @override
  Future<void> start({required String sessionId}) async {
    _paused = false;
    final stream = await _recorder.startStream(_streamConfig);
    _subscription = stream.listen((chunk) => _onChunk(sessionId, chunk));
  }

  @override
  Future<void> pause() async {
    _paused = true;
    await _subscription?.cancel();
    _subscription = null;
    await _recorder.stop();
  }

  @override
  Future<void> resume({required String sessionId}) async {
    if (!_paused) return;
    await start(sessionId: sessionId);
  }

  @override
  Future<void> stop() async {
    _paused = false;
    await _subscription?.cancel();
    _subscription = null;
    await _recorder.stop();
  }

  @override
  Future<void> dispose() => _recorder.dispose();

  void _onChunk(String sessionId, Uint8List chunk) {
    if (_paused || chunk.isEmpty) return;
    final samples = _bytesToInt16(chunk);
    final rms = _rmsEnergy(samples);
    onAmplitude?.call(_normalizeRms(rms));
    rust.pushLivePcm(sessionId: sessionId, samples: samples);
  }

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
