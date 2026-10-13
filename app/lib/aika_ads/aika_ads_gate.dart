import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/providers/ads_personalization_consent_provider.dart';
import 'aika_ad_manager_binding.dart';
import 'aika_ads.dart';
import 'aika_ads_runtime.dart';

/// Arms in-app native ads on phone/tablet as soon as the Mobile Ads SDK is
/// ready. Leanback never gets a browse tile.
class AikaAdsGate extends ConsumerStatefulWidget {
  const AikaAdsGate({required this.child, super.key});

  final Widget child;

  @override
  ConsumerState<AikaAdsGate> createState() => _AikaAdsGateState();
}

class _AikaAdsGateState extends ConsumerState<AikaAdsGate> {
  @override
  void initState() {
    super.initState();
    unawaited(_arm());
  }

  Future<void> _arm() async {
    ref.read(adsPersonalizationConsentProvider);
    final formFactor = await detectAikaAdFormFactor();
    await resolveAikaAdManager().initialize(formFactor: formFactor);
    if (!mounted) return;
    if (!shouldArmAikaPhoneAds(formFactor, resolveAikaAdManager())) {
      return;
    }
    allowImmediateAikaPhoneAds(resolveAikaAdManager());
    if (!mounted) return;
    if (!resolveAikaAdManager().shouldShowAd(
      isLeanback: false,
      isCasting: false,
    )) {
      return;
    }
    ref.read(aikaIptvAdPlacementsStateProvider.notifier).state =
        aikaIptvAdPlacements(formFactor: formFactor);
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
