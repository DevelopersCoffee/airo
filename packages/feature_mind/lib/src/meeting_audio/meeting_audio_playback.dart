import 'dart:async';
import 'dart:io';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;

/// Plays a meeting's source recording and seeks to a transcript timestamp.
///
/// Stays on the [AudioPlayer] methods the TV stub also implements (`play`,
/// `pause`, `resume`, `seek`) so a flavor that swaps `audioplayers` for
/// `packages/stubs/audioplayers_stub` still compiles. [AudioPlayer] is only
/// constructed on the first play/seek so widget tests that never tap Play
/// do not need the plugin channel.
class MeetingAudioPlayback extends ChangeNotifier {
  MeetingAudioPlayback({AudioPlayer? player}) : _injected = player;

  final AudioPlayer? _injected;
  AudioPlayer? _player;
  StreamSubscription<Duration>? _positionSub;
  StreamSubscription<Duration>? _durationSub;
  StreamSubscription<PlayerState>? _stateSub;

  String? _path;
  Duration _position = Duration.zero;
  Duration _duration = Duration.zero;
  bool _playing = false;

  Duration get position => _position;
  Duration get duration => _duration;
  bool get playing => _playing;
  String? get path => _path;

  static bool fileExists(String? path) {
    if (path == null || path.isEmpty) return false;
    try {
      return File(path).existsSync();
    } on Object {
      return false;
    }
  }

  Future<void> toggle(String path) async {
    final player = await _ensurePlayer();
    if (_playing) {
      await player.pause();
      return;
    }
    if (_path == path) {
      await player.resume();
      return;
    }
    _path = path;
    await player.play(DeviceFileSource(path, mimeType: _mimeTypeForPath(path)));
  }

  Future<void> seekAndPlay(String path, int startMs) async {
    final player = await _ensurePlayer();
    final position = Duration(milliseconds: startMs < 0 ? 0 : startMs);
    if (_path != path) {
      _path = path;
      await player.play(DeviceFileSource(path, mimeType: _mimeTypeForPath(path)));
    }
    await player.seek(position);
    if (!_playing) {
      await player.resume();
    }
  }

  Future<AudioPlayer> _ensurePlayer() async {
    if (_player != null) return _player!;
    final player = _injected ?? AudioPlayer();
    _player = player;
    _positionSub = player.onPositionChanged.listen((position) {
      _position = position;
      notifyListeners();
    });
    _durationSub = player.onDurationChanged.listen((duration) {
      _duration = duration;
      notifyListeners();
    });
    _stateSub = player.onPlayerStateChanged.listen((state) {
      _playing = state == PlayerState.playing;
      notifyListeners();
    });
    return player;
  }

  static String? _mimeTypeForPath(String path) {
    switch (p.extension(path).toLowerCase()) {
      case '.m4a':
      case '.m4b':
      case '.mp4':
        return 'audio/mp4';
      case '.mp3':
        return 'audio/mpeg';
      case '.wav':
        return 'audio/wav';
      case '.aac':
        return 'audio/aac';
      case '.ogg':
      case '.opus':
        return 'audio/ogg';
      case '.flac':
        return 'audio/flac';
      case '.caf':
        return 'audio/x-caf';
      case '.webm':
        return 'audio/webm';
      default:
        return null;
    }
  }

  @override
  void dispose() {
    unawaited(_positionSub?.cancel());
    unawaited(_durationSub?.cancel());
    unawaited(_stateSub?.cancel());
    unawaited(_player?.dispose());
    super.dispose();
  }
}
