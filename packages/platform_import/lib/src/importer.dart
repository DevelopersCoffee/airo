
import 'dart:typed_data';

abstract class Importer {
  Future<Uint8List> importFile(String path);
  Future<Uint8List> importUrl(String url);
}
