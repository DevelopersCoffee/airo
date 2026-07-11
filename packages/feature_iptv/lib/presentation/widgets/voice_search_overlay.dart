import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../application/providers/iptv_providers.dart';
import '../voice/voice_search_service.dart';

/// Voice search overlay that appears when voice search is triggered on Fire TV
class VoiceSearchOverlay extends ConsumerStatefulWidget {
  /// Callback when voice search completes with a result
  final ValueChanged<String>? onSearchComplete;

  /// Callback when overlay is dismissed
  final VoidCallback? onDismiss;

  const VoiceSearchOverlay({super.key, this.onSearchComplete, this.onDismiss});

  @override
  ConsumerState<VoiceSearchOverlay> createState() => _VoiceSearchOverlayState();
}

class _VoiceSearchOverlayState extends ConsumerState<VoiceSearchOverlay>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _pulseAnimation;
  String? _recognizedText;
  bool _isListening = false;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat(reverse: true);

    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.3).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeInOut),
    );

    // Start listening when overlay appears
    _startListening();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  Future<void> _startListening() async {
    setState(() {
      _isListening = true;
      _recognizedText = null;
    });

    final service = ref.read(voiceSearchServiceProvider);
    final result = await service.startListening();

    if (!mounted) return;

    setState(() {
      _isListening = false;
      _recognizedText = result.text;
    });

    if (result.isSuccess && result.text != null && result.text!.isNotEmpty) {
      // Apply search query
      ref.read(channelSearchQueryProvider.notifier).state = result.text!;
      widget.onSearchComplete?.call(result.text!);
    }

    // Auto-dismiss after showing result
    await Future<void>.delayed(const Duration(seconds: 1));
    if (mounted) {
      widget.onDismiss?.call();
    }
  }

  void _cancelSearch() {
    final service = ref.read(voiceSearchServiceProvider);
    service.stopListening();
    widget.onDismiss?.call();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Material(
      color: Colors.black.withValues(alpha: 0.85),
      child: SafeArea(
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Voice search icon with pulse animation
              AnimatedBuilder(
                animation: _pulseAnimation,
                builder: (context, child) {
                  return Transform.scale(
                    scale: _isListening ? _pulseAnimation.value : 1.0,
                    child: Container(
                      width: 120,
                      height: 120,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: _isListening
                            ? theme.colorScheme.primary
                            : theme.colorScheme.surface,
                        boxShadow: _isListening
                            ? [
                                BoxShadow(
                                  color: theme.colorScheme.primary.withValues(
                                    alpha: 0.5,
                                  ),
                                  blurRadius: 30,
                                  spreadRadius: 10,
                                ),
                              ]
                            : null,
                      ),
                      child: Icon(
                        _isListening ? Icons.mic : Icons.mic_off,
                        size: 64,
                        color: _isListening
                            ? theme.colorScheme.onPrimary
                            : theme.colorScheme.onSurface,
                      ),
                    ),
                  );
                },
              ),
              const SizedBox(height: 32),

              // Status text
              Text(
                _isListening
                    ? 'Listening...'
                    : _recognizedText != null
                    ? 'Searching for "$_recognizedText"'
                    : 'No speech detected',
                style: theme.textTheme.headlineSmall?.copyWith(
                  color: Colors.white,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),

              // Hint text
              Text(
                _isListening
                    ? 'Say a channel name to search'
                    : 'Press Back to cancel',
                style: theme.textTheme.bodyLarge?.copyWith(
                  color: Colors.white70,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 48),

              // Cancel button (focusable for D-pad)
              Focus(
                autofocus: true,
                child: Builder(
                  builder: (context) {
                    final hasFocus = Focus.of(context).hasFocus;
                    return ElevatedButton.icon(
                      onPressed: _cancelSearch,
                      icon: const Icon(Icons.close),
                      label: const Text('Cancel'),
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 32,
                          vertical: 16,
                        ),
                        backgroundColor: hasFocus
                            ? theme.colorScheme.primary
                            : theme.colorScheme.surface,
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Voice search overlay controller for managing overlay state
class VoiceSearchOverlayController extends ChangeNotifier {
  bool _isVisible = false;

  bool get isVisible => _isVisible;

  void show() {
    _isVisible = true;
    notifyListeners();
  }

  void hide() {
    _isVisible = false;
    notifyListeners();
  }

  void toggle() {
    _isVisible = !_isVisible;
    notifyListeners();
  }
}

/// Provider for voice search overlay controller
final voiceSearchOverlayControllerProvider =
    ChangeNotifierProvider<VoiceSearchOverlayController>((ref) {
      return VoiceSearchOverlayController();
    });
