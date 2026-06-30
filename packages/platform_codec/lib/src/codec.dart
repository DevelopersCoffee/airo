
import 'dart:typed_data';

abstract class CodecProvider<T> {
  String get name;
  List<String> get supportedMimeTypes;
  Uint8List encode(T data);
  T decode(Uint8List bytes);
}

class JsonCodecProvider implements CodecProvider<Map<String, dynamic>> {
  @override String get name => 'json';
  @override List<String> get supportedMimeTypes => ['application/json'];
  @override Uint8List encode(Map<String, dynamic> data) => Uint8List(0);
  @override Map<String, dynamic> decode(Uint8List bytes) => {};
}
