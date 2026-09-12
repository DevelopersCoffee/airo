/// Minimal AdMob surface for the phone flavor. The TV pubspec resolves the
/// real `google_mobile_ads` package. This stub never serves ads.
library;

import 'package:flutter/widgets.dart';

class MobileAds {
  MobileAds._();

  static final MobileAds instance = MobileAds._();

  Future<InitializationStatus> initialize() async {
    return const InitializationStatus();
  }
}

class InitializationStatus {
  const InitializationStatus();
}

class AdRequest {
  const AdRequest();
}

class LoadAdError {
  LoadAdError(this.code, this.domain, this.message);

  final int code;
  final String domain;
  final String message;

  @override
  String toString() => message;
}

class Ad {
  void dispose() {}
}

class NativeAd extends Ad {
  NativeAd({
    required this.adUnitId,
    required this.listener,
    required this.request,
    this.nativeTemplateStyle,
    this.factoryId,
  });

  final String adUnitId;
  final NativeAdListener listener;
  final AdRequest request;
  final NativeTemplateStyle? nativeTemplateStyle;
  final String? factoryId;

  Future<void> load() async {
    listener.onAdFailedToLoad?.call(
      this,
      LoadAdError(0, 'stub', 'Ads are unavailable in this flavor.'),
    );
  }
}

class NativeAdListener {
  const NativeAdListener({
    this.onAdLoaded,
    this.onAdFailedToLoad,
    this.onAdImpression,
    this.onAdClicked,
    this.onAdClosed,
    this.onAdOpened,
  });

  final void Function(Ad ad)? onAdLoaded;
  final void Function(Ad ad, LoadAdError error)? onAdFailedToLoad;
  final void Function(Ad ad)? onAdImpression;
  final void Function(Ad ad)? onAdClicked;
  final void Function(Ad ad)? onAdClosed;
  final void Function(Ad ad)? onAdOpened;
}

class AdWidget extends StatelessWidget {
  const AdWidget({super.key, required this.ad});

  final Ad ad;

  @override
  Widget build(BuildContext context) => const SizedBox.shrink();
}

enum TemplateType { small, medium }

enum NativeTemplateFontStyle { normal, bold, italic, monospace }

class NativeTemplateTextStyle {
  NativeTemplateTextStyle({
    this.textColor,
    this.backgroundColor,
    this.style,
    this.size,
  });

  Color? textColor;
  Color? backgroundColor;
  NativeTemplateFontStyle? style;
  double? size;
}

class NativeTemplateStyle {
  NativeTemplateStyle({
    required this.templateType,
    this.callToActionTextStyle,
    this.primaryTextStyle,
    this.secondaryTextStyle,
    this.tertiaryTextStyle,
    this.mainBackgroundColor,
    this.cornerRadius,
  });

  TemplateType templateType;
  NativeTemplateTextStyle? callToActionTextStyle;
  NativeTemplateTextStyle? primaryTextStyle;
  NativeTemplateTextStyle? secondaryTextStyle;
  NativeTemplateTextStyle? tertiaryTextStyle;
  Color? mainBackgroundColor;
  double? cornerRadius;
}
