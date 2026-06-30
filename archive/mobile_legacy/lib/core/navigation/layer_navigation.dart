import 'package:flutter/material.dart';

/// Layer-based modular navigation system
///
/// Rules:
/// - App has one main shell
/// - Each section is a module loaded when tapped
/// - Module opens as a layer at bottom (sheet or overlay), not a new app
/// - Screen history is stored as a stack
/// - Back button removes the top layer and shows the previous one
/// - UI and data of modules load only when needed (lazy load)

/// Layer type for different presentation styles
enum LayerType {
  /// Bottom sheet that slides up from bottom
  bottomSheet,

  /// Full screen overlay
  fullScreen,

  /// Dialog overlay
  dialog,

  /// Drawer from side
  drawer,
}

/// Layer configuration
class LayerConfig {
  final String id;
  final String title;
  final LayerType type;
  final Widget Function(BuildContext context) builder;
  final bool isDismissible;
  final bool enableDrag;
  final double? initialChildSize;
  final double? minChildSize;
  final double? maxChildSize;

  const LayerConfig({
    required this.id,
    required this.title,
    required this.builder,
    this.type = LayerType.bottomSheet,
    this.isDismissible = true,
    this.enableDrag = true,
    this.initialChildSize = 0.9,
    this.minChildSize = 0.5,
    this.maxChildSize = 0.95,
  });
}

/// Layer navigation controller
class LayerNavigationController extends ChangeNotifier {
  final List<LayerConfig> _layerStack = [];

  /// Get current layer stack
  List<LayerConfig> get layerStack => List.unmodifiable(_layerStack);

  /// Get current layer
  LayerConfig? get currentLayer =>
      _layerStack.isEmpty ? null : _layerStack.last;

  /// Check if any layers are open
  bool get hasLayers => _layerStack.isNotEmpty;

  /// Push a new layer onto the stack
  void pushLayer(LayerConfig config) {
    _layerStack.add(config);
    notifyListeners();
  }

  /// Pop the top layer from the stack
  void popLayer() {
    if (_layerStack.isNotEmpty) {
      _layerStack.removeLast();
      notifyListeners();
    }
  }

  /// Pop all layers
  void popAllLayers() {
    _layerStack.clear();
    notifyListeners();
  }

  /// Pop to a specific layer by id
  void popToLayer(String layerId) {
    final index = _layerStack.indexWhere((layer) => layer.id == layerId);
    if (index != -1) {
      _layerStack.removeRange(index + 1, _layerStack.length);
      notifyListeners();
    }
  }

  /// Replace current layer
  void replaceLayer(LayerConfig config) {
    if (_layerStack.isNotEmpty) {
      _layerStack.removeLast();
    }
    _layerStack.add(config);
    notifyListeners();
  }
}

/// Layer navigation widget
class LayerNavigation extends StatefulWidget {
  final Widget child;
  final LayerNavigationController controller;

  const LayerNavigation({
    super.key,
    required this.child,
    required this.controller,
  });

  @override
  State<LayerNavigation> createState() => _LayerNavigationState();
}

class _LayerNavigationState extends State<LayerNavigation> {
  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_onLayerChanged);
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onLayerChanged);
    super.dispose();
  }

  void _onLayerChanged() {
    if (widget.controller.hasLayers) {
      _showLayer(widget.controller.currentLayer!);
    }
  }

  void _showLayer(LayerConfig config) {
    switch (config.type) {
      case LayerType.bottomSheet:
        _showBottomSheet(config);
        break;
      case LayerType.fullScreen:
        _showFullScreen(config);
        break;
      case LayerType.dialog:
        _showDialog(config);
        break;
      case LayerType.drawer:
        _showDrawer(config);
        break;
    }
  }

  void _showBottomSheet(LayerConfig config) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      isDismissible: config.isDismissible,
      enableDrag: config.enableDrag,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: config.initialChildSize ?? 0.9,
        minChildSize: config.minChildSize ?? 0.5,
        maxChildSize: config.maxChildSize ?? 0.95,
        expand: false,
        builder: (context, scrollController) => Column(
          children: [
            // Handle bar
            Container(
              margin: const EdgeInsets.symmetric(vertical: 8),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            // Header
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                children: [
                  if (widget.controller.layerStack.length > 1)
                    IconButton(
                      icon: const Icon(Icons.arrow_back),
                      onPressed: () {
                        Navigator.of(context).pop();
                        widget.controller.popLayer();
                      },
                    ),
                  Expanded(
                    child: Text(
                      config.title,
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () {
                      Navigator.of(context).pop();
                      widget.controller.popAllLayers();
                    },
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            // Content
            Expanded(child: config.builder(context)),
          ],
        ),
      ),
    ).then((_) {
      // Clean up when sheet is dismissed
      if (widget.controller.currentLayer?.id == config.id) {
        widget.controller.popLayer();
      }
    });
  }

  void _showFullScreen(LayerConfig config) {
    Navigator.of(context)
        .push(
          MaterialPageRoute(
            fullscreenDialog: true,
            builder: (context) => Scaffold(
              appBar: AppBar(
                title: Text(config.title),
                leading: widget.controller.layerStack.length > 1
                    ? IconButton(
                        icon: const Icon(Icons.arrow_back),
                        onPressed: () {
                          Navigator.of(context).pop();
                          widget.controller.popLayer();
                        },
                      )
                    : null,
                actions: [
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () {
                      Navigator.of(context).pop();
                      widget.controller.popAllLayers();
                    },
                  ),
                ],
              ),
              body: config.builder(context),
            ),
          ),
        )
        .then((_) {
          if (widget.controller.currentLayer?.id == config.id) {
            widget.controller.popLayer();
          }
        });
  }

  void _showDialog(LayerConfig config) {
    showDialog(
      context: context,
      barrierDismissible: config.isDismissible,
      builder: (context) => AlertDialog(
        title: Text(config.title),
        content: config.builder(context),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              widget.controller.popLayer();
            },
            child: const Text('Close'),
          ),
        ],
      ),
    ).then((_) {
      if (widget.controller.currentLayer?.id == config.id) {
        widget.controller.popLayer();
      }
    });
  }

  void _showDrawer(LayerConfig config) {
    showModalBottomSheet(
      context: context,
      builder: (context) => Drawer(
        child: Column(
          children: [
            DrawerHeader(
              child: Text(config.title, style: const TextStyle(fontSize: 24)),
            ),
            Expanded(child: config.builder(context)),
          ],
        ),
      ),
    ).then((_) {
      if (widget.controller.currentLayer?.id == config.id) {
        widget.controller.popLayer();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return widget.child;
  }
}
