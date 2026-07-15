import 'dart:io';

String readXmltvFileSync(String path) {
  return File(path).readAsStringSync();
}
