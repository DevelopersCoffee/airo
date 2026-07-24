import 'package:file_picker/file_picker.dart';
import 'package:platform_player/platform_player.dart';

/// Lets the user pick a phone-local video file to stream to a cast receiver.
///
/// The feature package keeps the picker app-owned so `feature_iptv` does not
/// depend on `file_picker`, but the flow itself is a real product surface.
Future<PhoneLocalMediaItem?> pickPhoneLocalMediaForTv() async {
  final result = await FilePicker.pickFiles(type: FileType.video);
  final files = result?.files;
  if (files == null || files.isEmpty) return null;

  final file = files.first;
  final path = file.path;
  if (path == null) return null;

  return PhoneLocalMediaItem(
    filePath: path,
    title: file.name,
    container: (file.extension ?? '').toLowerCase(),
  );
}
