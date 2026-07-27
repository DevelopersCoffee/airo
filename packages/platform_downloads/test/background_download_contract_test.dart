import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:platform_downloads/platform_downloads.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const methodChannel = MethodChannel(
    MethodChannelBackgroundDownloads.methodChannelName,
  );
  const eventChannel = EventChannel(
    MethodChannelBackgroundDownloads.eventChannelName,
  );

  late List<MethodCall> calls;

  setUp(() {
    calls = <MethodCall>[];
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(methodChannel, (call) async {
          calls.add(call);
          if (call.method == 'getQueue') {
            return <String, Object?>{
              'entries': <Object?>[
                <String, Object?>{
                  'artifactId': 'model-b',
                  'status': 'queued',
                  'downloadedBytes': 0,
                  'totalBytes': 2048,
                  'queuePosition': 1,
                  'retryCount': 0,
                },
              ],
            };
          }
          return null;
        });
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(methodChannel, null);
  });

  test('request accepts only HTTPS sources and non-empty artifact IDs', () {
    expect(
      () => DownloadArtifactRequest(
        artifactId: '',
        source: Uri.parse('https://example.test/model.bin'),
        destinationPath: '/sandbox/model.bin',
      ),
      throwsArgumentError,
    );
    expect(
      () => DownloadArtifactRequest(
        artifactId: 'model-a',
        source: Uri.parse('http://example.test/model.bin'),
        destinationPath: '/sandbox/model.bin',
      ),
      throwsArgumentError,
    );
    expect(
      () => DownloadArtifactRequest(
        artifactId: 'model-a',
        source: Uri.parse('https://user:secret@example.test/model.bin'),
        destinationPath: '/sandbox/model.bin',
      ),
      throwsArgumentError,
    );
  });

  test(
    'enqueue serializes the stable v1 request without logging metadata',
    () async {
      final downloads = MethodChannelBackgroundDownloads(
        methodChannel: methodChannel,
        eventChannel: eventChannel,
      );

      await downloads.enqueue(
        DownloadArtifactRequest(
          artifactId: 'model-a',
          source: Uri.parse('https://example.test/model.bin?signature=secret'),
          destinationPath: '/sandbox/model.bin',
          expectedBytes: 1024,
          expectedSha256:
              '0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef',
          displayName: 'Model A',
        ),
      );

      expect(calls, hasLength(1));
      expect(calls.single.method, 'enqueue');
      expect(calls.single.arguments, <String, Object?>{
        'contractVersion': 1,
        'artifactId': 'model-a',
        'source': 'https://example.test/model.bin?signature=secret',
        'destinationPath': '/sandbox/model.bin',
        'expectedBytes': 1024,
        'expectedSha256':
            '0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef',
        'displayName': 'Model A',
      });
    },
  );

  test(
    'pause resume retry and cancel use artifact-scoped idempotent calls',
    () async {
      final downloads = MethodChannelBackgroundDownloads(
        methodChannel: methodChannel,
        eventChannel: eventChannel,
      );

      await downloads.pause('model-a');
      await downloads.resume('model-a');
      await downloads.retry('model-a');
      await downloads.cancel('model-a');

      expect(calls.map((call) => call.method), [
        'pause',
        'resume',
        'retry',
        'cancel',
      ]);
      for (final call in calls) {
        expect(call.arguments, <String, Object?>{'artifactId': 'model-a'});
      }
    },
  );

  test('queue snapshot decodes ordered entries and derived controls', () async {
    final downloads = MethodChannelBackgroundDownloads(
      methodChannel: methodChannel,
      eventChannel: eventChannel,
    );

    final snapshot = await downloads.getQueue();

    expect(snapshot.entries, hasLength(1));
    expect(snapshot.entries.single.artifactId, 'model-b');
    expect(snapshot.entries.single.status, DownloadStatus.queued);
    expect(snapshot.entries.single.canPause, isFalse);
    expect(snapshot.entries.single.canCancel, isTrue);
    expect(snapshot.entries.single.queuePosition, 1);
  });

  test('progress payload exposes structured retryable failure semantics', () {
    final progress = DownloadProgress.fromMap(<Object?, Object?>{
      'artifactId': 'model-a',
      'status': 'failed',
      'downloadedBytes': 512,
      'totalBytes': 1024,
      'retryCount': 2,
      'failureCode': 'transport',
      'failureMessage': 'Connection interrupted',
      'canResume': true,
    });

    expect(progress.status, DownloadStatus.failed);
    expect(progress.failure?.code, DownloadFailureCode.transport);
    expect(progress.failure?.message, 'Connection interrupted');
    expect(progress.retryCount, 2);
    expect(progress.canResume, isTrue);
    expect(progress.canRetry, isTrue);
    expect(progress.isTerminal, isFalse);
  });

  test('unknown native values fail closed with platform failure', () {
    final progress = DownloadProgress.fromMap(<Object?, Object?>{
      'artifactId': 'model-a',
      'status': 'future_status',
      'downloadedBytes': 0,
      'totalBytes': 0,
      'failureCode': 'future_failure',
    });

    expect(progress.status, DownloadStatus.failed);
    expect(progress.failure?.code, DownloadFailureCode.platformUnavailable);
    expect(progress.canRetry, isTrue);
  });
}
