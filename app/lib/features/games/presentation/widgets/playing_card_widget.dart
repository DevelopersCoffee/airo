import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../application/card_asset_manager.dart';
import '../../domain/models/card_model.dart';

/// Animated playing card widget
class PlayingCardWidget extends ConsumerStatefulWidget {
  final CardModel card;
  final bool isHidden;
  final Duration delay;
  final double width;
  final double height;

  const PlayingCardWidget({
    super.key,
    required this.card,
    this.isHidden = false,
    this.delay = Duration.zero,
    this.width = 90,
    this.height = 130,
  });

  @override
  ConsumerState<PlayingCardWidget> createState() => _PlayingCardWidgetState();
}

class _PlayingCardWidgetState extends ConsumerState<PlayingCardWidget>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;
  late Animation<double> _rotationAnimation;

  @override
  void initState() {
    super.initState();
    
    _controller = AnimationController(
      duration: const Duration(milliseconds: 500),
      vsync: this,
    );

    _scaleAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: Curves.elasticOut,
    ));

    _rotationAnimation = Tween<double>(
      begin: 0.5,
      end: 0.0,
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOut,
    ));

    // Start animation after delay
    Future.delayed(widget.delay, () {
      if (mounted) {
        _controller.forward();
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final assetManager = ref.watch(cardAssetManagerProvider);

    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return Transform.scale(
          scale: _scaleAnimation.value,
          child: Transform.rotate(
            angle: _rotationAnimation.value,
            child: child,
          ),
        );
      },
      child: Container(
        width: widget.width,
        height: widget.height,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(8),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.3),
              blurRadius: 8,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: widget.isHidden
              ? assetManager.buildCardBack(
                  width: widget.width,
                  height: widget.height,
                  fit: BoxFit.cover,
                )
              : assetManager.buildCardImage(
                  imageUrl: widget.card.image,
                  width: widget.width,
                  height: widget.height,
                  fit: BoxFit.cover,
                ),
        ),
      ),
    );
  }
}

/// Simple card widget without animation (for static displays)
class SimpleCardWidget extends ConsumerWidget {
  final CardModel card;
  final bool isHidden;
  final double width;
  final double height;

  const SimpleCardWidget({
    super.key,
    required this.card,
    this.isHidden = false,
    this.width = 90,
    this.height = 130,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final assetManager = ref.watch(cardAssetManagerProvider);

    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.2),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: isHidden
            ? assetManager.buildCardBack(
                width: width,
                height: height,
                fit: BoxFit.cover,
              )
            : assetManager.buildCardImage(
                imageUrl: card.image,
                width: width,
                height: height,
                fit: BoxFit.cover,
              ),
      ),
    );
  }
}

