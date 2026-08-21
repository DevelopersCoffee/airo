/// On-disk layout for Mind chats, matching Cursor's project folder:
/// one directory of shared knowledge, and one folder per chat whose
/// transcript is JSONL named after the chat id.
///
/// ```
/// <root>/
///   directory/graph.json
///   chats/<id>/<id>.jsonl
///   chats/<id>/graph.json
/// ```
class ChatWorkspaceLayout {
  const ChatWorkspaceLayout._();

  static const rootName = 'airo_mind';
  static const chatsFolder = 'chats';
  static const directoryFolder = 'directory';
  static const directoryGraphFile = 'graph.json';

  static const directoryPath = '$directoryFolder/$directoryGraphFile';

  static String chatFolder(String id) => '$chatsFolder/$id';

  static String transcriptPath(String id) => '${chatFolder(id)}/$id.jsonl';

  static String chatGraphPath(String id) =>
      '${chatFolder(id)}/$directoryGraphFile';
}
