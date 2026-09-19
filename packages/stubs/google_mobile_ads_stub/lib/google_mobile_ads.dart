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
  const AdRequest({this.extras});

  final Map<String, String>? extras;
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

class AdError {
  AdError(this.code, this.domain, this.message);

  final int code;
  final String domain;
  final String message;

  @override
  String toString() => message;
}

class AdSize {
  const AdSize({required this.width, required this.height});

  final int width;
  final int height;

  static const AdSize banner = AdSize(width: 320, height: 50);

  static Future<AdSize?> getCurrentOrientationAnchoredAdaptiveBannerAdSize(
    int width,
  ) async {
    return AdSize(width: width, height: 50);
  }

  static AdSize getInlineAdaptiveBannerAdSize(int width, int maxHeight) {
    return AdSize(width: width, height: maxHeight);
  }
}

class BannerAdListener {
  const BannerAdListener({
    this.onAdLoaded,
    this.onAdFailedToLoad,
    this.onAdImpression,
  });

  final void Function(Ad ad)? onAdLoaded;
  final void Function(Ad ad, LoadAdError error)? onAdFailedToLoad;
  final void Function(Ad ad)? onAdImpression;
}

class BannerAd extends Ad {
  BannerAd({
    required this.adUnitId,
    required this.size,
    required this.request,
    required this.listener,
  });

  final String adUnitId;
  final AdSize size;
  final AdRequest request;
  final BannerAdListener listener;

  Future<void> load() async {}
}

class FullScreenContentCallback<T> {
  const FullScreenContentCallback({
    this.onAdShowedFullScreenContent,
    this.onAdDismissedFullScreenContent,
    this.onAdFailedToShowFullScreenContent,
  });

  final void Function(T ad)? onAdShowedFullScreenContent;
  final void Function(T ad)? onAdDismissedFullScreenContent;
  final void Function(T ad, AdError error)? onAdFailedToShowFullScreenContent;
}

class InterstitialAdLoadCallback {
  const InterstitialAdLoadCallback({
    required this.onAdLoaded,
    required this.onAdFailedToLoad,
  });

  final void Function(InterstitialAd ad) onAdLoaded;
  final void Function(LoadAdError error) onAdFailedToLoad;
}

class InterstitialAd extends Ad {
  FullScreenContentCallback<InterstitialAd>? fullScreenContentCallback;

  static Future<void> load({
    required String adUnitId,
    required AdRequest request,
    required InterstitialAdLoadCallback adLoadCallback,
  }) async {}

  Future<void> show() async {}
}

class AppOpenAdLoadCallback {
  const AppOpenAdLoadCallback({
    required this.onAdLoaded,
    required this.onAdFailedToLoad,
  });

  final void Function(AppOpenAd ad) onAdLoaded;
  final void Function(LoadAdError error) onAdFailedToLoad;
}

class AppOpenAd extends Ad {
  FullScreenContentCallback<AppOpenAd>? fullScreenContentCallback;

  static Future<void> load({
    required String adUnitId,
    required AdRequest request,
    required AppOpenAdLoadCallback adLoadCallback,
  }) async {}

  Future<void> show() async {}
}

class RewardItem {
  const RewardItem(this.amount, this.type);

  final num amount;
  final String type;
}

class RewardedAdLoadCallback {
  const RewardedAdLoadCallback({
    required this.onAdLoaded,
    required this.onAdFailedToLoad,
  });

  final void Function(RewardedAd ad) onAdLoaded;
  final void Function(LoadAdError error) onAdFailedToLoad;
}

class RewardedInterstitialAdLoadCallback {
  const RewardedInterstitialAdLoadCallback({
    required this.onAdLoaded,
    required this.onAdFailedToLoad,
  });

  final void Function(RewardedInterstitialAd ad) onAdLoaded;
  final void Function(LoadAdError error) onAdFailedToLoad;
}

class RewardedAd extends Ad {
  FullScreenContentCallback<RewardedAd>? fullScreenContentCallback;

  static Future<void> load({
    required String adUnitId,
    required AdRequest request,
    required RewardedAdLoadCallback rewardedAdLoadCallback,
  }) async {}

  Future<void> show({
    required void Function(Ad ad, RewardItem reward) onUserEarnedReward,
  }) async {}
}

class RewardedInterstitialAd extends Ad {
  FullScreenContentCallback<RewardedInterstitialAd>? fullScreenContentCallback;

  static Future<void> load({
    required String adUnitId,
    required AdRequest request,
    required RewardedInterstitialAdLoadCallback
    rewardedInterstitialAdLoadCallback,
  }) async {}

  Future<void> show({
    required void Function(Ad ad, RewardItem reward) onUserEarnedReward,
  }) async {}
}
