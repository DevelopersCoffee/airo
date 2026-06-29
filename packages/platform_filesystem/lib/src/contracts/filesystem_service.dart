import 'package:platform_core/platform_core.dart';

abstract interface class FilesystemService implements PlatformService {
  Future<void> initialize();
  Future<void> shutdown();
}
