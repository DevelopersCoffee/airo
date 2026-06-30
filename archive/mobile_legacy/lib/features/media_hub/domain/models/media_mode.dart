import 'package:equatable/equatable.dart';

enum MediaMode { music, tv }

extension MediaModeX on MediaMode {
  String get label => switch (this) {
    MediaMode.music => 'Music',
    MediaMode.tv => 'TV',
  };
}

class MediaModeSelection extends Equatable {
  const MediaModeSelection(this.mode);

  final MediaMode mode;

  @override
  List<Object?> get props => [mode];
}
