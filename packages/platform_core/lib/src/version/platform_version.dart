import 'package:equatable/equatable.dart';

class SemanticVersion extends Equatable {
  final int major;
  final int minor;
  final int patch;
  final String? preRelease;
  final String? buildMetadata;

  const SemanticVersion({
    required this.major,
    required this.minor,
    required this.patch,
    this.preRelease,
    this.buildMetadata,
  });

  @override
  List<Object?> get props => [major, minor, patch, preRelease, buildMetadata];
  
  @override
  String toString() {
    var v = '$major.$minor.$patch';
    if (preRelease != null) v += '-$preRelease';
    if (buildMetadata != null) v += '+$buildMetadata';
    return v;
  }
}

class PlatformVersion extends Equatable {
  final SemanticVersion coreVersion;
  final SemanticVersion apiVersion;

  const PlatformVersion({
    required this.coreVersion,
    required this.apiVersion,
  });

  @override
  List<Object?> get props => [coreVersion, apiVersion];
}
