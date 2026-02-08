/// Cross-platform fullscreen utility
/// Uses conditional imports to provide web fullscreen on web platform
/// and no-op stubs on other platforms

export 'web_fullscreen_stub.dart'
    if (dart.library.html) 'web_fullscreen_web.dart';

