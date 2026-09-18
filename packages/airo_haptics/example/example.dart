import 'package:airo_haptics/airo_haptics.dart';
import 'package:flutter/material.dart';

void main() {
  runApp(const HapticLabApp());
}

class HapticLabApp extends StatelessWidget {
  const HapticLabApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Airo Haptic Lab',
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple, brightness: Brightness.dark),
      ),
      home: const HapticLabScreen(),
    );
  }
}

class HapticLabScreen extends StatefulWidget {
  const HapticLabScreen({super.key});

  @override
  State<HapticLabScreen> createState() => _HapticLabScreenState();
}

class _HapticLabScreenState extends State<HapticLabScreen> {
  AiroHapticCapabilities? _capabilities;
  double _customIntensity = 1;
  double _customSharpness = 0.8;
  double _customDurationMs = 200;

  @override
  void initState() {
    super.initState();
    _loadCapabilities();
  }

  Future<void> _loadCapabilities() async {
    final caps = await AiroHaptics.capabilities;
    if (mounted) {
      setState(() {
        _capabilities = caps;
      });
    }
  }

  void _triggerCustomPattern() {
    final pattern = AiroHapticPattern(
      id: 'custom_lab_pattern',
      events: [
        AiroHapticEvent.continuous(
          duration: Duration(milliseconds: _customDurationMs.round()),
          intensity: _customIntensity,
          sharpness: _customSharpness,
        ),
      ],
    );
    AiroHaptics.play(pattern);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Airo Haptic Lab'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadCapabilities,
            tooltip: 'Refresh Capabilities',
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _buildCapabilitiesCard(),
            const SizedBox(height: 16),
            _buildPresetsSection(),
            const SizedBox(height: 16),
            _buildCustomPatternSection(),
          ],
        ),
      ),
    );
  }

  Widget _buildCapabilitiesCard() {
    final caps = _capabilities;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Capabilities', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            if (caps == null)
              const CircularProgressIndicator()
            else ...[
              Text('Platform: ${caps.platform.nameLabel} (${caps.backend ?? "Native"})'),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 4,
                children: [
                  _chip('Supported', caps.supported),
                  _chip('Basic', caps.basic),
                  _chip('Advanced', caps.advanced),
                  _chip('Custom Patterns', caps.customPatterns),
                  _chip('Continuous', caps.continuous),
                  _chip('Variable Intensity', caps.variableIntensity),
                  _chip('Variable Sharpness', caps.variableSharpness),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _chip(String label, bool value) {
    return FilterChip(
      selected: value,
      label: Text(label),
      onSelected: null,
      selectedColor: Colors.deepPurple.shade700,
    );
  }

  Widget _buildPresetsSection() {
    return const Card(
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Semantic & Interaction Presets'),
            SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                ElevatedButton(onPressed: AiroHaptics.selection, child: Text('Selection')),
                ElevatedButton(onPressed: AiroHaptics.light, child: Text('Light Impact')),
                ElevatedButton(onPressed: AiroHaptics.medium, child: Text('Medium Impact')),
                ElevatedButton(onPressed: AiroHaptics.heavy, child: Text('Heavy Impact')),
                ElevatedButton(onPressed: AiroHaptics.success, child: Text('Success')),
                ElevatedButton(onPressed: AiroHaptics.warning, child: Text('Warning')),
                ElevatedButton(onPressed: AiroHaptics.error, child: Text('Error')),
                ElevatedButton(onPressed: AiroHaptics.soft, child: Text('Soft')),
                ElevatedButton(onPressed: AiroHaptics.rigid, child: Text('Rigid')),
                ElevatedButton(onPressed: AiroHaptics.focus, child: Text('Focus')),
                ElevatedButton(onPressed: AiroHaptics.navigation, child: Text('Navigation')),
                ElevatedButton(onPressed: AiroHaptics.delete, child: Text('Delete')),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCustomPatternSection() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Custom Pattern Studio', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 12),
            Text('Intensity: ${_customIntensity.toStringAsFixed(2)}'),
            Slider(
              value: _customIntensity,
              onChanged: (v) => setState(() => _customIntensity = v),
            ),
            Text('Sharpness: ${_customSharpness.toStringAsFixed(2)}'),
            Slider(
              value: _customSharpness,
              onChanged: (v) => setState(() => _customSharpness = v),
            ),
            Text('Duration: ${_customDurationMs.round()} ms'),
            Slider(
              min: 50,
              max: 1000,
              value: _customDurationMs,
              onChanged: (v) => setState(() => _customDurationMs = v),
            ),
            const SizedBox(height: 12),
            ElevatedButton.icon(
              onPressed: _triggerCustomPattern,
              icon: const Icon(Icons.play_arrow),
              label: const Text('PLAY CUSTOM PATTERN'),
            ),
          ],
        ),
      ),
    );
  }
}
