import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:platform_events/platform_events.dart';
import '../contracts/filesystem_service.dart';
import '../contracts/directory_provider.dart';
import '../contracts/file_manager.dart';
import '../contracts/integrity_verifier.dart';
import '../api/default_filesystem_service.dart';
import '../directories/default_directory_provider.dart';
import '../files/default_file_manager.dart';
import '../integrity/crypto_integrity_verifier.dart';

final directoryProvider = Provider<DirectoryProvider>((ref) {
  return DefaultDirectoryProvider();
});

final filesystemServiceProvider = Provider<FilesystemService>((ref) {
  return DefaultFilesystemService(ref.watch(directoryProvider) as DefaultDirectoryProvider);
});

final fileManagerProvider = Provider<FileManager>((ref) {
  final dirProvider = ref.watch(directoryProvider);
  final eventPublisher = ref.watch(eventPublisherProvider);
  return DefaultFileManager(dirProvider, eventPublisher);
});

final integrityVerifierProvider = Provider<IntegrityVerifier>((ref) {
  return CryptoIntegrityVerifier();
});
