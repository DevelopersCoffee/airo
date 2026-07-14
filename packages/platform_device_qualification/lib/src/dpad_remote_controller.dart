import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class DpadRemoteController extends StatelessWidget {
  final VoidCallback? onBackPress;

  const DpadRemoteController({
    super.key,
    this.onBackPress,
  });

  void _sendKey(LogicalKeyboardKey logicalKey) {
    final physicalKey = _mapLogicalToPhysical(logicalKey);
    if (physicalKey == null) return;
    final timeStamp = Duration(milliseconds: DateTime.now().millisecondsSinceEpoch);

    // Modern Flutter key event simulation
    // Send KeyDownEvent
    HardwareKeyboard.instance.handleKeyEvent(
      KeyDownEvent(
        physicalKey: physicalKey,
        logicalKey: logicalKey,
        timeStamp: timeStamp,
      ),
    );

    // Send KeyUpEvent shortly after to simulate a tap
    Future.delayed(const Duration(milliseconds: 50), () {
      HardwareKeyboard.instance.handleKeyEvent(
        KeyUpEvent(
          physicalKey: physicalKey,
          logicalKey: logicalKey,
          timeStamp: timeStamp + const Duration(milliseconds: 50),
        ),
      );
    });
  }

  PhysicalKeyboardKey? _mapLogicalToPhysical(LogicalKeyboardKey key) {
    if (key == LogicalKeyboardKey.arrowUp) return PhysicalKeyboardKey.arrowUp;
    if (key == LogicalKeyboardKey.arrowDown) return PhysicalKeyboardKey.arrowDown;
    if (key == LogicalKeyboardKey.arrowLeft) return PhysicalKeyboardKey.arrowLeft;
    if (key == LogicalKeyboardKey.arrowRight) return PhysicalKeyboardKey.arrowRight;
    if (key == LogicalKeyboardKey.enter) return PhysicalKeyboardKey.enter;
    if (key == LogicalKeyboardKey.escape) return PhysicalKeyboardKey.escape;
    if (key == LogicalKeyboardKey.space) return PhysicalKeyboardKey.space;
    if (key == LogicalKeyboardKey.f1) return PhysicalKeyboardKey.f1;
    return null;
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 200,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.grey[900]?.withOpacity(0.95),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.grey[800]!, width: 2),
        boxShadow: const [
          BoxShadow(
            color: Colors.black45,
            blurRadius: 10,
            spreadRadius: 2,
          ),
        ],
      ),
      child: Material(
        type: MaterialType.transparency,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Top buttons: Power (toggle overlay) and Back
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _IconButton(
                  icon: Icons.power_settings_new,
                  color: Colors.redAccent,
                  tooltip: 'Hide Remote',
                  onTap: onBackPress ?? () {},
                ),
                const Text(
                  'Airo TV Remote',
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                _IconButton(
                  icon: Icons.keyboard_return,
                  tooltip: 'Back / Escape',
                  onTap: () => _sendKey(LogicalKeyboardKey.escape),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // D-pad Ring
            SizedBox(
              width: 150,
              height: 150,
              child: Stack(
                children: [
                  // D-pad Background Circle
                  Positioned.fill(
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.grey[800],
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.grey[700]!, width: 1),
                      ),
                    ),
                  ),

                  // Up Button
                  Align(
                    alignment: Alignment.topCenter,
                    child: _DpadButton(
                      icon: Icons.arrow_drop_up,
                      onTap: () => _sendKey(LogicalKeyboardKey.arrowUp),
                    ),
                  ),

                  // Down Button
                  Align(
                    alignment: Alignment.bottomCenter,
                    child: _DpadButton(
                      icon: Icons.arrow_drop_down,
                      onTap: () => _sendKey(LogicalKeyboardKey.arrowDown),
                    ),
                  ),

                  // Left Button
                  Align(
                    alignment: Alignment.centerLeft,
                    child: _DpadButton(
                      icon: Icons.arrow_left,
                      onTap: () => _sendKey(LogicalKeyboardKey.arrowLeft),
                    ),
                  ),

                  // Right Button
                  Align(
                    alignment: Alignment.centerRight,
                    child: _DpadButton(
                      icon: Icons.arrow_right,
                      onTap: () => _sendKey(LogicalKeyboardKey.arrowRight),
                    ),
                  ),

                  // Select (Center) Button
                  Align(
                    alignment: Alignment.center,
                    child: GestureDetector(
                      onTap: () => _sendKey(LogicalKeyboardKey.enter),
                      child: Container(
                        width: 56,
                        height: 56,
                        decoration: BoxDecoration(
                          color: Colors.grey[900],
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: Colors.grey[750]!,
                            width: 2,
                          ),
                          boxShadow: const [
                            BoxShadow(
                              color: Colors.black26,
                              blurRadius: 4,
                              offset: Offset(0, 2),
                            ),
                          ],
                        ),
                        child: const Center(
                          child: Text(
                            'OK',
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),

            // Navigation/Media Control Buttons Row
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                // Menu button
                _TextButton(
                  text: 'MENU',
                  onTap: () => _sendKey(LogicalKeyboardKey.f1),
                ),
                // Play/Pause button
                _IconButton(
                  icon: Icons.play_arrow,
                  tooltip: 'Play/Pause',
                  onTap: () => _sendKey(LogicalKeyboardKey.space),
                ),
                // Home button
                _IconButton(
                  icon: Icons.home,
                  tooltip: 'Home',
                  onTap: () => _sendKey(LogicalKeyboardKey.home),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _IconButton extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;
  final Color? color;

  const _IconButton({
    required this.icon,
    required this.tooltip,
    required this.onTap,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(100),
        child: Container(
          padding: const EdgeInsets.all(8),
          child: Icon(
            icon,
            color: color ?? Colors.white,
            size: 20,
          ),
        ),
      ),
    );
  }
}

class _TextButton extends StatelessWidget {
  final String text;
  final VoidCallback onTap;

  const _TextButton({
    required this.text,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          border: Border.all(color: Colors.white24),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(
          text,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 9,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }
}

class _DpadButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;

  const _DpadButton({
    required this.icon,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(100),
      child: Container(
        width: 44,
        height: 44,
        child: Icon(
          icon,
          color: Colors.white,
          size: 32,
        ),
      ),
    );
  }
}
