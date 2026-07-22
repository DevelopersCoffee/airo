import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class IptvResumeSplash extends StatefulWidget {
  const IptvResumeSplash({
    super.key,
    required this.playbackReady,
    required this.onFinished,
    this.minDisplay = const Duration(seconds: 3),
    this.maxDisplay = const Duration(seconds: 6),
  });

  final bool playbackReady;
  final VoidCallback onFinished;
  final Duration minDisplay;
  final Duration maxDisplay;

  @override
  State<IptvResumeSplash> createState() => _IptvResumeSplashState();
}

class _IptvResumeSplashState extends State<IptvResumeSplash> {
  Timer? _minTimer;
  Timer? _capTimer;
  var _minElapsed = false;
  var _finished = false;

  @override
  void initState() {
    super.initState();
    _minTimer = Timer(widget.minDisplay, () {
      _minElapsed = true;
      _finishIfReady();
    });
    _capTimer = Timer(widget.maxDisplay, _finish);
  }

  @override
  void didUpdateWidget(IptvResumeSplash oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.playbackReady && !oldWidget.playbackReady) _finishIfReady();
  }

  void _finishIfReady() {
    if (_minElapsed && widget.playbackReady) _finish();
  }

  void _finish() {
    if (_finished) return;
    _finished = true;
    _minTimer?.cancel();
    _capTimer?.cancel();
    widget.onFinished();
  }

  @override
  void dispose() {
    _minTimer?.cancel();
    _capTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Focus(
      autofocus: true,
      onKeyEvent: (_, __) {
        _finish();
        return KeyEventResult.handled;
      },
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: _finish,
        child: DecoratedBox(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Color(0xFF05060F), Color(0xFF141B33)],
            ),
          ),
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Airo TV',
                  style: Theme.of(context).textTheme.headlineLarge?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 24),
                const SizedBox(
                  width: 28,
                  height: 28,
                  child: CircularProgressIndicator(strokeWidth: 2.5),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
