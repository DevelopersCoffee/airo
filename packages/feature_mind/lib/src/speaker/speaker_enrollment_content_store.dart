import 'dart:io';
import 'dart:typed_data';

/// Content-addressed embedding blobs for enrolled speakers (#504).
///
/// Embeddings live beside the enrollment op log — not inlined in JSONL — so
/// replay stays cheap and the shape matches future Vault content storage.
class SpeakerEnrollmentContentStore {
  SpeakerEnrollmentContentStore(this._contentDir);

  final Directory _contentDir;

  static Future<SpeakerEnrollmentContentStore> open(
    String contentDirPath,
  ) async {
    final dir = Directory(contentDirPath);
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    return SpeakerEnrollmentContentStore(dir);
  }

  File _fileFor(String profileId) => File('${_contentDir.path}/$profileId.bin');

  Future<void> put(String profileId, List<double> embedding) async {
    if (profileId.isEmpty || embedding.isEmpty) return;
    final bytes = ByteData(embedding.length * 4);
    for (var i = 0; i < embedding.length; i++) {
      bytes.setFloat32(i * 4, embedding[i], Endian.little);
    }
    await _fileFor(
      profileId,
    ).writeAsBytes(bytes.buffer.asUint8List(), flush: true);
  }

  Future<List<double>?> get(String profileId) async {
    final file = _fileFor(profileId);
    if (!await file.exists()) return null;
    final raw = await file.readAsBytes();
    if (raw.isEmpty || raw.length % 4 != 0) return null;
    final data = ByteData.sublistView(raw);
    return [
      for (var i = 0; i < data.lengthInBytes ~/ 4; i++)
        data.getFloat32(i * 4, Endian.little),
    ];
  }

  Future<void> remove(String profileId) async {
    final file = _fileFor(profileId);
    if (await file.exists()) {
      await file.delete();
    }
  }
}
