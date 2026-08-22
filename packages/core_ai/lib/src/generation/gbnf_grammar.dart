/// Domain-free GBNF snippets for llama.cpp's grammar sampler.
///
/// The engine already accepts a `root` grammar on [GenerationRequest]; these
/// helpers only *write* that text. Product code decides the prefix; this
/// module never mentions diets, meetings, or other capabilities.
class GbnfGrammar {
  const GbnfGrammar._();

  /// Forces the token stream to begin with [prefix], then allows printable
  /// body text (including newlines). Quotes and control chars in [prefix]
  /// are escaped for GBNF string literals.
  static String forcedPrefix(String prefix) {
    final escaped = _escapeGbnfString(prefix);
    return 'root ::= "$escaped" body\n'
        r'body ::= [\x09\x0a\x0d\x20-\x7e\x80-\xFF]*'
        '\n';
  }

  static String _escapeGbnfString(String value) {
    final buffer = StringBuffer();
    for (final unit in value.codeUnits) {
      switch (unit) {
        case 0x5c: // \
          buffer.write(r'\\');
        case 0x22: // "
          buffer.write(r'\"');
        case 0x0a:
          buffer.write(r'\n');
        case 0x0d:
          buffer.write(r'\r');
        case 0x09:
          buffer.write(r'\t');
        default:
          if (unit < 0x20) {
            buffer.write('\\x${unit.toRadixString(16).padLeft(2, '0')}');
          } else {
            buffer.writeCharCode(unit);
          }
      }
    }
    return buffer.toString();
  }
}
