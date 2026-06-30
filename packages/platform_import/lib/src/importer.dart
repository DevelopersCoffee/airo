
import 'dart:typed_data';
import 'package:platform_provider/platform_provider.dart';

abstract class ImporterProvider implements PlatformProvider {
  bool supports(String uri);
  Future<Uint8List> importData(String uri);
}
