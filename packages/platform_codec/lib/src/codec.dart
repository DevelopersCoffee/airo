
import 'dart:typed_data';

abstract class Codec<T> {
  Uint8List encode(T data);
  T decode(Uint8List bytes);
}

class JsonCodec implements Codec<Map<String, dynamic>> {
  @override
  Uint8List encode(Map<String, dynamic> data) => Uint8List(0); // Stub
  @override
  Map<String, dynamic> decode(Uint8List bytes) => {}; // Stub
}
