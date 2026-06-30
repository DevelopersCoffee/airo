
import 'dart:typed_data';

abstract class ImporterProvider {
  String get name;
  bool supports(String uri);
  Future<Uint8List> importData(String uri);
}

class FilesystemImporter implements ImporterProvider {
  @override String get name => 'filesystem';
  @override bool supports(String uri) => uri.startsWith('file://') || uri.startsWith('/');
  @override Future<Uint8List> importData(String uri) async => Uint8List(0);
}
