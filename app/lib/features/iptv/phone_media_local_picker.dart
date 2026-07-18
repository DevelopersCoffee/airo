import 'package:file_picker/file_picker.dart';
import 'package:platform_player/platform_player.dart';

/// CV-033 debug entry point: lets the user pick a phone-local video file to
/// stream to a cast receiver. Only wired into the app for debug builds
/// (see `app_router.dart`) — the end-user surface for this flow is
/// undecided, so this stays behind a debug gate rather than blocking
/// hardware testing on final UX.
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
