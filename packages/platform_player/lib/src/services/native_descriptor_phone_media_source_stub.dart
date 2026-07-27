import 'phone_media_seekable_source.dart';

class NativeDescriptorPhoneMediaSource implements PhoneMediaSeekableSource {
  factory NativeDescriptorPhoneMediaSource({
    required int descriptor,
    required int mediaLength,
  }) {
    throw UnsupportedError(
      'Native descriptors are unavailable on this platform.',
    );
  }

  @override
  bool get isAvailable => false;

  @override
  Future<int> length() => throw const PhoneMediaSourceException(
    PhoneMediaSourceFailureCode.unavailable,
  );

  @override
  Stream<List<int>> openRead(int start, int end) => Stream.error(
    const PhoneMediaSourceException(PhoneMediaSourceFailureCode.unavailable),
  );

  void close() {}
}
