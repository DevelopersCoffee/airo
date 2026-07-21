import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'vault_config.dart';

/// Clipboard access for vault secrets. Every copy schedules a
/// compare-and-clear: after [VaultConfig.clipboardClearDuration] the clipboard
/// is wiped only if it still holds the value we put there, so a newer user copy
/// is never destroyed.
class ClipboardService {
  ClipboardService({
    Future<void> Function(ClipboardData data)? setData,
    Future<ClipboardData?> Function()? getData,
  }) : _setData = setData ?? Clipboard.setData,
       _getData = getData ?? (() => Clipboard.getData(Clipboard.kTextPlain));

  final Future<void> Function(ClipboardData data) _setData;
  final Future<ClipboardData?> Function() _getData;
  Timer? _clearTimer;
  Future<void> _writeQueue = Future<void>.value();
  var _copyGeneration = 0;
  var _disposed = false;

  Future<void> copyWithAutoClear(String text, {Duration? clearAfter}) {
    if (_disposed) return Future<void>.value();

    final copyGeneration = ++_copyGeneration;
    _clearTimer?.cancel();
    _clearTimer = null;

    final queuedCopy = _enqueueWrite(() async {
      if (!_isCurrentCopy(copyGeneration)) return;

      await _setData(ClipboardData(text: text));
      if (!_isCurrentCopy(copyGeneration)) return;

      _clearTimer = Timer(
        clearAfter ?? VaultConfig.clipboardClearDuration,
        () => unawaited(_clearIfUnchanged(text, copyGeneration)),
      );
    });
    return queuedCopy;
  }

  Future<void> _clearIfUnchanged(String copiedText, int copyGeneration) async {
    if (!_isCurrentCopy(copyGeneration)) return;

    try {
      final current = await _getData();
      if (!_isCurrentCopy(copyGeneration)) return;

      if (current?.text == copiedText) {
        await _enqueueWrite(() async {
          if (!_isCurrentCopy(copyGeneration)) return;

          final latest = await _getData();
          if (!_isCurrentCopy(copyGeneration)) return;

          if (latest?.text == copiedText) {
            await _setData(const ClipboardData(text: ''));
          }
        });
      }
    } catch (_) {
      // Clipboard platform failures happen after the timer fires and should not
      // surface as unhandled async errors from this cleanup path.
    }
  }

  Future<void> _enqueueWrite(Future<void> Function() write) {
    final queuedWrite = _writeQueue.then((_) => write());
    _writeQueue = queuedWrite.catchError((Object _) {});
    return queuedWrite;
  }

  bool _isCurrentCopy(int copyGeneration) =>
      !_disposed && _copyGeneration == copyGeneration;

  void dispose() {
    if (_disposed) return;
    _disposed = true;
    _copyGeneration++;
    _clearTimer?.cancel();
    _clearTimer = null;
  }
}

final clipboardServiceProvider = Provider<ClipboardService>((ref) {
  final service = ClipboardService();
  ref.onDispose(service.dispose);
  return service;
});
