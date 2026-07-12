import 'package:flutter/foundation.dart';

class AppLogger {
  static void info(String message, {String? tag}) {
    debugPrint(_format(message, tag));
  }

  static void analytics(String event, {Map<String, Object?>? params}) {
    debugPrint(_format('$event ${params ?? const {}}', 'analytics'));
  }

  static String _format(String message, String? tag) {
    return tag == null ? message : '[$tag] $message';
  }
}
