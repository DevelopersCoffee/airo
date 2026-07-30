import 'dart:convert';

import 'package:core_ai/core_ai.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

/// Controlled prompt workspace for text runtimes and OpenAI-compatible image
/// servers (including local/private endpoints such as a LAN ComfyUI bridge).
class PromptLabScreen extends StatefulWidget {
  const PromptLabScreen({super.key, this.initialImageMode = false});

  final bool initialImageMode;

  @override
  State<PromptLabScreen> createState() => _PromptLabScreenState();
}

class _PromptLabScreenState extends State<PromptLabScreen> {
  final _promptController = TextEditingController();
  final _negativeController = TextEditingController();
  final _imageServerController = TextEditingController();
  final _imagePicker = ImagePicker();
  double _temperature = 0.7;
  double _topK = 40;
  int _maxTokens = 512;
  int _imageSteps = 20;
  late bool _imageMode;
  XFile? _sourceImage;
  GeneratedImage? _generatedImage;
  String? _imageError;
  bool _isGeneratingImage = false;

  @override
  void initState() {
    super.initState();
    _imageMode = widget.initialImageMode;
  }

  @override
  void dispose() {
    _promptController.dispose();
    _negativeController.dispose();
    _imageServerController.dispose();
    super.dispose();
  }

  Future<void> _run() async {
    final prompt = _promptController.text.trim();
    if (prompt.isEmpty) return;
    if (_imageMode) {
      await _runImage(prompt);
      return;
    }
    final negative = _negativeController.text.trim();
    final composed = [
      if (_imageMode) 'Image task.',
      prompt,
      if (negative.isNotEmpty) 'Negative prompt: $negative',
      'Runtime controls: temperature=${_temperature.toStringAsFixed(2)}, top-k=${_topK.round()}, max output tokens=$_maxTokens.',
    ].join('\n');
    context.push('/mind/chat?prefill=${Uri.encodeComponent(composed)}');
  }

  Future<void> _runImage(String prompt) async {
    final baseUrl = _imageServerController.text.trim();
    final uri = Uri.tryParse(baseUrl);
    if (uri == null ||
        !uri.hasScheme ||
        (uri.scheme != 'http' && uri.scheme != 'https')) {
      setState(
        () => _imageError = 'Enter a valid local/private image server URL.',
      );
      return;
    }

    setState(() {
      _isGeneratingImage = true;
      _generatedImage = null;
      _imageError = null;
    });
    try {
      final sourceBase64 = _sourceImage == null
          ? null
          : base64Encode(await _sourceImage!.readAsBytes());
      final result = await OpenAICompatibleImageClient(baseUrl: baseUrl)
          .generate(
            ImageGenerationRequest(
              prompt: prompt,
              negativePrompt: _negativeController.text.trim().isEmpty
                  ? null
                  : _negativeController.text.trim(),
              sourceImageBase64: sourceBase64,
              steps: _imageSteps,
            ),
          );
      if (!mounted) return;
      if (result.isSuccess) {
        setState(() => _generatedImage = result.valueOrNull);
      } else {
        setState(() => _imageError = result.failure.toString());
      }
    } on Object catch (error) {
      if (mounted) {
        setState(() => _imageError = 'Image generation failed: $error');
      }
    } finally {
      if (mounted) setState(() => _isGeneratingImage = false);
    }
  }

  Future<void> _pickSourceImage() async {
    final image = await _imagePicker.pickImage(source: ImageSource.gallery);
    if (image != null && mounted) setState(() => _sourceImage = image);
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
          if (_imageMode) ...[
            TextField(
              controller: _imageServerController,
              keyboardType: TextInputType.url,
              decoration: const InputDecoration(
                labelText: 'Image server URL',
                hintText: 'http://127.0.0.1:8188/v1',
                helperText:
                    'Uses an OpenAI-compatible /images/generations endpoint.',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: _pickSourceImage,
              icon: const Icon(Icons.add_photo_alternate_outlined),
              label: Text(
                _sourceImage == null
                    ? 'Add source image (optional)'
                    : 'Source: ${_sourceImage!.name}',
              ),
            ),
            const SizedBox(height: 12),
          ],
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
          if (_imageMode) ...[
            Text('Image steps: $_imageSteps'),
            Slider(
              value: _imageSteps.toDouble(),
              min: 1,
              max: 50,
              divisions: 49,
              label: _imageSteps.toString(),
              onChanged: (value) => setState(() => _imageSteps = value.round()),
            ),
          ] else ...[
            Text('Maximum output: $_maxTokens tokens'),
            Slider(
              value: _maxTokens.toDouble(),
              min: 128,
              max: 2048,
              divisions: 15,
              label: _maxTokens.toString(),
              onChanged: (value) => setState(() => _maxTokens = value.round()),
            ),
          ],
          const SizedBox(height: 12),
          FilledButton.icon(
            onPressed:
                _isGeneratingImage || _promptController.text.trim().isEmpty
                ? null
                : _run,
            icon: _isGeneratingImage
                ? const SizedBox.square(
                    dimension: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.play_arrow),
            label: Text(
              _imageMode ? 'Generate image' : 'Run with selected runtime',
            ),
          ),
          if (_imageError != null) ...[
            const SizedBox(height: 12),
            Text(
              _imageError!,
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          ],
          if (_generatedImage != null) ...[
            const SizedBox(height: 16),
            _GeneratedImageView(image: _generatedImage!),
          ],
          const SizedBox(height: 8),
          const Text(
            'Airo keeps these controls visible so you can explain and reproduce a result. The selected runtime performs the final capability and memory check.',
          ),
        ],
      ),
    );
  }
}

class _GeneratedImageView extends StatelessWidget {
  const _GeneratedImageView({required this.image});

  final GeneratedImage image;

  @override
  Widget build(BuildContext context) {
    final base64Data = OpenAICompatibleImageClient.extractDataUrlBase64(
      image.base64Data,
    );
    final rawBase64 = base64Data ?? image.base64Data;
    Widget child;
    if (rawBase64 != null) {
      try {
        child = Image.memory(base64Decode(rawBase64), fit: BoxFit.contain);
      } on Object {
        child = const Padding(
          padding: EdgeInsets.all(16),
          child: Text('The image server returned malformed image data.'),
        );
      }
    } else {
      child = Image.network(
        image.url!,
        fit: BoxFit.contain,
        errorBuilder: (context, error, stackTrace) => const Padding(
          padding: EdgeInsets.all(16),
          child: Text('The image could not be loaded from the image server.'),
        ),
      );
    }
    return Card(
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          child,
          if (image.revisedPrompt != null)
            Padding(
              padding: const EdgeInsets.all(12),
              child: Text('Revised prompt: ${image.revisedPrompt}'),
            ),
        ],
      ),
    );
  }
}
