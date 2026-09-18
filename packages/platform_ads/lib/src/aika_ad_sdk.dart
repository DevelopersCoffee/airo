import 'aika_ad_sdk_stub.dart'
    if (dart.library.io) 'aika_ad_sdk_io.dart'
    as impl;

typedef AikaAdSdkInitializer = Future<bool> Function();

class AikaAdSdk {
  const AikaAdSdk({this.initializeFn});

  final AikaAdSdkInitializer? initializeFn;

  Future<bool> initialize() => (initializeFn ?? impl.initializeAikaAdSdk)();
}
