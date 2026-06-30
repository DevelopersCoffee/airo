
import 'dart:typed_data';

abstract class Importer {
  Future<Uint8List> importFile(String path);
  Future<Uint8List> importUrl(String url);
}

class LocalFileImporter implements Importer {
  @override
  Future<Uint8List> importFile(String path) async {
    // Read file bytes
    return Uint8List(0);
  }
  @override
  Future<Uint8List> importUrl(String url) async => throw UnimplementedError();
}
