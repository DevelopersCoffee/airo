import 'dart:async';

import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

import 'aika_ad_ids.dart';
import 'aika_ad_manager.dart';
import 'aika_ad_policy.dart';

/// Dismissible AdMob Native Advanced card. Fails silent on no fill.
class AikaNativeAdCard extends StatefulWidget {
  const AikaNativeAdCard({
    super.key,
    required this.placement,
    this.isLeanback = false,
    this.isCasting = false,
  });

  final AikaAdPlacement placement;
  final bool isLeanback;
  final bool isCasting;

  @override
  State<AikaNativeAdCard> createState() => _AikaNativeAdCardState();
}

class _AikaNativeAdCardState extends State<AikaNativeAdCard> {
  NativeAd? _nativeAd;
  bool _isAdLoaded = false;
  bool _dismissed = false;

  bool get _browse => widget.placement == AikaAdPlacement.browse;

  @override
  void initState() {
    super.initState();
    unawaited(_startLoad());
  }

  Future<void> _startLoad() async {
    await AikaAdManager.instance.initialize();
    if (!mounted) {
      return;
    }
    _loadAd();
  }

  void _loadAd() {
    if (!AikaAdManager.instance.shouldShowAd(
      isLeanback: widget.isLeanback,
      isCasting: widget.isCasting,
    )) {
      return;
    }

    final colors = Theme.of(context).colorScheme;
    _nativeAd = NativeAd(
      adUnitId: aikaNativeAdUnitId,
      request: const AdRequest(),
      nativeTemplateStyle: NativeTemplateStyle(
        templateType: _browse ? TemplateType.small : TemplateType.medium,
        mainBackgroundColor: colors.surface,
        cornerRadius: 12,
        callToActionTextStyle: NativeTemplateTextStyle(
          textColor: colors.onPrimary,
          backgroundColor: colors.primary,
          style: NativeTemplateFontStyle.bold,
          size: 14,
        ),
        primaryTextStyle: NativeTemplateTextStyle(
          textColor: colors.onSurface,
          style: NativeTemplateFontStyle.bold,
          size: 14,
        ),
        secondaryTextStyle: NativeTemplateTextStyle(
          textColor: colors.onSurfaceVariant,
          style: NativeTemplateFontStyle.normal,
          size: 12,
        ),
      ),
      listener: NativeAdListener(
        onAdLoaded: (ad) {
          if (!mounted) {
            ad.dispose();
            return;
          }
          setState(() {
            _isAdLoaded = true;
          });
        },
        onAdFailedToLoad: (ad, error) {
          ad.dispose();
          debugPrint('Aika native ad failed to load: $error');
          if (mounted) {
            setState(() {
              _nativeAd = null;
              _isAdLoaded = false;
            });
          }
        },
        onAdImpression: (ad) {
          AikaAdManager.instance.recordAdImpression();
        },
      ),
    )..load();
  }

  void _dismiss() {
    _nativeAd?.dispose();
    _nativeAd = null;
    AikaAdManager.instance.recordAdImpression();
    setState(() {
      _dismissed = true;
      _isAdLoaded = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_dismissed || !_isAdLoaded || _nativeAd == null) {
      return const SizedBox.shrink();
    }

    final colors = Theme.of(context).colorScheme;
    final height = _browse ? 120.0 : 250.0;

    return Semantics(
      label: 'Advertisement',
      child: Material(
        color: colors.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(12),
        clipBehavior: Clip.antiAlias,
        child: Stack(
          children: [
            SizedBox(
              height: height,
              width: double.infinity,
              child: AdWidget(ad: _nativeAd!),
            ),
            Positioned(
              top: 0,
              right: 0,
              child: IconButton(
                tooltip: 'Hide ad',
                visualDensity: VisualDensity.compact,
                onPressed: _dismiss,
                icon: Icon(
                  Icons.close,
                  size: 18,
                  color: colors.onSurfaceVariant,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _nativeAd?.dispose();
    super.dispose();
  }
}
