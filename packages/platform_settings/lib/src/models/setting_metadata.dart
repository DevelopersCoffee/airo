import 'package:platform_core/platform_core.dart';
import 'package:equatable/equatable.dart';

class SettingMetadata extends Equatable {
  final String description;
  final SemanticVersion introducedVersion;
  final SemanticVersion? deprecatedVersion;
  final bool requiresRestart;
  
  const SettingMetadata({
    required this.description,
    required this.introducedVersion,
    this.deprecatedVersion,
    this.requiresRestart = false,
  });

  @override
  List<Object?> get props => [description, introducedVersion, deprecatedVersion, requiresRestart];
}
