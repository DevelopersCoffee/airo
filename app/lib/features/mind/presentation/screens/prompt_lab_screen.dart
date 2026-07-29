import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

/// Controlled prompt workspace shared by text and future image runtimes.
class PromptLabScreen extends StatefulWidget {
  const PromptLabScreen({super.key});

  @override
  State<PromptLabScreen> createState() => _PromptLabScreenState();
}

class _PromptLabScreenState extends State<PromptLabScreen> {
  final _promptController = TextEditingController();
  final _negativeController = TextEditingController();
  double _temperature = 0.7;
  double _topK = 40;
  int _maxTokens = 512;
  bool _imageMode = false;

  @override
  void dispose() {
    _promptController.dispose();
    _negativeController.dispose();
    super.dispose();
  }

  void _run() {
    final prompt = _promptController.text.trim();
    if (prompt.isEmpty) return;
    final negative = _negativeController.text.trim();
    final composed = [
      if (_imageMode) 'Image task.',
      prompt,
      if (negative.isNotEmpty) 'Negative prompt: $negative',
      'Runtime controls: temperature=${_temperature.toStringAsFixed(2)}, top-k=${_topK.round()}, max output tokens=$_maxTokens.',
    ].join('\n');
    context.push('/mind/chat?prefill=${Uri.encodeComponent(composed)}');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Prompt Lab')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
        children: [
          SegmentedButton<bool>(
            segments: const [
              ButtonSegment(
                value: false,
                label: Text('Text'),
                icon: Icon(Icons.chat_outlined),
              ),
              ButtonSegment(
                value: true,
                label: Text('Image'),
                icon: Icon(Icons.image_outlined),
              ),
            ],
            selected: {_imageMode},
            onSelectionChanged: (values) =>
                setState(() => _imageMode = values.first),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _promptController,
            minLines: 5,
            maxLines: 10,
            decoration: const InputDecoration(
              labelText: 'Prompt',
              hintText: 'Describe the result you want…',
              border: OutlineInputBorder(),
            ),
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _negativeController,
            minLines: 2,
            maxLines: 5,
            decoration: const InputDecoration(
              labelText: 'Negative prompt (optional)',
              hintText: 'What should the result avoid?',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 20),
          Text('Temperature: ${_temperature.toStringAsFixed(2)}'),
          Slider(
            value: _temperature,
            min: 0,
            max: 1.5,
            divisions: 30,
            label: _temperature.toStringAsFixed(2),
            onChanged: (value) => setState(() => _temperature = value),
          ),
          Text('Top-k: ${_topK.round()}'),
          Slider(
            value: _topK,
            min: 1,
            max: 100,
            divisions: 99,
            label: _topK.round().toString(),
            onChanged: (value) => setState(() => _topK = value),
          ),
          Text('Maximum output: $_maxTokens tokens'),
          Slider(
            value: _maxTokens.toDouble(),
            min: 128,
            max: 2048,
            divisions: 15,
            label: _maxTokens.toString(),
            onChanged: (value) => setState(() => _maxTokens = value.round()),
          ),
          const SizedBox(height: 12),
          FilledButton.icon(
            onPressed: _promptController.text.trim().isEmpty ? null : _run,
            icon: const Icon(Icons.play_arrow),
            label: const Text('Run with selected runtime'),
          ),
          const SizedBox(height: 8),
          const Text(
            'Airo keeps these controls visible so you can explain and reproduce a result. The selected runtime performs the final capability and memory check.',
          ),
        ],
      ),
    );
  }
}
