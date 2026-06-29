class MeetingAudioMetadata {
  const MeetingAudioMetadata({
    required this.meetingId,
    required this.filePath,
    required this.codec,
    required this.sampleRateHz,
    required this.channelCount,
    required this.sizeBytes,
    required this.sha256,
  });

  final String meetingId;
  final String filePath;
  final String codec;
  final int sampleRateHz;
  final int channelCount;
  final int sizeBytes;
  final String sha256;
}
