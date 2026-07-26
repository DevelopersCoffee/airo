import 'package:flutter/widgets.dart';

typedef AiroMemoryPressureRegistration =
    void Function(WidgetsBindingObserver observer);

/// Long-lived host observer that evicts decoded images under OS memory
/// pressure. Feature widgets must not each register their own listener.
class AiroMemoryPressureObserver with WidgetsBindingObserver {
  AiroMemoryPressureObserver({
    VoidCallback? onMemoryPressure,
    AiroMemoryPressureRegistration? register,
    AiroMemoryPressureRegistration? unregister,
  }) : _onMemoryPressure = onMemoryPressure ?? _clearImageCache,
       _unregister = unregister ?? WidgetsBinding.instance.removeObserver {
    (register ?? WidgetsBinding.instance.addObserver)(this);
  }

  final VoidCallback _onMemoryPressure;
  final AiroMemoryPressureRegistration _unregister;
  bool _disposed = false;

  @override
  void didHaveMemoryPressure() {
    if (_disposed) return;
    _onMemoryPressure();
  }

  void dispose() {
    if (_disposed) return;
    _disposed = true;
    _unregister(this);
  }

  static void _clearImageCache() {
    final cache = PaintingBinding.instance.imageCache;
    cache.clear();
    cache.clearLiveImages();
  }
}
