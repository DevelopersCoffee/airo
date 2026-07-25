import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/services.dart';
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
    );
  }

  final file = await FilePicker.pickFile(type: FileType.video);
  if (file == null) return null;
  final path = file.path;
  if (path == null) return null;

  return PhoneLocalMediaItem(
    filePath: path,
    title: file.name,
    container: (file.extension ?? '').toLowerCase(),
  );
}

Future<PhoneLocalMediaItem?> pickAndroidPhoneLocalMediaForTv({
  required MethodChannel channel,
}) async {
  try {
    final selection = await channel.invokeMapMethod<String, Object?>(
      'pickVideo',
    );
    if (selection == null) return null;

    final token = selection['token'] as String?;
    final filePath = selection['filePath'] as String?;
    final title = selection['title'] as String?;
    if (token == null ||
        token.isEmpty ||
        filePath == null ||
        filePath.isEmpty ||
        title == null ||
        title.isEmpty) {
      if (token != null && token.isNotEmpty) {
        await channel.invokeMethod<void>('release', {'token': token});
      }
      return null;
    }

    return PhoneLocalMediaItem(
      filePath: filePath,
      title: title,
      container: _extensionOf(title),
      sourceLease: _AndroidPhoneMediaSourceLease(
        channel: channel,
        token: token,
      ),
    );
  } on PlatformException {
    return null;
  }
}

String _extensionOf(String fileName) {
  final separator = fileName.lastIndexOf('.');
  if (separator < 0 || separator == fileName.length - 1) return '';
  return fileName.substring(separator + 1).toLowerCase();
}

class _AndroidPhoneMediaSourceLease implements PhoneMediaSourceLease {
  _AndroidPhoneMediaSourceLease({required this.channel, required this.token});

  final MethodChannel channel;
  final String token;
  bool _released = false;

  @override
  Future<void> release() async {
    if (_released) return;
    _released = true;
    await channel.invokeMethod<void>('release', {'token': token});
  }
}
