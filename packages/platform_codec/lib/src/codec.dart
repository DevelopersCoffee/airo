
import 'dart:typed_data';
import 'package:platform_provider/platform_provider.dart';

abstract class CodecProvider<T> implements PlatformProvider {
  Uint8List encode(T data);
  T decode(Uint8List bytes);
}
