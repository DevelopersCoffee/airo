import 'dart:io';
import '../files/platform_file.dart';

abstract interface class FileManager {
  Future<T> createFile<T extends PlatformFile>(T descriptor);
  Future<void> deleteFile(PlatformFile file);
  Future<bool> exists(PlatformFile file);
  Future<void> atomicWrite(PlatformFile destination, Future<void> Function(File tempFile) writeOperation);
}
