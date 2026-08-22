import 'chat_workspace_store.dart';

Future<ChatWorkspaceStore> openChatWorkspaceStore() async =>
    MemoryChatWorkspaceStore();
