import 'dart:io';

String readM3uFileSync(String path) => File(path).readAsStringSync();
