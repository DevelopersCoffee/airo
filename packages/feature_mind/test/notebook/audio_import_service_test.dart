import 'dart:io';
import 'dart:typed_data';

import 'package:feature_mind/src/capture/domain/meeting_processing_job.dart';
import 'package:feature_mind/src/notebook/application/audio_import_service.dart';
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
      downloader: (url, path) async {
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
  });

  @override
  final String path;

  @override
  final String name;

  final int size;

  @override
  Uri get uri => Uri.file(path);

  @override
  Future<int> length() async => size;

  @override
  Stream<Uint8List> readAsByteStream() => const Stream.empty();

  @override
  Future<Uint8List> readAsBytes() async => Uint8List(0);

  @override
  XFile get xFile => XFile(path, name: name, length: size);
}
