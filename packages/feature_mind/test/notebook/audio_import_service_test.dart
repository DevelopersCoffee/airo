import 'dart:io';
import 'dart:typed_data';

import 'package:feature_mind/src/capture/domain/meeting_processing_job.dart';
import 'package:feature_mind/src/notebook/application/audio_import_service.dart';
import 'package:feature_mind/src/notebook/application/youtube_audio_downloader.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image_picker/image_picker.dart';

void main() {
  late Directory tempDir;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('audio_import_');
  });

  tearDown(() async {
    if (await tempDir.exists()) await tempDir.delete(recursive: true);
  });

  test('accepts podcast and recording extensions, rejects documents', () {
    final real = AudioImportService();
    expect(real.isSupportedPath('/tmp/show.m4a'), isTrue);
    expect(real.isSupportedPath('/tmp/show.mp3'), isTrue);
    expect(real.isSupportedPath('/tmp/show.wav'), isTrue);
    expect(real.isSupportedPath('/tmp/notes.pdf'), isFalse);
    expect(real.titleFromPath('/tmp/deep_work.mp3'), 'deep work');
    expect(
      real.titleFromUrl('https://cdn.example.com/episodes/q3-review.mp3'),
      'q3-review',
    );
    expect(real.isHttpUrl('https://example.com/a.mp3'), isTrue);
    expect(real.isHttpUrl('file:///tmp/a.mp3'), isFalse);
    expect(
      real.isYoutubeUrl('https://www.youtube.com/watch?v=dQw4w9WgXcQ'),
      isTrue,
    );
    expect(real.isYoutubeUrl('https://youtu.be/dQw4w9WgXcQ'), isTrue);
    expect(real.isYoutubeUrl('https://example.com/a.mp3'), isFalse);
    expect(
      real.titleFromUrl('https://www.youtube.com/watch?v=abc'),
      'YouTube audio',
    );
  });

  test('stagePickedFile writes bytes into the sandbox dest', () async {
    final dest = '${tempDir.path}/staged.mp3';
    final service = AudioImportService();
    await service.stagePickedFile(
      _TestPlatformFile(
        path: '${tempDir.path}/clip.mp3',
        name: 'clip.mp3',
        size: 3,
        data: Uint8List.fromList([1, 2, 3]),
      ),
      dest,
    );
    expect(File(dest).lengthSync(), 3);
  });

  test('pickLocalAudio returns the chosen supported path', () async {
    final chosen = '${tempDir.path}/lecture.wav';
    File(chosen).writeAsStringSync('audio');
    final service = AudioImportService(
      pickFile: ({type = FileType.any, allowedExtensions}) async {
        expect(type, FileType.custom);
        expect(allowedExtensions, contains('mp3'));
        return _TestPlatformFile(path: chosen, name: 'lecture.wav', size: 5);
      },
    );

    expect(await service.pickLocalAudio(), chosen);
  });

  test('downloadRemote writes bytes through the injected downloader', () async {
    final dest = '${tempDir.path}/pod.mp3';
    final service = AudioImportService(
      downloader: (url, path, onProgress) async {
        expect(url, 'https://example.com/pod.mp3');
        await File(path).writeAsBytes([1, 2, 3], flush: true);
      },
    );

    await service.downloadRemote(
      url: 'https://example.com/pod.mp3',
      destPath: dest,
    );
    expect(File(dest).lengthSync(), 3);
  });

  test('downloadYoutube uses injected downloader and returns metadata', () async {
    final dest = '${tempDir.path}/youtube';
    final service = AudioImportService(
      youtubeDownloader: (url, path, onProgress) async {
        expect(url, 'https://www.youtube.com/watch?v=abc123');
        expect(path, dest);
        await File('${path}.m4a').writeAsBytes([1, 2, 3], flush: true);
        return const YoutubeAudioImport(
          path: '/ignored',
          title: 'Battery deep dive',
        );
      },
    );

    final result = await service.downloadYoutube(
      url: 'https://www.youtube.com/watch?v=abc123',
      destPath: dest,
    );
    expect(result.title, 'Battery deep dive');
  });

  test('extractYoutubeVideoId handles watch, shorts, and youtu.be links', () {
    expect(
      extractYoutubeVideoId('https://www.youtube.com/watch?v=dQw4w9WgXcQ'),
      'dQw4w9WgXcQ',
    );
    expect(
      extractYoutubeVideoId('https://youtu.be/dQw4w9WgXcQ'),
      'dQw4w9WgXcQ',
    );
    expect(
      extractYoutubeVideoId('https://www.youtube.com/shorts/abc123'),
      'abc123',
    );
    expect(extractYoutubeVideoId('https://example.com/a.mp3'), isNull);
  });

  test('jobFor stamps upload vs podcast source', () {
    final service = AudioImportService();
    final job = service.jobFor(
      audioPath: '/tmp/a.mp3',
      title: 'Show',
      source: MeetingProcessingSource.podcast,
      enqueuedAtMs: 9,
    );
    expect(job.source, MeetingProcessingSource.podcast);
    expect(job.title, 'Show');
  });
}

final class _TestPlatformFile extends PlatformFile {
  _TestPlatformFile({
    required this.path,
    required this.name,
    required this.size,
    this.data,
  });

  @override
  final String path;

  @override
  final String name;

  final int size;
  final Uint8List? data;

  @override
  Uri get uri => Uri.file(path);

  @override
  Future<int> length() async => size;

  @override
  Stream<Uint8List> readAsByteStream() => Stream.value(data ?? Uint8List(0));

  @override
  Future<Uint8List> readAsBytes() async => data ?? Uint8List(0);

  @override
  XFile get xFile => XFile(path, name: name, length: size);
}
