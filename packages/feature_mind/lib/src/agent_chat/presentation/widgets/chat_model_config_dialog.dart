import 'package:core_ui/core_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../domain/models/chat_model_config.dart';

Future<ChatModelConfig?> showChatModelConfigDialog({
  required BuildContext context,
  required ChatModelConfig initial,
}) {
  return showDialog<ChatModelConfig>(
    context: context,
    builder: (context) => ChatModelConfigDialog(initial: initial),
  );
}

/// Configurations sheet: sampling sliders plus an optional system-prompt override.
class ChatModelConfigDialog extends StatefulWidget {
  const ChatModelConfigDialog({super.key, required this.initial});

  final ChatModelConfig initial;

  @override
  State<ChatModelConfigDialog> createState() => _ChatModelConfigDialogState();
}

class _ChatModelConfigDialogState extends State<ChatModelConfigDialog>
    with SingleTickerProviderStateMixin {
  late TabController _tabs;
  late ChatModelConfig _draft;
  late final TextEditingController _maxTokens;
  late final TextEditingController _topK;
  late final TextEditingController _topP;
  late final TextEditingController _temperature;
  late final TextEditingController _systemPrompt;

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 2, vsync: this);
    _draft = widget.initial.normalized();
    _maxTokens = TextEditingController(text: '${_draft.maxTokens}');
    _topK = TextEditingController(text: '${_draft.topK}');
    _topP = TextEditingController(text: _formatDouble(_draft.topP, 2));
    _temperature = TextEditingController(
      text: _formatDouble(_draft.temperature, 2),
    );
    _systemPrompt = TextEditingController(text: _draft.systemPrompt);
  }

  @override
  void dispose() {
    _tabs.dispose();
    _maxTokens.dispose();
    _topK.dispose();
    _topP.dispose();
    _temperature.dispose();
    _systemPrompt.dispose();
    super.dispose();
  }

  void _commit() {
    Navigator.of(
      context,
    ).pop(_draft.copyWith(systemPrompt: _systemPrompt.text).normalized());
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final size = MediaQuery.sizeOf(context);
    final maxHeight = size.height * 0.86;
    final width = size.width < 560 ? size.width - 40 : 520.0;
    return Dialog(
      key: const Key('chat_model_config_dialog'),
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      child: Material(
        type: MaterialType.card,
        color:
            Theme.of(context).dialogTheme.backgroundColor ??
            Theme.of(context).colorScheme.surface,
        child: SizedBox(
          width: width,
          height: maxHeight.clamp(420, 560).toDouble(),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 12, 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text('Configurations', style: theme.textTheme.titleLarge),
                const SizedBox(height: AiroSpacing.sm),
                TabBar(
                  controller: _tabs,
                  tabAlignment: TabAlignment.start,
                  isScrollable: true,
                  tabs: const [
                    Tab(text: 'Model Configs'),
                    Tab(text: 'System Prompt'),
                  ],
                ),
                Expanded(
                  child: TabBarView(
                    controller: _tabs,
                    children: [_buildModelConfigs(theme), _buildSystemPrompt()],
                  ),
                ),
                Align(
                  alignment: Alignment.centerRight,
                  child: OverflowBar(
                    children: [
                      TextButton(
                        key: const Key('chat_model_config_cancel'),
                        onPressed: () => Navigator.of(context).pop(),
                        child: const Text('Cancel'),
                      ),
                      FilledButton(
                        key: const Key('chat_model_config_ok'),
                        onPressed: _commit,
                        child: const Text('OK'),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildModelConfigs(ThemeData theme) {
    return ListView(
      padding: const EdgeInsets.only(top: AiroSpacing.md, right: 8),
      children: [
        _SliderField(
          key: const Key('chat_model_config_max_tokens'),
          label: 'Max Tokens',
          controller: _maxTokens,
          value: _draft.maxTokens.toDouble(),
          min: ChatModelConfig.minMaxTokens.toDouble(),
          max: ChatModelConfig.maxMaxTokens.toDouble(),
          divisions: 127,
          format: (value) => value.round().toString(),
          onChanged: (value) {
            setState(() {
              _draft = _draft.copyWith(maxTokens: value.round());
              _maxTokens.text = '${_draft.maxTokens}';
            });
          },
          onSubmitted: (raw) {
            final parsed = int.tryParse(raw.trim());
            if (parsed == null) {
              _maxTokens.text = '${_draft.maxTokens}';
              return;
            }
            setState(() {
              _draft = _draft.copyWith(maxTokens: parsed);
              _maxTokens.text = '${_draft.maxTokens}';
            });
          },
        ),
        _SliderField(
          key: const Key('chat_model_config_topk'),
          label: 'TopK',
          controller: _topK,
          value: _draft.topK.toDouble(),
          min: ChatModelConfig.minTopK.toDouble(),
          max: ChatModelConfig.maxTopK.toDouble(),
          divisions: ChatModelConfig.maxTopK - ChatModelConfig.minTopK,
          format: (value) => value.round().toString(),
          onChanged: (value) {
            setState(() {
              _draft = _draft.copyWith(topK: value.round());
              _topK.text = '${_draft.topK}';
            });
          },
          onSubmitted: (raw) {
            final parsed = int.tryParse(raw.trim());
            if (parsed == null) {
              _topK.text = '${_draft.topK}';
              return;
            }
            setState(() {
              _draft = _draft.copyWith(topK: parsed);
              _topK.text = '${_draft.topK}';
            });
          },
        ),
        _SliderField(
          key: const Key('chat_model_config_topp'),
          label: 'TopP',
          controller: _topP,
          value: _draft.topP,
          min: ChatModelConfig.minTopP,
          max: ChatModelConfig.maxTopP,
          divisions: 100,
          format: (value) => _formatDouble(value, 2),
          onChanged: (value) {
            setState(() {
              _draft = _draft.copyWith(topP: value);
              _topP.text = _formatDouble(_draft.topP, 2);
            });
          },
          onSubmitted: (raw) {
            final parsed = double.tryParse(raw.trim());
            if (parsed == null) {
              _topP.text = _formatDouble(_draft.topP, 2);
              return;
            }
            setState(() {
              _draft = _draft.copyWith(topP: parsed);
              _topP.text = _formatDouble(_draft.topP, 2);
            });
          },
        ),
        _SliderField(
          key: const Key('chat_model_config_temperature'),
          label: 'Temperature',
          controller: _temperature,
          value: _draft.temperature,
          min: ChatModelConfig.minTemperature,
          max: ChatModelConfig.maxTemperature,
          divisions: 40,
          format: (value) => _formatDouble(value, 2),
          onChanged: (value) {
            setState(() {
              _draft = _draft.copyWith(temperature: value);
              _temperature.text = _formatDouble(_draft.temperature, 2);
            });
          },
          onSubmitted: (raw) {
            final parsed = double.tryParse(raw.trim());
            if (parsed == null) {
              _temperature.text = _formatDouble(_draft.temperature, 2);
              return;
            }
            setState(() {
              _draft = _draft.copyWith(temperature: parsed);
              _temperature.text = _formatDouble(_draft.temperature, 2);
            });
          },
        ),
        const SizedBox(height: AiroSpacing.md),
        Text('Accelerator', style: theme.textTheme.titleSmall),
        const SizedBox(height: AiroSpacing.sm),
        SegmentedButton<ChatAccelerator>(
          key: const Key('chat_model_config_accelerator'),
          showSelectedIcon: false,
          segments: const [
            ButtonSegment(value: ChatAccelerator.cpu, label: Text('CPU')),
            ButtonSegment(value: ChatAccelerator.gpu, label: Text('GPU')),
          ],
          selected: {_draft.accelerator},
          onSelectionChanged: (values) {
            setState(() {
              _draft = _draft.copyWith(accelerator: values.first);
            });
          },
        ),
      ],
    );
  }

  Widget _buildSystemPrompt() {
    return Padding(
      padding: const EdgeInsets.only(top: AiroSpacing.md, right: 8, bottom: 8),
      child: TextField(
        key: const Key('chat_model_config_system_prompt'),
        controller: _systemPrompt,
        minLines: 8,
        maxLines: 16,
        decoration: const InputDecoration(
          alignLabelWithHint: true,
          labelText: 'System Prompt',
          hintText: 'Optional instructions prepended to the assembled prompt.',
          border: OutlineInputBorder(),
        ),
      ),
    );
  }
}

class _SliderField extends StatelessWidget {
  const _SliderField({
    super.key,
    required this.label,
    required this.controller,
    required this.value,
    required this.min,
    required this.max,
    required this.divisions,
    required this.format,
    required this.onChanged,
    required this.onSubmitted,
  });

  final String label;
  final TextEditingController controller;
  final double value;
  final double min;
  final double max;
  final int divisions;
  final String Function(double value) format;
  final ValueChanged<double> onChanged;
  final ValueChanged<String> onSubmitted;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: AiroSpacing.sm),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: theme.textTheme.titleSmall),
          Row(
            children: [
              Expanded(
                child: Slider(
                  value: value.clamp(min, max),
                  min: min,
                  max: max,
                  divisions: divisions,
                  label: format(value),
                  onChanged: onChanged,
                ),
              ),
              SizedBox(
                width: 76,
                child: TextField(
                  controller: controller,
                  textAlign: TextAlign.center,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  inputFormatters: [
                    FilteringTextInputFormatter.allow(RegExp(r'[0-9.]')),
                  ],
                  decoration: const InputDecoration(
                    isDense: true,
                    border: OutlineInputBorder(),
                    contentPadding: EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 8,
                    ),
                  ),
                  onSubmitted: onSubmitted,
                  onEditingComplete: () => onSubmitted(controller.text),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

String _formatDouble(double value, int fractionDigits) {
  return value.toStringAsFixed(fractionDigits);
}
