import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import '../../../../core/services/gemini_nano_service.dart';

/// Widget that displays device compatibility status for Gemini Nano
class DeviceCompatibilityBanner extends StatefulWidget {
  final Widget child;
  final bool showBanner;

  const DeviceCompatibilityBanner({
    super.key,
    required this.child,
    this.showBanner = true,
  });

  @override
  State<DeviceCompatibilityBanner> createState() =>
      _DeviceCompatibilityBannerState();
}

class _DeviceCompatibilityBannerState extends State<DeviceCompatibilityBanner> {
  final GeminiNanoService _geminiNano = GeminiNanoService();
  bool _isSupported = false;
  bool _isLoading = true;
  bool _showBanner = true;
  Map<String, dynamic>? _deviceInfo;

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
        _showBanner = true;
      });

      // Auto-dismiss banner after 3 seconds
      Future.delayed(const Duration(seconds: 3), () {
        if (mounted) {
          setState(() {
            _showBanner = false;
          });
        }
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
    if (!widget.showBanner || _isLoading || !_showBanner) {
      return widget.child;
    }

    if (_isSupported) {
      // Device is supported - show success banner with optimized message
      return Column(
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            color: Colors.green.shade100,
            child: Row(
              children: [
                Icon(Icons.phone_android, color: Colors.green.shade700),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Optimized for Your Device',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Colors.green.shade700,
                        ),
                      ),
                      Text(
                        'On-device AI ready • Fast & Private',
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
                Icon(Icons.cloud, color: Colors.orange.shade700),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Cloud AI Mode',
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

    final isPixel = _deviceInfo!['isPixel'] as bool? ?? false;
    final supportsNano = _deviceInfo!['supportsGeminiNano'] as bool? ?? false;

    if (!isPixel) {
      return 'Requires Pixel 9 series device';
    }

    if (!supportsNano) {
      return 'AICore module not installed';
    }

    return 'Device not compatible';
  }
}

/// Dialog showing detailed device information
class DeviceInfoDialog extends StatefulWidget {
  const DeviceInfoDialog({super.key});

  @override
  State<DeviceInfoDialog> createState() => _DeviceInfoDialogState();
}

class _DeviceInfoDialogState extends State<DeviceInfoDialog> {
  final GeminiNanoService _geminiNano = GeminiNanoService();
  bool _isLoading = true;
  Map<String, dynamic>? _deviceInfo;
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
                  _buildInfoRow(
                    'Manufacturer',
                    _deviceInfo!['manufacturer'] as String? ?? 'Unknown',
                  ),
                  _buildInfoRow(
                    'Model',
                    _deviceInfo!['model'] as String? ?? 'Unknown',
                  ),
                  _buildInfoRow(
                    'Device',
                    _deviceInfo!['device'] as String? ?? 'Unknown',
                  ),
                  _buildInfoRow(
                    'Android Version',
                    _deviceInfo!['androidVersion'] as String? ?? 'Unknown',
                  ),
                  _buildInfoRow(
                    'Pixel Device',
                    (_deviceInfo!['isPixel'] as bool? ?? false)
                        ? '✓ Yes'
                        : '✗ No',
                    (_deviceInfo!['isPixel'] as bool? ?? false)
                        ? Colors.green
                        : Colors.red,
                  ),
                  _buildInfoRow(
                    'Gemini Nano Support',
                    (_deviceInfo!['supportsGeminiNano'] as bool? ?? false)
                        ? '✓ Yes'
                        : '✗ No',
                    (_deviceInfo!['supportsGeminiNano'] as bool? ?? false)
                        ? Colors.green
                        : Colors.red,
                  ),
                  _buildInfoRow(
                    'Overall Status',
                    _isSupported ? '✓ Supported' : '✗ Not Supported',
                    _isSupported ? Colors.green : Colors.red,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Message: ${_deviceInfo!['message'] as String? ?? 'No additional information'}',
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
