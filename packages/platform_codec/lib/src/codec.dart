
import 'dart:typed_data';

abstract class Codec<T> {
  String get name;
  T decode(Uint8List bytes);
  Uint8List encode(T data);
}
