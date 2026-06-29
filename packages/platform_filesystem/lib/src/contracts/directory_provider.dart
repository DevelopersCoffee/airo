import 'dart:io';

abstract interface class DirectoryProvider {
  Future<Directory> systemDirectory();
  Future<Directory> workspacesDirectory();
  Future<Directory> workspaceDirectory(String workspaceId);
  Future<Directory> modelsDirectory();
  Future<Directory> modelTypeDirectory(String type); // llm, embedding, whisper, tts, vision
  Future<Directory> downloadsDirectory();
  Future<Directory> cacheDirectory();
  Future<Directory> exportsDirectory();
  Future<Directory> importsDirectory();
  Future<Directory> tempDirectory();
  Future<Directory> diagnosticsDirectory();
  Future<Directory> backupsDirectory();
}
