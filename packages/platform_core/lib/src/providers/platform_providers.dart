import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../environment/platform_environment.dart';
import '../version/platform_version.dart';

final environmentProvider = Provider<PlatformEnvironment>((ref) {
  throw UnimplementedError('Environment must be overridden during bootstrap');
});

final platformVersionProvider = Provider<PlatformVersion>((ref) {
  throw UnimplementedError('Platform version must be overridden during bootstrap');
});
