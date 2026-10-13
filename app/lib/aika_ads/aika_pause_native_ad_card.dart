import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

import 'aika_ad_manager_binding.dart';
import 'aika_ad_personalization.dart';
import 'aika_ads.dart';

/// Pause-overlay native ad that respects the ads personalization consent.
class AikaPauseNativeAdCard extends StatefulWidget {
  const AikaPauseNativeAdCard({
    super.key,
    this.isLeanback = false,
    this.isCasting = false,
    @visibleForTesting this.debugBodyOverride,
  });

  final bool isLeanback;
  final bool isCasting;

  /// Skips Mobile Ads load and renders this body when set (widget tests only).
  @visibleForTesting
  final Widget? debugBodyOverride;

  @override
  State<AikaPauseNativeAdCard> createState() => _AikaPauseNativeAdCardState();
}

class _AikaPauseNativeAdCardState extends State<AikaPauseNativeAdCard> {
  NativeAd? _nativeAd;
  bool _isAdLoaded = false;
  bool _dismissed = false;

  Widget? get _debugBody => kDebugMode ? widget.debugBodyOverride : null;

  @override
  void initState() {
    super.initState();
    unawaited(_startLoad());
  }

  Future<void> _startLoad() async {
    await resolveAikaAdManager().initialize();
    if (!mounted) {
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

    final debugBody = _debugBody;
    if (debugBody != null) {
      setState(() => _isAdLoaded = true);
      return;
    }

    final colors = Theme.of(context).colorScheme;
    _nativeAd = NativeAd(
      adUnitId: aikaNativeAdUnitId,
      request: buildAikaAdRequest(),
      nativeTemplateStyle: NativeTemplateStyle(
        templateType: TemplateType.medium,
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
    final debugBody = _debugBody;
    if (_dismissed ||
        !_isAdLoaded ||
        (_nativeAd == null && debugBody == null)) {
      return const SizedBox.shrink();
    }

    final colors = Theme.of(context).colorScheme;

    return Semantics(
      label: 'Advertisement',
      child: Material(
        color: colors.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(12),
        clipBehavior: Clip.antiAlias,
        child: Stack(
          children: [
            SizedBox(
              height: 250,
              width: double.infinity,
              child: _nativeAd != null ? AdWidget(ad: _nativeAd!) : debugBody!,
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
