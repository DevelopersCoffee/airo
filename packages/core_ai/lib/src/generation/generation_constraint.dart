import 'gbnf_grammar.dart';

/// How the inference engine must constrain the next completion.
///
/// Backends that speak GBNF (llama.cpp via the Rust generation engine) use
/// [gbnf]. Backends that cannot (Android plugin, LiteRT, cloud) still receive
/// [forcedPrefix] so the prompt and a post-pass can lock the same header.
class GenerationConstraint {
  const GenerationConstraint({this.gbnf, this.forcedPrefix});

  /// llama.cpp GBNF with start symbol `root`, or null for unconstrained.
  final String? gbnf;

  /// Exact leading text the reply must start with, if any.
  final String? forcedPrefix;

  /// Lock the first characters of the reply, then allow a free body.
  factory GenerationConstraint.forcedPrefix(String prefix) {
    final normalized = prefix.endsWith('\n') ? prefix : '$prefix\n';
    return GenerationConstraint(
      forcedPrefix: normalized,
      gbnf: GbnfGrammar.forcedPrefix(normalized),
    );
  }
}
