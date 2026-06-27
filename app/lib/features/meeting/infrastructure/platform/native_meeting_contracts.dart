import 'package:flutter/services.dart';

import '../../domain/entities/meeting_audio_metadata.dart';
import '../../domain/entities/meeting_record.dart';
import '../../domain/entities/transcript_chunk.dart';

const meetingRecorderChannelName = 'com.airo.meeting/recorder';
const meetingTranscriptionChannelName = 'com.airo.meeting/transcription';
const meetingTranscriptionEventsChannelName =
    'com.airo.meeting/transcription_events';

class NativeMeetingRecorderContract {
  NativeMeetingRecorderContract({
    MethodChannel channel = const MethodChannel(meetingRecorderChannelName),
  }) : _channel = channel;

  final MethodChannel _channel;

  Future<void> startRecording({required MeetingRecord meeting}) async {
    await _channel.invokeMethod<void>('startMeeting', {
      'meetingId': meeting.id,
      'title': meeting.title,
      'startedAt': meeting.startedAt.toUtc().toIso8601String(),
      if (meeting.languageCode case final String languageCode)
        'languageCode': languageCode,
    });
  }

  Future<void> pauseRecording({required String meetingId}) async {
    await _channel.invokeMethod<void>('pauseMeeting', {'meetingId': meetingId});
  }

  Future<void> resumeRecording({required String meetingId}) async {
    await _channel.invokeMethod<void>('resumeMeeting', {
      'meetingId': meetingId,
    });
  }

  Future<MeetingAudioMetadata> stopRecording({
    required String meetingId,
  }) async {
    final response = await _channel.invokeMapMethod<String, Object?>(
      'stopMeeting',
      {'meetingId': meetingId},
    );
    return _audioMetadataFromMap(response, fallbackMeetingId: meetingId);
  }

  Future<void> cancelRecording({required String meetingId}) async {
    await _channel.invokeMethod<void>('cancelMeeting', {
      'meetingId': meetingId,
    });
  }
}

class NativeMeetingTranscriptionContract {
  NativeMeetingTranscriptionContract({
    MethodChannel channel = const MethodChannel(
      meetingTranscriptionChannelName,
    ),
    EventChannel eventChannel = const EventChannel(
      meetingTranscriptionEventsChannelName,
    ),
    Stream<Object?> Function(EventChannel channel)? eventStreamFactory,
  }) : _channel = channel,
       _eventChannel = eventChannel,
       _eventStreamFactory = eventStreamFactory ?? _defaultEventStreamFactory;

  final MethodChannel _channel;
  final EventChannel _eventChannel;
  final Stream<Object?> Function(EventChannel channel) _eventStreamFactory;

  Stream<TranscriptChunk> transcriptEvents() {
    return _eventStreamFactory(
      _eventChannel,
    ).map((event) => _transcriptChunkFromMap(_requireMap(event, 'event')));
  }

  Future<void> startRealtimeTranscription({
    required String meetingId,
    required String languageCode,
  }) async {
    await _channel.invokeMethod<void>('startRealtimeTranscription', {
      'meetingId': meetingId,
      'languageCode': languageCode,
    });
  }

  Future<void> pauseRealtimeTranscription({required String meetingId}) async {
    await _channel.invokeMethod<void>('pauseRealtimeTranscription', {
      'meetingId': meetingId,
    });
  }

  Future<void> resumeRealtimeTranscription({required String meetingId}) async {
    await _channel.invokeMethod<void>('resumeRealtimeTranscription', {
      'meetingId': meetingId,
    });
  }

  Future<void> stopRealtimeTranscription({required String meetingId}) async {
    await _channel.invokeMethod<void>('stopRealtimeTranscription', {
      'meetingId': meetingId,
    });
  }

  static Stream<Object?> _defaultEventStreamFactory(EventChannel channel) {
    return channel.receiveBroadcastStream();
  }
}

MeetingAudioMetadata _audioMetadataFromMap(
  Map<String, Object?>? payload, {
  required String fallbackMeetingId,
}) {
  final map = _requireMap(payload, 'audio metadata');
  return MeetingAudioMetadata(
    meetingId:
        _optionalString(map, 'meetingId') ??
        _optionalString(map, 'meeting_id') ??
        fallbackMeetingId,
    filePath: _requiredString(map, 'filePath', aliases: const ['file_path']),
    codec: _requiredString(map, 'codec'),
    sampleRateHz: _requiredInt(
      map,
      'sampleRateHz',
      aliases: const ['sample_rate_hz'],
    ),
    channelCount: _requiredInt(
      map,
      'channelCount',
      aliases: const ['channel_count'],
    ),
    sizeBytes: _requiredInt(map, 'sizeBytes', aliases: const ['size_bytes']),
    sha256: _requiredString(map, 'sha256'),
  );
}

TranscriptChunk _transcriptChunkFromMap(Map<String, Object?> map) {
  return TranscriptChunk(
    id: _requiredString(map, 'id'),
    meetingId: _requiredString(map, 'meetingId', aliases: const ['meeting_id']),
    text: _requiredString(map, 'text'),
    startMs: _requiredInt(map, 'startMs', aliases: const ['start_ms']),
    endMs: _requiredInt(map, 'endMs', aliases: const ['end_ms']),
    isFinal: _requiredBool(map, 'isFinal', aliases: const ['is_final']),
    speakerLabel: _optionalString(
      map,
      'speakerLabel',
      aliases: const ['speaker_label'],
    ),
    confidence: _optionalDouble(map, 'confidence'),
  );
}

Map<String, Object?> _requireMap(Object? payload, String label) {
  if (payload is Map<Object?, Object?>) {
    return payload.map((key, value) => MapEntry('$key', value));
  }
  throw FormatException('Expected $label payload to be a map.');
}

Object? _lookup(
  Map<String, Object?> map,
  String key, {
  List<String> aliases = const [],
}) {
  if (map.containsKey(key)) {
    return map[key];
  }
  for (final alias in aliases) {
    if (map.containsKey(alias)) {
      return map[alias];
    }
  }
  return null;
}

String _requiredString(
  Map<String, Object?> map,
  String key, {
  List<String> aliases = const [],
}) {
  final value = _lookup(map, key, aliases: aliases);
  if (value is String && value.isNotEmpty) {
    return value;
  }
  throw FormatException('Expected "$key" to be a non-empty string.');
}

String? _optionalString(
  Map<String, Object?> map,
  String key, {
  List<String> aliases = const [],
}) {
  final value = _lookup(map, key, aliases: aliases);
  if (value == null) {
    return null;
  }
  if (value is String && value.isNotEmpty) {
    return value;
  }
  throw FormatException('Expected "$key" to be a non-empty string.');
}

int _requiredInt(
  Map<String, Object?> map,
  String key, {
  List<String> aliases = const [],
}) {
  final value = _lookup(map, key, aliases: aliases);
  if (value is int) {
    return value;
  }
  throw FormatException('Expected "$key" to be an int.');
}

bool _requiredBool(
  Map<String, Object?> map,
  String key, {
  List<String> aliases = const [],
}) {
  final value = _lookup(map, key, aliases: aliases);
  if (value is bool) {
    return value;
  }
  throw FormatException('Expected "$key" to be a bool.');
}

double? _optionalDouble(Map<String, Object?> map, String key) {
  final value = map[key];
  if (value == null) {
    return null;
  }
  if (value is num) {
    return value.toDouble();
  }
  throw FormatException('Expected "$key" to be numeric.');
}
