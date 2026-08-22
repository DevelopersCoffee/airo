/// On-disk layout for Mind chats, matching Cursor's project folder:
/// shared knowledge per classification folder, and one folder per chat whose
/// transcript is JSONL named after the chat id.
///
/// ```
/// <root>/
///   directory/graph.json
///   folders.json
///   folders/<folderId>/graph.json
///   chats/<id>/<id>.jsonl
///   chats/<id>/graph.json
///   chats/<id>/meta.json
/// ```
class ChatWorkspaceLayout {
  const ChatWorkspaceLayout._();

  static const rootName = 'airo_mind';
  static const chatsFolder = 'chats';
  static const directoryFolder = 'directory';
  static const foldersFolder = 'folders';
  static const foldersIndexFile = 'folders.json';
  static const directoryGraphFile = 'graph.json';
  static const chatMetaFile = 'meta.json';

  static const directoryPath = '$directoryFolder/$directoryGraphFile';

  static String chatFolder(String id) => '$chatsFolder/$id';

  static String transcriptPath(String id) => '${chatFolder(id)}/$id.jsonl';

  static String chatGraphPath(String id) =>
      '${chatFolder(id)}/$directoryGraphFile';

  static String chatMetaPath(String id) => '${chatFolder(id)}/$chatMetaFile';

  static String folderGraphPath(String folderId) =>
      '$foldersFolder/$folderId/$directoryGraphFile';
}
