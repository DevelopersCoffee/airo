import 'package:flutter/material.dart';

enum SimulatedDevice {
  native(
    name: 'Native (Full Screen)',
    width: 0,
    height: 0,
    isTv: false,
  ),
  androidTv720p(
    name: 'Android TV 720p',
    width: 1280,
    height: 720,
    isTv: true,
  ),
  androidTv1080p(
    name: 'Android TV 1080p',
    width: 1920,
    height: 1080,
    isTv: true,
  ),
  fireTvStick(
    name: 'Fire TV Stick',
    width: 1920,
    height: 1080,
    isTv: true,
  ),
  googleTv4k(
    name: 'Google TV 4K',
    width: 3840,
    height: 2160,
    isTv: true,
  ),
  shieldTv4k(
    name: 'Shield TV 4K',
    width: 3840,
    height: 2160,
    isTv: true,
  ),
  tabletLandscape(
    name: 'Tablet Landscape (iPad)',
    width: 1024,
    height: 768,
    isTv: false,
  ),
  foldablePortrait(
    name: 'Foldable Portrait',
    width: 673,
    height: 841,
    isTv: false,
  ),
  foldableLandscape(
    name: 'Foldable Landscape',
    width: 841,
    height: 673,
    isTv: false,
  );

  final String name;
  final double width;
  final double height;
  final bool isTv;

  const SimulatedDevice({
    required this.name,
    required this.width,
    required this.height,
    required this.isTv,
  });

  bool get isNative => this == SimulatedDevice.native;
}

class ResolutionSimulator extends StatelessWidget {
  final Widget child;
  final SimulatedDevice device;
  final bool showBezel;

  const ResolutionSimulator({
    super.key,
    required this.child,
    required this.device,
    this.showBezel = true,
  });

  @override
  Widget build(BuildContext context) {
    if (device.isNative) {
      return child;
    }

    final simulatedSize = Size(device.width, device.height);

    return LayoutBuilder(
      builder: (context, constraints) {
        final parentSize = constraints.biggest;

        // Calculate aspect ratios
        final double parentAspect = parentSize.width / parentSize.height;
        final double targetAspect = simulatedSize.width / simulatedSize.height;

        double scale = 1.0;
        if (targetAspect > parentAspect) {
          // Limited by width
          scale = parentSize.width / simulatedSize.width;
        } else {
          // Limited by height
          scale = parentSize.height / simulatedSize.height;
        }

        // Apply a small margin so the simulated screen doesn't touch the edges
        final double marginFactor = showBezel ? 0.90 : 1.0;
        scale *= marginFactor;

        final double finalWidth = simulatedSize.width * scale;
        final double finalHeight = simulatedSize.height * scale;

        return Container(
          color: Colors.grey[950],
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (showBezel) ...[
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8.0),
                    child: Text(
                      '${device.name} (${device.width.toInt()} × ${device.height.toInt()})',
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        decoration: TextDecoration.none,
                      ),
                    ),
                  ),
                ],
                Container(
                  width: finalWidth,
                  height: finalHeight,
                  decoration: BoxDecoration(
                    color: Colors.black,
                    boxShadow: showBezel
                        ? [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.6),
                              blurRadius: 16,
                              spreadRadius: 2,
                            ),
                          ]
                        : null,
                    border: showBezel
                        ? Border.all(color: Colors.grey[800]!, width: 4)
                        : null,
                  ),
                  child: ClipRect(
                    child: FittedBox(
                      fit: BoxFit.contain,
                      child: SizedBox(
                        width: simulatedSize.width,
                        height: simulatedSize.height,
                        child: MediaQuery(
                          data: MediaQuery.of(context).copyWith(
                            size: simulatedSize,
                            padding: EdgeInsets.zero,
                            viewPadding: EdgeInsets.zero,
                            viewInsets: EdgeInsets.zero,
                            navigationMode: device.isTv
                                ? NavigationMode.directional
                                : NavigationMode.traditional,
                          ),
                          child: child,
                        ),
                      ),
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
}
