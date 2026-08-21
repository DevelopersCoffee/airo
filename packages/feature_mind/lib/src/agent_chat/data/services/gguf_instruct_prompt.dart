import 'package:core_ai/core_ai.dart';

/// Instruct wrap for local GGUF packages.
///
/// Raw `system + user` concatenation makes Gemma continue a `User:` / `Airo:`
/// transcript instead of answering the last turn. Qwen/Phi use ChatML; Gemma 2
/// instruct uses `<start_of_turn>` turns.
String formatGgufInstructPrompt({
  required String prompt,
  String? systemPrompt,
  required ModelFamily family,
}) {
  final user = prompt.trim();
  final system = systemPrompt?.trim() ?? '';
  if (family == ModelFamily.qwen || family == ModelFamily.phi) {
    final sys = system.isEmpty
        ? 'You are a helpful assistant. Answer the last user message directly.'
        : system;
    return '<|im_start|>system\n$sys<|im_end|>\n'
        '<|im_start|>user\n$user<|im_end|>\n'
        '<|im_start|>assistant\n';
  }
  if (family == ModelFamily.gemma) {
    final sys = system.isEmpty
        ? 'You are a helpful assistant. Answer the last user message directly. '
              'Do not continue a transcript, invent follow-up turns, or repeat a previous reply.'
        : '$system\nAnswer the last user message directly. '
              'Do not continue a transcript, invent follow-up turns, or repeat a previous reply.';
    return '<start_of_turn>user\n$sys\n\n$user<end_of_turn>\n'
        '<start_of_turn>model\n';
  }
  if (family == ModelFamily.llama) {
    final sys = system.isEmpty
        ? 'You are a helpful assistant. Answer the last user message directly.'
        : system;
    return '<|begin_of_text|><|start_header_id|>system<|end_header_id|>\n\n'
        '$sys<|eot_id|><|start_header_id|>user<|end_header_id|>\n\n'
        '$user<|eot_id|><|start_header_id|>assistant<|end_header_id|>\n\n';
  }
  if (family == ModelFamily.mistral) {
    final sys = system.isEmpty
        ? 'You are a helpful assistant. Answer the last user message directly.'
        : system;
    return '<s>[INST] $sys\n\n$user [/INST]';
  }
  final sys = system.isEmpty
      ? 'You are a helpful assistant. Answer the last user message directly.'
      : system;
  return '<|im_start|>system\n$sys<|im_end|>\n'
      '<|im_start|>user\n$user<|im_end|>\n'
      '<|im_start|>assistant\n';
}

const _ggufStopMarkers = [
  '<end_of_turn>',
  '<start_of_turn>',
  '</model>',
  '</user>',
  '<eos>',
  '<|eot_id|>',
  '<|end_of_text|>',
  '<|start_header_id|>',
  '[/INST]',
  '\nUser:',
  '\nAiro:',
  ' Airo:',
  '\nReady to proceed',
  '[Type your information here]',
];

/// True when generation has hit a role/stop marker and the engine should stop.
bool ggufHitStopMarker(String raw) {
  final text = raw.trim();
  if (text.isEmpty) return false;
  return _ggufStopMarkers.any(text.contains);
}

/// Drops role-play / transcript continuation after a real answer.
String trimGgufRoleBleed(String text) {
  var out = text.trim();
  out = out.replaceAll('[Type your information here]', '');
  for (final marker in _ggufStopMarkers) {
    if (marker == '[Type your information here]') continue;
    final index = out.indexOf(marker);
    if (index > 0) {
      out = out.substring(0, index);
    } else if (index == 0) {
      out = '';
      break;
    }
  }
  return _collapseRepeatedRuns(out.trim());
}

int ggufMaxOutputTokens(OfflineModelInfo package) {
  final count = package.parameterCount;
  if (count != null && count < 1000000000) return 512;
  return 2048;
}

bool isCompactLocalPackage(OfflineModelInfo? package) {
  final count = package?.parameterCount;
  return count != null && count < 1000000000;
}

String _collapseRepeatedRuns(String text) {
  if (text.isEmpty) return text;
  final lines = text.split('\n');
  if (lines.length >= 2) {
    final collapsed = <String>[];
    for (final line in lines) {
      if (collapsed.isNotEmpty &&
          collapsed.last == line &&
          line.trim().isNotEmpty) {
        continue;
      }
      collapsed.add(line);
    }
    text = collapsed.join('\n');
  }
  final repeated = RegExp(r'(.{16,120}?)(?:\s*\1){2,}').firstMatch(text);
  if (repeated != null) {
    final phrase = repeated.group(1)!;
    return '${text.substring(0, repeated.start)}$phrase'.trim();
  }
  return text.trim();
}
