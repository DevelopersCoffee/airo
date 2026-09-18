import 'dart:io';

import 'package:google_mobile_ads/google_mobile_ads.dart';

Future<bool> initializeAikaAdSdk() async {
  if (!Platform.isAndroid && !Platform.isIOS) {
    return false;
  }
  await MobileAds.instance.initialize();
  return true;
}
