import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/services.dart';
import 'package:platform_media/platform_media.dart';
import 'package:platform_player/platform_player.dart';

const _androidPhoneMediaPickerChannel = MethodChannel(
  'com.airo/phone_media_picker',
);

/// Lets an experimental build pick a phone-local video file to stream to a
/// receiver.
///
/// The feature package keeps the picker app-owned so `feature_iptv` does not
/// depend on `file_picker`, but the flow itself is a real product surface.
Future<PhoneLocalMediaItem?> pickPhoneLocalMediaForTv() async {
  if (Platform.isAndroid) {
    return pickAndroidPhoneLocalMediaForTv(
      channel: _androidPhoneMediaPickerChannel,
      analyzer: DefaultLocalMediaAssetAnalyzer(),
    );
  }

  final file = await FilePicker.pickFile(type: FileType.video);
  if (file == null) return null;
  final path = file.path;
  if (path == null) return null;
  final analysis = await DefaultLocalMediaAssetAnalyzer().analyze(
    MediaAssetAnalysisRequest(
      assetId: file.identifier ?? file.name,
      filePath: path,
      fileName: file.name,
      fileSizeBytesHint: file.size > 0 ? file.size : null,
    ),
  );

  return _phoneLocalMediaItem(
    filePath: path,
    title: file.name,
    fallbackContainer: (file.extension ?? '').toLowerCase(),
    analysis: analysis,
  );
}

Future<PhoneLocalMediaItem?> pickAndroidPhoneLocalMediaForTv({
  required MethodChannel channel,
  LocalMediaAssetAnalyzer? analyzer,
}) async {
  try {
    final selection = await channel.invokeMapMethod<String, Object?>(
      'pickVideo',
    );
    if (selection == null) return null;

    final token = selection['token'] as String?;
    final descriptor = (selection['descriptor'] as num?)?.round();
    final mediaLength = (selection['size'] as num?)?.round();
    final filePath = selection['filePath'] as String?;
    final title = selection['title'] as String?;
    if (token == null ||
        token.isEmpty ||
        descriptor == null ||
        descriptor < 0 ||
        mediaLength == null ||
        mediaLength < 0 ||
        filePath == null ||
        filePath.isEmpty ||
        title == null ||
        title.isEmpty) {
      if (token != null && token.isNotEmpty) {
        await channel.invokeMethod<void>('release', {'token': token});
      }
      return null;
    }
    final analysis = await (analyzer ?? DefaultLocalMediaAssetAnalyzer())
        .analyze(
          MediaAssetAnalysisRequest(
            assetId: token,
            filePath: filePath,
            fileName: title,
            fileSizeBytesHint: mediaLength,
          ),
        );
    final source = _AndroidPhoneMediaSource(
      channel: channel,
      token: token,
      descriptor: descriptor,
      mediaLength: mediaLength,
    );

    return _phoneLocalMediaItem(
      filePath: filePath,
      title: title,
      fallbackContainer: _extensionOf(title),
      analysis: analysis,
      sourceLease: source,
      source: source,
    );
  } on PlatformException {
    return null;
  }
}

PhoneLocalMediaItem _phoneLocalMediaItem({
  required String filePath,
  required String title,
  required String fallbackContainer,
  required MediaAssetAnalysisResult analysis,
  PhoneMediaSourceLease? sourceLease,
  PhoneMediaSeekableSource? source,
}) {
  final profile = analysis.profile;
  final analyzedContainer = profile?.container;
  final primaryVideo = profile?.videoTracks.firstOrNull;
  final primaryAudio = profile?.audioTracks.firstOrNull;
  return PhoneLocalMediaItem(
    filePath: filePath,
    title: title,
    container:
        analyzedContainer == null ||
            analyzedContainer == MediaAssetContainer.unknown
        ? fallbackContainer
        : analyzedContainer.stableId,
    sourceLease: sourceLease,
    source: source,
    videoCodec:
        primaryVideo == null || primaryVideo.codec == MediaVideoCodec.unknown
        ? null
        : primaryVideo.codec.stableId,
    audioCodec:
        primaryAudio == null || primaryAudio.codec == MediaAudioCodec.unknown
        ? null
        : primaryAudio.codec.stableId,
    duration: profile?.duration,
  );
}

String _extensionOf(String fileName) {
  final separator = fileName.lastIndexOf('.');
  if (separator < 0 || separator == fileName.length - 1) return '';
  return fileName.substring(separator + 1).toLowerCase();
}

class _AndroidPhoneMediaSource
    implements PhoneMediaSourceLease, PhoneMediaSeekableSource {
  _AndroidPhoneMediaSource({
    required this.channel,
    required this.token,
    required int descriptor,
    required int mediaLength,
  }) : _source = NativeDescriptorPhoneMediaSource(
         descriptor: descriptor,
         mediaLength: mediaLength,
       );

  final MethodChannel channel;
  final String token;
  final NativeDescriptorPhoneMediaSource _source;
  bool _released = false;

  @override
  bool get isAvailable => !_released && _source.isAvailable;

  @override
  Future<int> length() => _source.length();

  @override
  Stream<List<int>> openRead(int start, int end) =>
      _source.openRead(start, end);

  @override
  Future<void> release() async {
    if (_released) return;
    _released = true;
    _source.close();
    await channel.invokeMethod<void>('release', {'token': token});
  }
}
