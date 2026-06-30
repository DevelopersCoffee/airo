import 'dart:async';

abstract interface class DownloadTransport {
  Stream<List<int>> fetch(String url, {int? startByte, int? endByte});
  Future<int> getContentLength(String url);
}
