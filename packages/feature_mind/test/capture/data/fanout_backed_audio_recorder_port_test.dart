import 'package:feature_mind/src/capture/data/audio_recorder_port.dart';
import 'package:feature_mind/src/capture/data/fanout_backed_audio_recorder_port.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('fan-out port never opens a second encoder', () async {
    final port = FanoutBackedAudioRecorderPort(path: '/tmp/meeting-1.wav');
    expect(await port.hasPermission(), isTrue);
    await port.start('/tmp/meeting-1.wav');
    await port.pause();
    await port.resume();
    expect(await port.stop(), '/tmp/meeting-1.wav');
    expect(port.osEvents, isA<Stream<RecorderOsEvent>>());
    await port.dispose();
  });
}
