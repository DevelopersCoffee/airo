import 'dart:io';

import 'package:path_provider/path_provider.dart';

import '../../domain/models/chat_workspace_layout.dart';
import 'chat_workspace_store.dart';
import 'chat_workspace_store_io.dart';

Future<ChatWorkspaceStore> openChatWorkspaceStore() async {
  try {
    final support = await getApplicationSupportDirectory();
    final root = Directory('${support.path}/${ChatWorkspaceLayout.rootName}');
    await root.create(recursive: true);
    return IoChatWorkspaceStore(root);
  } on Object {
    return MemoryChatWorkspaceStore();
  }
}
