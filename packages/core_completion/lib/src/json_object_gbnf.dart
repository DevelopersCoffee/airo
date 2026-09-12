/// GBNF with start symbol `root` that emits one JSON object.
///
/// [requiredKeys] become required object members as JSON string literals.
/// Callers own property names; this helper has no product vocabulary.
String jsonObjectGbnf({Iterable<String> requiredKeys = const []}) {
  final keys = [
    for (final key in requiredKeys)
      if (key.trim().isNotEmpty) key.trim(),
  ];
  final requiredPairs = [
    for (final key in keys) '"${_escape(key)}" ws ":" ws value',
  ];
  final members = requiredPairs.isEmpty
      ? 'object ::= "{" ws members? ws "}"\n'
            'members ::= pair (ws "," ws pair)*\n'
      : 'object ::= "{" ws required rest ws "}"\n'
            'required ::= ${requiredPairs.join(' ws "," ws ')}\n'
            'rest ::= (ws "," ws extra-pair)*\n';
  return 'root ::= object\n'
      '$members'
      'extra-pair ::= pair\n'
      'pair ::= string ws ":" ws value\n'
      'value ::= object | array | string | number | boolean | null\n'
      'array ::= "[" ws (value (ws "," ws value)*)? ws "]"\n'
      'string ::= "\\"" chars "\\""\n'
      'chars ::= char*\n'
      r'char ::= [^"\\] | "\\" escape'
      '\n'
      r'escape ::= ["\\/bfnrt] | "u" hex hex hex hex'
      '\n'
      'hex ::= [0-9a-fA-F]\n'
      r'number ::= "-"? int frac? exp?'
      '\n'
      'int ::= "0" | [1-9] [0-9]*\n'
      'frac ::= "." [0-9]+\n'
      'exp ::= [eE] [+-]? [0-9]+\n'
      'boolean ::= "true" | "false"\n'
      'null ::= "null"\n'
      r'ws ::= [ \t\n]*'
      '\n';
}

String _escape(String value) =>
    value.replaceAll(r'\', r'\\').replaceAll('"', r'\"');
