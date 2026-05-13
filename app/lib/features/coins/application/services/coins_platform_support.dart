import 'package:flutter/foundation.dart';

class CoinsPlatformSupport {
  const CoinsPlatformSupport._();

  static bool groupsAvailable({bool isWeb = kIsWeb}) => !isWeb;
}
