import 'package:airo_app/features/meeting/domain/entities/meeting_record.dart';
import 'package:airo_app/features/meeting/domain/entities/meeting_segment.dart';
import 'package:airo_app/features/meeting/domain/entities/transcript_chunk.dart';
import 'package:airo_app/features/meeting/infrastructure/platform/native_meeting_contracts.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const recorderChannel = MethodChannel(meetingRecorderChannelName);
  const transcriptionChannel = MethodChannel(meetingTranscriptionChannelName);

  tearDown(() async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(recorderChannel, null);
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(transcriptionChannel, null);
  });

  group('NativeMeetingRecorderContract', () {
    test('sends a strict typed payload when starting a recording', () async {
      late MethodCall capturedCall;
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(recorderChannel, (call) async {
            capturedCall = call;
            return null;
          });

      final contract = NativeMeetingRecorderContract(channel: recorderChannel);
      await contract.startRecording(
        meeting: MeetingRecord.started(
          id: 'meeting-239',
          title: 'Live Notes foundation',
          startedAt: DateTime.utc(2026, 6, 27, 5, 0),
          languageCode: 'en-IN',
        ),
      );

      expect(capturedCall.method, 'startMeeting');
      expect(capturedCall.arguments, {
        'meetingId': 'meeting-239',
        'title': 'Live Notes foundation',
        'startedAt': '2026-06-27T05:00:00.000Z',
        'languageCode': 'en-IN',
      });
    });

    test('parses strict typed audio metadata from stop responses', () async {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(recorderChannel, (call) async {
            expect(call.method, 'stopMeeting');
            return {
              'meetingId': 'meeting-239',
              'filePath': '/tmp/meeting-239.wav',
              'codec': 'wav',
              'sampleRateHz': 16000,
              'channelCount': 1,
              'sizeBytes': 4096,
              'sha256': 'abc123',
            };
          });

      final contract = NativeMeetingRecorderContract(channel: recorderChannel);
      final metadata = await contract.stopRecording(meetingId: 'meeting-239');

      expect(metadata.meetingId, 'meeting-239');
      expect(metadata.filePath, '/tmp/meeting-239.wav');
      expect(metadata.sampleRateHz, 16000);
    });

    test('rejects malformed recorder payloads deterministically', () async {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(recorderChannel, (_) async {
            return {
              'filePath': '/tmp/meeting-239.wav',
              'codec': 'wav',
              'sampleRateHz': '16000',
              'channelCount': 1,
              'sizeBytes': 4096,
              'sha256': 'abc123',
            };
          });

      final contract = NativeMeetingRecorderContract(channel: recorderChannel);

      await expectLater(
        () => contract.stopRecording(meetingId: 'meeting-239'),
        throwsA(isA<FormatException>()),
      );
    });
  });

  group('NativeMeetingTranscriptionContract', () {
    test('sends strict start args to the transcription channel', () async {
      late MethodCall capturedCall;
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(transcriptionChannel, (call) async {
            capturedCall = call;
            return null;
          });

      final contract = NativeMeetingTranscriptionContract(
        channel: transcriptionChannel,
      );
      await contract.startRealtimeTranscription(
        meetingId: 'meeting-239',
        languageCode: 'en-IN',
      );

      expect(capturedCall.method, 'startRealtimeTranscription');
      expect(capturedCall.arguments, {
        'meetingId': 'meeting-239',
        'languageCode': 'en-IN',
      });
    });

    test('parses transcript events into strict typed chunks', () async {
      final contract = NativeMeetingTranscriptionContract(
        channel: transcriptionChannel,
        eventStreamFactory: (_) => Stream<Object?>.value({
          'id': 'chunk-1',
          'meetingId': 'meeting-239',
          'text': 'Action: ship strict contracts.',
          'startMs': 0,
          'endMs': 1200,
          'isFinal': true,
          'confidence': 0.98,
        }),
      );

      final chunk = await contract.transcriptEvents().single;
      final segment = MeetingSegment.fromTranscriptChunk(chunk);

      expect(chunk.meetingId, 'meeting-239');
      expect(chunk.isFinal, true);
      expect(
        segment.toTranscriptChunk().text,
        'Action: ship strict contracts.',
      );
    });

    test('rejects malformed transcript events deterministically', () async {
      final contract = NativeMeetingTranscriptionContract(
        channel: transcriptionChannel,
        eventStreamFactory: (_) => Stream<Object?>.value({
          'id': 'chunk-1',
          'meetingId': 'meeting-239',
          'text': 'Action: ship strict contracts.',
          'startMs': '0',
          'endMs': 1200,
          'isFinal': true,
        }),
      );

      await expectLater(
        contract.transcriptEvents(),
        emitsError(isA<FormatException>()),
      );
    });
  });

  test('MeetingSegment round-trips with TranscriptChunk', () {
    const chunk = TranscriptChunk.partial(
      id: 'chunk-2',
      meetingId: 'meeting-239',
      text: 'Partial transcript',
      startMs: 10,
      endMs: 40,
      speakerLabel: 'Speaker 1',
      confidence: 0.8,
    );

    final segment = MeetingSegment.fromTranscriptChunk(chunk);

    expect(segment.meetingId, chunk.meetingId);
    expect(segment.toTranscriptChunk().speakerLabel, 'Speaker 1');
    expect(segment.toTranscriptChunk().confidence, 0.8);
  });
}
