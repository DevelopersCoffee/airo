import 'dart:async';

import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

import 'aika_ads.dart';

/// Browse-grid Native card that fills the library cell.
///
/// Hosted [AikaNativeAdCard] hardcodes a 120px `TemplateType.small` banner.
/// Phone list cells are 88px and compact grid posters are 128px, so that
/// banner either clips or sits in a hole. This card loads against the parent
/// constraints and reloads when list ↔ grid changes the cell size.
class AikaBrowseNativeAdCard extends StatefulWidget {
  const AikaBrowseNativeAdCard({
    super.key,
    this.isLeanback = false,
    this.isCasting = false,
  });

  final bool isLeanback;
  final bool isCasting;

  @override
  State<AikaBrowseNativeAdCard> createState() => _AikaBrowseNativeAdCardState();
}

class _AikaBrowseNativeAdCardState extends State<AikaBrowseNativeAdCard> {
  NativeAd? _nativeAd;
  bool _isAdLoaded = false;
  bool _dismissed = false;
  Size? _loadedFor;
  Size? _loadQueuedFor;

  @override
  void initState() {
    super.initState();
    unawaited(AikaAdManager.instance.initialize());
  }

  Size? _cellSize(BoxConstraints constraints) {
    final width = constraints.maxWidth;
    final height = constraints.maxHeight;
    if (!width.isFinite || !height.isFinite || width <= 0 || height <= 0) {
      return null;
    }
    return Size(width, height);
  }

  bool _sameCell(Size a, Size b) {
    return (a.width - b.width).abs() < 8 && (a.height - b.height).abs() < 8;
  }

  void _queueLoad(Size size) {
    if (_loadQueuedFor != null && _sameCell(_loadQueuedFor!, size)) {
      return;
    }
    if (_loadedFor != null &&
        _sameCell(_loadedFor!, size) &&
        _nativeAd != null) {
      return;
    }
    _loadQueuedFor = size;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final queued = _loadQueuedFor;
      if (queued == null) return;
      unawaited(_loadAd(queued));
    });
  }

  Future<void> _loadAd(Size size) async {
    await AikaAdManager.instance.initialize();
    if (!mounted) return;
    if (_dismissed) return;
    if (_loadedFor != null &&
        _sameCell(_loadedFor!, size) &&
        _nativeAd != null) {
      return;
    }
    if (!AikaAdManager.instance.shouldShowAd(
      isLeanback: widget.isLeanback,
      isCasting: widget.isCasting,
    )) {
      return;
    }

    _nativeAd?.dispose();
    _nativeAd = null;
    _isAdLoaded = false;
    _loadedFor = size;

    final colors = Theme.of(context).colorScheme;
    final ad = NativeAd(
      adUnitId: aikaNativeAdUnitId,
      request: const AdRequest(),
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
        onAdLoaded: (loaded) {
          if (!mounted || _dismissed) {
            loaded.dispose();
            return;
          }
          setState(() {
            _nativeAd = loaded as NativeAd;
            _isAdLoaded = true;
          });
        },
        onAdFailedToLoad: (failed, error) {
          failed.dispose();
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
    );
    await ad.load();
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
    if (_dismissed) {
      return const SizedBox.shrink();
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final size = _cellSize(constraints);
        if (size != null) {
          _queueLoad(size);
        }

        final colors = Theme.of(context).colorScheme;
        if (!_isAdLoaded || _nativeAd == null) {
          return DecoratedBox(
            decoration: BoxDecoration(
              color: colors.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(12),
            ),
          );
        }

        return Semantics(
          label: 'Advertisement',
          child: Material(
            color: colors.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(12),
            clipBehavior: Clip.antiAlias,
            child: Stack(
              fit: StackFit.expand,
              children: [
                AdWidget(ad: _nativeAd!),
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
      },
    );
  }

  @override
  void dispose() {
    _nativeAd?.dispose();
    super.dispose();
  }
}
