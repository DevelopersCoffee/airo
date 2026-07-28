import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('TV stub mirrors the byte-oriented file picker contract', () async {
    final bytes = Uint8List.fromList(<int>[1, 2, 3]);
    final file = PlatformFile(
      name: 'backup.json',
      size: bytes.length,
      bytes: bytes,
    );

    expect(await file.readAsBytes(), bytes);
    expect(
      await FilePicker.saveFile(fileName: file.name, bytes: bytes),
      isNull,
    );
  });
}
