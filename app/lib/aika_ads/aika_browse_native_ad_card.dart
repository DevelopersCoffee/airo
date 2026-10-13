import 'dart:async';

import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

import 'aika_ad_manager_binding.dart';
import 'aika_ad_personalization.dart';
import 'aika_ads.dart';

/// Browse Native card sized for AdMob's small template.
///
/// Google's validator flags "Advertiser assets outside native ad view" when
/// [TemplateType.small] is clipped into an 88px list row or a 128px poster
/// cell, or when a Flutter close button is stacked on top of [AdWidget].
/// This card keeps the native view at 120×full-width, unclipped, with
/// dismiss chrome *above* the [NativeAdView].
class AikaBrowseNativeAdCard extends StatefulWidget {
  const AikaBrowseNativeAdCard({
    super.key,
    this.isLeanback = false,
    this.isCasting = false,
    @visibleForTesting this.debugBodyOverride,
  });

  static const double templateHeight = 120;

  final bool isLeanback;
  final bool isCasting;

  /// Skips Mobile Ads load and renders this body when set (widget tests only).
  @visibleForTesting
  final Widget? debugBodyOverride;

  @override
  State<AikaBrowseNativeAdCard> createState() => _AikaBrowseNativeAdCardState();
}

class _AikaBrowseNativeAdCardState extends State<AikaBrowseNativeAdCard> {
  NativeAd? _nativeAd;
  bool _isAdLoaded = false;
  bool _dismissed = false;

  @override
  void initState() {
    super.initState();
    if (widget.debugBodyOverride != null) {
      _isAdLoaded = true;
      return;
    }
    unawaited(_startLoad());
  }

  Future<void> _startLoad() async {
    await resolveAikaAdManager().initialize();
    if (!mounted || _dismissed) {
      return;
    }
    _loadAd();
  }

  void _loadAd() {
    if (!resolveAikaAdManager().shouldShowAd(
      isLeanback: widget.isLeanback,
      isCasting: widget.isCasting,
    )) {
      return;
    }

    final colors = Theme.of(context).colorScheme;
    _nativeAd = NativeAd(
      adUnitId: aikaNativeAdUnitId,
      request: buildAikaAdRequest(),
      nativeTemplateStyle: NativeTemplateStyle(
        templateType: TemplateType.small,
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
          if (!mounted || _dismissed) {
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
          resolveAikaAdManager().recordAdImpression();
        },
      ),
    )..load();
  }

  void _dismiss() {
    _nativeAd?.dispose();
    _nativeAd = null;
    resolveAikaAdManager().recordAdImpression();
    setState(() {
      _dismissed = true;
      _isAdLoaded = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final debugBody = widget.debugBodyOverride;
    if (_dismissed ||
        !_isAdLoaded ||
        (_nativeAd == null && debugBody == null)) {
      return const SizedBox.shrink();
    }

    final colors = Theme.of(context).colorScheme;
    return Semantics(
      label: 'Advertisement',
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Align(
            alignment: Alignment.centerRight,
            child: IconButton(
              tooltip: 'Hide ad',
              visualDensity: VisualDensity.compact,
              onPressed: _dismiss,
              icon: Icon(Icons.close, size: 18, color: colors.onSurfaceVariant),
            ),
          ),
          SizedBox(
            height: AikaBrowseNativeAdCard.templateHeight,
            width: double.infinity,
            child: RepaintBoundary(
              child: _nativeAd != null ? AdWidget(ad: _nativeAd!) : debugBody!,
            ),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _nativeAd?.dispose();
    super.dispose();
  }
}
