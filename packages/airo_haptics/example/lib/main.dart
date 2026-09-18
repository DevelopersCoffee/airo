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
  AiroHapticProfile _selectedProfile = AiroHapticProfile.defaultProfile;
  AiroHapticPlayer? _activePlayer;
  AiroHapticSession? _activeSession;

  double _liveIntensity = 1;
  double _liveSharpness = 0.5;

  // ADSR Envelope parameters
  double _attackMs = 30;
  double _decayMs = 80;
  double _sustainLevel = 0.6;
  double _releaseMs = 150;

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

  Future<void> _playPresetPattern() async {
    final pattern = AiroHapticPattern.doubleClick();
    _activePlayer = await AiroHaptics.createPlayer(pattern);
    await _activePlayer?.start();
    setState(() {});
  }

  Future<void> _playContinuousEnvelope() async {
    final envelope = AiroHapticEnvelope(
      attack: Duration(milliseconds: _attackMs.round()),
      decay: Duration(milliseconds: _decayMs.round()),
      sustain: _sustainLevel,
      release: Duration(milliseconds: _releaseMs.round()),
    );

    _activeSession ??= await AiroHaptics.startSession(id: 'lab_continuous_session');
    await _activeSession?.playContinuous(
      intensity: _liveIntensity,
      sharpness: _liveSharpness,
      envelope: envelope,
    );
    setState(() {});
  }

  Future<void> _updateLiveParameters(double intensity, double sharpness) async {
    setState(() {
      _liveIntensity = intensity;
      _liveSharpness = sharpness;
    });
    if (_activePlayer != null && _activePlayer!.isPlaying) {
      await _activePlayer!.update(intensity: intensity, sharpness: sharpness);
    }
    if (_activeSession != null && _activeSession!.isActive) {
      await _activeSession!.update(intensity: intensity, sharpness: sharpness);
    }
  }

  void _loadSampleAhap() {
    const ahapMap = {
      'Pattern': [
        {
          'Event': {
            'EventType': 'HapticTransient',
            'Time': 0.0,
            'EventParameters': [
              {'ParameterID': 'HapticIntensity', 'ParameterValue': 0.8},
              {'ParameterID': 'HapticSharpness', 'ParameterValue': 0.9}
            ]
          }
        },
        {
          'Event': {
            'EventType': 'HapticContinuous',
            'Time': 0.12,
            'EventDuration': 0.25,
            'EventParameters': [
              {'ParameterID': 'HapticIntensity', 'ParameterValue': 0.6},
              {'ParameterID': 'HapticSharpness', 'ParameterValue': 0.3}
            ]
          }
        }
      ]
    };

    final pattern = AiroHapticPattern.fromAhap(ahapMap, id: 'sample_ahap', name: 'Imported AHAP');
    AiroHaptics.play(pattern);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Airo Haptic Lab 1.x'),
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
            _buildProfileSelector(),
            const SizedBox(height: 16),
            _buildPresetsSection(),
            const SizedBox(height: 16),
            _buildEnvelopeStudio(),
            const SizedBox(height: 16),
            _buildLiveParameterController(),
            const SizedBox(height: 16),
            _buildAhapImporterCard(),
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
            Text('Device Telemetry', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            if (caps == null)
              const CircularProgressIndicator()
            else ...[
              Text('Platform: ${caps.platform.nameLabel} (${caps.backend ?? "Native Engine"})'),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 4,
                children: [
                  _chip('Supported', caps.supported),
                  _chip('Basic', caps.basic),
                  _chip('Advanced Composition', caps.advanced),
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

  Widget _buildProfileSelector() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Tuning Profile', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              children: AiroHapticProfile.values.map((profile) {
                final isSelected = _selectedProfile == profile;
                return ChoiceChip(
                  label: Text(profile.label),
                  selected: isSelected,
                  onSelected: (selected) {
                    if (selected) {
                      setState(() {
                        _selectedProfile = profile;
                        AiroHaptics.profile = profile;
                      });
                      AiroHaptics.selection();
                    }
                  },
                );
              }).toList(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPresetsSection() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Semantic & Physical Presets', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 12),
            const Wrap(
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
              ],
            ),
            const SizedBox(height: 8),
            ElevatedButton(onPressed: _playPresetPattern, child: const Text('Pattern Player')),
          ],
        ),
      ),
    );
  }

  Widget _buildEnvelopeStudio() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('ADSR Continuous Envelope Studio', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            Text('Attack: ${_attackMs.round()} ms'),
            Slider(value: _attackMs, min: 5, max: 200, onChanged: (v) => setState(() => _attackMs = v)),
            Text('Decay: ${_decayMs.round()} ms'),
            Slider(value: _decayMs, min: 10, max: 300, onChanged: (v) => setState(() => _decayMs = v)),
            Text('Sustain Level: ${_sustainLevel.toStringAsFixed(2)}'),
            Slider(value: _sustainLevel, min: 0.1, onChanged: (v) => setState(() => _sustainLevel = v)),
            Text('Release: ${_releaseMs.round()} ms'),
            Slider(value: _releaseMs, min: 10, max: 500, onChanged: (v) => setState(() => _releaseMs = v)),
            const SizedBox(height: 8),
            ElevatedButton.icon(
              onPressed: _playContinuousEnvelope,
              icon: const Icon(Icons.waves),
              label: const Text('PLAY ADSR ENVELOPE'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLiveParameterController() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Real-Time Dynamic Parameters', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            Text('Live Intensity: ${_liveIntensity.toStringAsFixed(2)}'),
            Slider(
              value: _liveIntensity,
              onChanged: (v) => _updateLiveParameters(v, _liveSharpness),
            ),
            Text('Live Sharpness: ${_liveSharpness.toStringAsFixed(2)}'),
            Slider(
              value: _liveSharpness,
              onChanged: (v) => _updateLiveParameters(_liveIntensity, v),
            ),
            Row(
              children: [
                ElevatedButton(
                  onPressed: () => _activePlayer?.pause(),
                  child: const Text('Pause Player'),
                ),
                const SizedBox(width: 8),
                ElevatedButton(
                  onPressed: () => _activePlayer?.resume(),
                  child: const Text('Resume Player'),
                ),
                const SizedBox(width: 8),
                ElevatedButton(
                  onPressed: () {
                    _activePlayer?.stop();
                    _activeSession?.stop();
                    AiroHaptics.stopAll();
                  },
                  child: const Text('Stop All'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAhapImporterCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('AHAP Pattern Parsing', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            const Text('Parses Apple AHAP design format maps seamlessly across all target platforms.'),
            const SizedBox(height: 8),
            ElevatedButton.icon(
              onPressed: _loadSampleAhap,
              icon: const Icon(Icons.file_open),
              label: const Text('PLAY SAMPLE AHAP PATTERN'),
            ),
          ],
        ),
      ),
    );
  }
}
