import 'chat_workspace_store.dart';
import 'chat_workspace_store_stub.dart'
    if (dart.library.io) 'chat_workspace_store_factory_io.dart'
    as platform;

Future<ChatWorkspaceStore> openChatWorkspaceStore() =>
    platform.openChatWorkspaceStore();
