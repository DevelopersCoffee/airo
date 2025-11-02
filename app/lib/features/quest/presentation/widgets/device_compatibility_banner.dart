import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import '../../../../core/services/gemini_nano_service.dart';

/// Widget that displays device compatibility status for Gemini Nano
class DeviceCompatibilityBanner extends StatefulWidget {
  final Widget child;
  final bool showBanner;

  const DeviceCompatibilityBanner({
    Key? key,
    required this.child,
    this.showBanner = true,
  }) : super(key: key);

  @override
  State<DeviceCompatibilityBanner> createState() =>
      _DeviceCompatibilityBannerState();
}

class _DeviceCompatibilityBannerState extends State<DeviceCompatibilityBanner> {
  final GeminiNanoService _geminiNano = GeminiNanoService();
  bool _isSupported = false;
  bool _isLoading = true;
  DeviceInfo? _deviceInfo;

  @override
  void initState() {
    super.initState();
    _checkDeviceSupport();
  }

  Future<void> _checkDeviceSupport() async {
    try {
      final isSupported = await _geminiNano.isSupported();
      final deviceInfo = await _geminiNano.getDeviceInfo();

      setState(() {
        _isSupported = isSupported;
        _deviceInfo = deviceInfo;
        _isLoading = false;
      });
    } catch (e) {
      debugPrint('Error checking device support: $e');
      setState(() {
        _isSupported = false;
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.showBanner || _isLoading) {
      return widget.child;
    }

    if (_isSupported) {
      // Device is supported - show success banner
      return Column(
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            color: Colors.green.shade100,
            child: Row(
              children: [
                Icon(Icons.check_circle, color: Colors.green.shade700),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Gemini Nano Ready',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Colors.green.shade700,
                        ),
                      ),
                      Text(
                        'On-device AI is available on this device',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.green.shade600,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Expanded(child: widget.child),
        ],
      );
    } else {
      // Device not supported - show warning banner
      return Column(
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            color: Colors.orange.shade100,
            child: Row(
              children: [
                Icon(Icons.warning, color: Colors.orange.shade700),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Gemini Nano Not Available',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Colors.orange.shade700,
                        ),
                      ),
                      Text(
                        _getCompatibilityMessage(),
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.orange.shade600,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Expanded(child: widget.child),
        ],
      );
    }
  }

  String _getCompatibilityMessage() {
    if (_deviceInfo == null) {
      return 'Unable to check device compatibility';
    }

    if (!_deviceInfo!.isPixel9Series) {
      return 'Requires Pixel 9 series device';
    }

    if (!_deviceInfo!.isAiCoreAvailable) {
      return 'AICore module not installed';
    }

    return 'Device not compatible';
  }
}

/// Dialog showing detailed device information
class DeviceInfoDialog extends StatefulWidget {
  const DeviceInfoDialog({Key? key}) : super(key: key);

  @override
  State<DeviceInfoDialog> createState() => _DeviceInfoDialogState();
}

class _DeviceInfoDialogState extends State<DeviceInfoDialog> {
  final GeminiNanoService _geminiNano = GeminiNanoService();
  bool _isLoading = true;
  DeviceInfo? _deviceInfo;
  bool _isSupported = false;

  @override
  void initState() {
    super.initState();
    _loadDeviceInfo();
  }

  Future<void> _loadDeviceInfo() async {
    try {
      final deviceInfo = await _geminiNano.getDeviceInfo();
      final isSupported = await _geminiNano.isSupported();

      setState(() {
        _deviceInfo = deviceInfo;
        _isSupported = isSupported;
        _isLoading = false;
      });
    } catch (e) {
      debugPrint('Error loading device info: $e');
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Device Information'),
      content: _isLoading
          ? const SizedBox(
              height: 100,
              child: Center(child: CircularProgressIndicator()),
            )
          : _deviceInfo == null
          ? const Text('Unable to load device information')
          : SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildInfoRow('Manufacturer', _deviceInfo!.manufacturer),
                  _buildInfoRow('Model', _deviceInfo!.model),
                  _buildInfoRow('Android Version', _deviceInfo!.androidVersion),
                  _buildInfoRow(
                    'Pixel 9 Series',
                    _deviceInfo!.isPixel9Series ? '✓ Yes' : '✗ No',
                    _deviceInfo!.isPixel9Series ? Colors.green : Colors.red,
                  ),
                  _buildInfoRow(
                    'AICore Available',
                    _deviceInfo!.isAiCoreAvailable ? '✓ Yes' : '✗ No',
                    _deviceInfo!.isAiCoreAvailable ? Colors.green : Colors.red,
                  ),
                  _buildInfoRow(
                    'Gemini Nano Support',
                    _isSupported ? '✓ Supported' : '✗ Not Supported',
                    _isSupported ? Colors.green : Colors.red,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Status: ${_deviceInfo!.compatibilityStatus}',
                    style: const TextStyle(
                      fontSize: 12,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ],
              ),
            ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Close'),
        ),
      ],
    );
  }

  Widget _buildInfoRow(String label, String value, [Color? valueColor]) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(fontWeight: FontWeight.w500)),
          Text(value, style: TextStyle(color: valueColor)),
        ],
      ),
    );
  }
}
