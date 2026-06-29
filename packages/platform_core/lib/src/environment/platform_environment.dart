import 'package:freezed_annotation/freezed_annotation.dart';

part 'platform_environment.freezed.dart';

@freezed
class PlatformEnvironment with _$PlatformEnvironment {
  const factory PlatformEnvironment({
    required String buildMode,
    required String platform,
    required String version,
    required String packageVersion,
    @Default([]) List<String> deviceCapabilities,
    @Default([]) List<String> featureFlags,
  }) = _PlatformEnvironment;
}
