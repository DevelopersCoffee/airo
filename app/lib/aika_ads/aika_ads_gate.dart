import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'aika_ads.dart';
import 'aika_ads_runtime.dart';

/// Arms in-app native ads on phone/tablet after SDK init and session warmup.
///
/// Leanback never gets a browse tile, so the library cannot sit on a blank
/// fifth slot. Phone (including Aika Stream on Pixel) receives cards only
/// once [AikaAdManager] will actually load them.
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
    final formFactor = await detectAikaAdFormFactor();
    await AikaAdManager.instance.initialize(formFactor: formFactor);
    if (!mounted) return;
    if (!shouldArmAikaPhoneAds(formFactor, AikaAdManager.instance)) {
      return;
    }
    final delay = delayUntilAikaAdsAllowed(AikaAdManager.instance);
    if (delay > Duration.zero) {
      await Future<void>.delayed(delay);
    }
    if (!mounted) return;
    if (!AikaAdManager.instance.shouldShowAd(
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
