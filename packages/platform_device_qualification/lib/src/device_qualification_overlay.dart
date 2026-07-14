import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'resolution_simulator.dart';
import 'dpad_remote_controller.dart';

// Since the user agreed to thread-safe static overrides, we will import and set the override on DeviceFormFactorDetector.
// In a real modular codebase, we can use platform channels or direct import if the app is compiled together.
// Let's dynamically resolve the device form factor override or use reflection/import if we can.
// In main_qualification.dart we will import both. In this package, we can define a callback or invoke a method dynamically.
typedef FormFactorOverrideCallback = void Function(String formFactor, String? tvPlatform);

class DeviceQualificationOverlay extends StatefulWidget {
  final Widget child;
  final String defaultPlaylistUrl;
  final FormFactorOverrideCallback? onFormFactorOverride;
  final bool autoCycle;

  const DeviceQualificationOverlay({
    super.key,
    required this.child,
    this.defaultPlaylistUrl = 'https://iptv-org.github.io/iptv/index.m3u',
    this.onFormFactorOverride,
    this.autoCycle = false,
  });

  @override
  State<DeviceQualificationOverlay> createState() => _DeviceQualificationOverlayState();
}

class _DeviceQualificationOverlayState extends State<DeviceQualificationOverlay> {
  bool _showPanel = false;
  bool _showRemote = false;
  SimulatedDevice _simulatedDevice = SimulatedDevice.native;
  String _networkProfile = 'Excellent WiFi';
  double _latencyMs = 0;
  bool _showBezel = true;

  // Diagnostic states
  double _fps = 60.0;
  int _droppedFrames = 0;
  DateTime _lastFrameTime = DateTime.now();

  // Defect logging form states
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  String _severity = 'P2';
  String _category = 'UI / Spacing';

  @override
  void initState() {
    super.initState();
    _startFpsTicker();
    _seedPlaylist();
    if (widget.autoCycle) {
      _startAutoCycle();
    }
  }

  void _startAutoCycle() {
    int index = 0;
    Future.doWhile(() async {
      await Future.delayed(const Duration(seconds: 8));
      if (!mounted) return false;
      index = (index + 1) % SimulatedDevice.values.length;
      final nextDevice = SimulatedDevice.values[index];
      setState(() {
        _simulatedDevice = nextDevice;
        if (nextDevice.isTv) {
          _showRemote = true; // show remote overlay for visual testing
        } else {
          _showRemote = false;
        }
      });
      _updateFormFactorOverride(nextDevice);
      return true;
    });
  }

  void _seedPlaylist() async {
    final prefs = await SharedPreferences.getInstance();
    // Pre-seed user playlist URL if empty
    if (prefs.getString('user_playlist_url') == null) {
      await prefs.setString('user_playlist_url', widget.defaultPlaylistUrl);
    }
  }

  void _startFpsTicker() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final now = DateTime.now();
      final difference = now.difference(_lastFrameTime).inMicroseconds;
      _lastFrameTime = now;
      if (difference > 0) {
        final instantFps = 1000000.0 / difference;
        setState(() {
          _fps = _fps * 0.95 + instantFps * 0.05; // smoothed FPS
          if (difference > 20000) { // Frame dropped (took >20ms instead of 16ms)
            _droppedFrames++;
          }
        });
      }
      _startFpsTicker();
    });
  }

  void _updateFormFactorOverride(SimulatedDevice device) {
    if (widget.onFormFactorOverride != null) {
      if (device.isTv) {
        widget.onFormFactorOverride!('tv', 'android_tv');
      } else if (device == SimulatedDevice.tabletLandscape) {
        widget.onFormFactorOverride!('tablet', null);
      } else if (device == SimulatedDevice.native) {
        widget.onFormFactorOverride!('tablet', null); // native iPad Air
      } else {
        widget.onFormFactorOverride!('mobile', null); // foldable or mobile
      }
    }
  }

  void _copyDefectReport() {
    final markdown = '''
# [Airo TV Defect Report] ${_titleController.text}

**Severity:** $_severity
**Category:** $_category
**Simulated Device Configuration:** ${_simulatedDevice.name} (${_simulatedDevice.width.toInt()}x${_simulatedDevice.height.toInt()})
**Network Profile:** $_networkProfile (Latency: ${_latencyMs.toInt()}ms)
**Performance Telemetry:** ${_fps.toStringAsFixed(1)} FPS | $_droppedFrames Dropped Frames

## Description
${_descriptionController.text}

## QA Context (Hardware Info)
- **Primary QA Device:** iPad Air
- **Timestamp:** ${DateTime.now().toLocal()}
- **Testing Base Branch:** qa/v2-ipad-qualification
- **IPTV Input Playlist:** ${widget.defaultPlaylistUrl}
''';

    Clipboard.setData(ClipboardData(text: markdown));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Defect report copied to clipboard in Markdown!'),
        backgroundColor: Colors.green,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        // App content wrapped with resolution simulator
        Positioned.fill(
          child: ResolutionSimulator(
            device: _simulatedDevice,
            showBezel: _showBezel,
            child: widget.child,
          ),
        ),

        // Floating remote controller (draggable)
        if (_showRemote && _simulatedDevice.isTv)
          Positioned(
            right: 20,
            bottom: 100,
            child: Draggable(
              feedback: DpadRemoteController(
                onBackPress: () => setState(() => _showRemote = false),
              ),
              childWhenDragging: const SizedBox.shrink(),
              child: DpadRemoteController(
                onBackPress: () => setState(() => _showRemote = false),
              ),
            ),
          ),

        // Floating trigger button (shows debug panel)
        Positioned(
          left: 12,
          bottom: 12,
          child: Opacity(
            opacity: _showPanel ? 0.3 : 0.9,
            child: GestureDetector(
              onTap: () => setState(() => _showPanel = !_showPanel),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF6C63FF), Color(0xFF3F3D56)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: const [
                    BoxShadow(
                      color: Colors.black26,
                      blurRadius: 8,
                      offset: Offset(0, 4),
                    ),
                  ],
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.bug_report, color: Colors.white, size: 18),
                    SizedBox(width: 6),
                    Text(
                      'QA PLATFORM',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                        decoration: TextDecoration.none,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),

        // Slide-out QA testing panel
        if (_showPanel)
          Positioned(
            left: 0,
            top: 0,
            bottom: 0,
            width: 360,
            child: _buildQaPanel(),
          ),
      ],
    );
  }

  Widget _buildQaPanel() {
    return Material(
      color: Colors.black.withOpacity(0.85),
      child: Container(
        decoration: BoxDecoration(
          border: Border(right: BorderSide(color: Colors.grey[850]!, width: 2)),
        ),
        child: SafeArea(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Colors.purple[900]!, Colors.black],
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'QA Qualification Menu',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close, color: Colors.white70),
                      onPressed: () => setState(() => _showPanel = false),
                    ),
                  ],
                ),
              ),

              // Scrollable QA Tabs
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    // Diagnostics Box
                    _buildDiagnosticsCard(),
                    const SizedBox(height: 16),

                    // Device Profile
                    _buildSectionHeader('Simulated Layout'),
                    const SizedBox(height: 8),
                    _buildDeviceSelector(),
                    const SizedBox(height: 12),
                    _buildSwitchTile(
                      title: 'Show Screen Bezel',
                      value: _showBezel,
                      onChanged: (val) => setState(() => _showBezel = val),
                    ),
                    if (_simulatedDevice.isTv) ...[
                      _buildSwitchTile(
                        title: 'Show Remote Controller Overlay',
                        value: _showRemote,
                        onChanged: (val) => setState(() => _showRemote = val),
                      ),
                    ],
                    const SizedBox(height: 20),

                    // Network Configuration
                    _buildSectionHeader('Network Emulation'),
                    const SizedBox(height: 8),
                    _buildNetworkSelector(),
                    const SizedBox(height: 20),

                    // Defect Logger Form
                    _buildSectionHeader('Log Defect (GitHub Report)'),
                    const SizedBox(height: 8),
                    _buildDefectForm(),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDiagnosticsCard() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.grey[900]?.withOpacity(0.8),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.purple.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'TELEMETRY DATA',
            style: TextStyle(
              color: Colors.purpleAccent,
              fontSize: 10,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _buildMetric('FPS', '${_fps.toStringAsFixed(1)} FPS', _fps > 55 ? Colors.green : Colors.orange),
              _buildMetric('Dropped Frames', '$_droppedFrames', _droppedFrames == 0 ? Colors.green : Colors.redAccent),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _buildMetric('Active Resolution', _simulatedDevice.isNative ? 'Native' : '${_simulatedDevice.width.toInt()}x${_simulatedDevice.height.toInt()}', Colors.white70),
              _buildMetric('Input Playlist', 'seeded', Colors.green),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMetric(String label, String value, Color valueColor) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(color: Colors.white54, fontSize: 10)),
        Text(value, style: TextStyle(color: valueColor, fontSize: 14, fontWeight: FontWeight.bold)),
      ],
    );
  }

  Widget _buildSectionHeader(String title) {
    return Text(
      title.toUpperCase(),
      style: const TextStyle(
        color: Colors.white54,
        fontSize: 11,
        fontWeight: FontWeight.bold,
      ),
    );
  }

  Widget _buildDeviceSelector() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: Colors.grey[900],
        borderRadius: BorderRadius.circular(8),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<SimulatedDevice>(
          value: _simulatedDevice,
          dropdownColor: Colors.grey[900],
          isExpanded: true,
          style: const TextStyle(color: Colors.white, fontSize: 14),
          icon: const Icon(Icons.arrow_drop_down, color: Colors.white70),
          items: SimulatedDevice.values.map((device) {
            return DropdownMenuItem(
              value: device,
              child: Text(device.name),
            );
          }).toList(),
          onChanged: (device) {
            if (device != null) {
              setState(() {
                _simulatedDevice = device;
                if (!device.isTv) _showRemote = false;
              });
              _updateFormFactorOverride(device);
            }
          },
        ),
      ),
    );
  }

  Widget _buildSwitchTile({
    required String title,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return SwitchListTile(
      title: Text(title, style: const TextStyle(color: Colors.white, fontSize: 13)),
      value: value,
      onChanged: onChanged,
      contentPadding: EdgeInsets.zero,
      dense: true,
      activeColor: const Color(0xFF6C63FF),
    );
  }

  Widget _buildNetworkSelector() {
    final profiles = ['Excellent WiFi', '5 Mbps', '2 Mbps', '1 Mbps', 'Offline'];
    return Column(
      children: profiles.map((p) {
        final isSelected = _networkProfile == p;
        return RadioListTile<String>(
          title: Text(
            p,
            style: TextStyle(
              color: isSelected ? const Color(0xFF6C63FF) : Colors.white,
              fontSize: 13,
              fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
            ),
          ),
          value: p,
          groupValue: _networkProfile,
          dense: true,
          activeColor: const Color(0xFF6C63FF),
          contentPadding: EdgeInsets.zero,
          onChanged: (val) {
            if (val != null) {
              setState(() {
                _networkProfile = val;
                _latencyMs = switch (val) {
                  'Excellent WiFi' => 10.0,
                  '5 Mbps' => 45.0,
                  '2 Mbps' => 120.0,
                  '1 Mbps' => 250.0,
                  'Offline' => double.infinity,
                  _ => 0.0
                };
              });
            }
          },
        );
      }).toList(),
    );
  }

  Widget _buildDefectForm() {
    return Column(
      children: [
        // Title
        TextField(
          controller: _titleController,
          style: const TextStyle(color: Colors.white, fontSize: 13),
          decoration: InputDecoration(
            labelText: 'Defect Summary / Title',
            labelStyle: const TextStyle(color: Colors.white54),
            filled: true,
            fillColor: Colors.grey[900],
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
          ),
        ),
        const SizedBox(height: 12),

        // Severity
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text('Severity: ', style: TextStyle(color: Colors.white, fontSize: 13)),
            DropdownButton<String>(
              value: _severity,
              dropdownColor: Colors.grey[900],
              style: const TextStyle(color: Colors.white, fontSize: 13),
              items: ['P0', 'P1', 'P2', 'P3', 'P4'].map((s) {
                return DropdownMenuItem(value: s, child: Text(s));
              }).toList(),
              onChanged: (val) => setState(() => _severity = val ?? 'P2'),
            ),
            const Text('Category: ', style: TextStyle(color: Colors.white, fontSize: 13)),
            DropdownButton<String>(
              value: _category,
              dropdownColor: Colors.grey[900],
              style: const TextStyle(color: Colors.white, fontSize: 13),
              items: ['UI / Spacing', 'Navigation / Focus', 'Streaming Quality', 'EPG Timeline', 'Search/Inputs'].map((c) {
                return DropdownMenuItem(value: c, child: Text(c));
              }).toList(),
              onChanged: (val) => setState(() => _category = val ?? 'UI / Spacing'),
            ),
          ],
        ),
        const SizedBox(height: 12),

        // Description
        TextField(
          controller: _descriptionController,
          style: const TextStyle(color: Colors.white, fontSize: 13),
          maxLines: 4,
          decoration: InputDecoration(
            labelText: 'Defect Details / Steps to Reproduce',
            labelStyle: const TextStyle(color: Colors.white54),
            filled: true,
            fillColor: Colors.grey[900],
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
          ),
        ),
        const SizedBox(height: 16),

        // Button to generate markdown and copy to clipboard
        SizedBox(
          width: double.infinity,
          height: 44,
          child: ElevatedButton.icon(
            onPressed: _copyDefectReport,
            icon: const Icon(Icons.content_copy, size: 16, color: Colors.white),
            label: const Text('Export Report to Clipboard'),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF6C63FF),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
          ),
        ),
      ],
    );
  }
}
