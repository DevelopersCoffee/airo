import 'dart:io';

import 'package:feature_iptv/product_identity.dart';
import 'package:flutter_test/flutter_test.dart';

const _forbiddenChrome = ['Airo TV', 'AIRO TV', 'Midas Stream'];

void main() {
  test('TvStoreProduct.displayName is Aika Stream', () {
    expect(TvStoreProduct.displayName, 'Aika Stream');
  });

  test(
    'feature_iptv presentation user-facing strings are Aika Stream, not Airo TV',
    () {
      final presentation = Directory('lib/presentation');
      expect(
        presentation.existsSync(),
        isTrue,
        reason:
            'Run from packages/feature_iptv. Looked for ${presentation.path}.',
      );

      final offenders = <String>[];
      for (final entity in presentation.listSync(recursive: true)) {
        if (entity is! File || !entity.path.endsWith('.dart')) continue;
        final literals = _quotedLiterals(entity.readAsStringSync());
        for (final literal in literals) {
          for (final banned in _forbiddenChrome) {
            if (literal.contains(banned)) {
              offenders.add('${entity.path}: "$literal"');
            }
          }
        }
      }

      expect(
        offenders,
        isEmpty,
        reason:
            'User-facing TV chrome must use ${TvStoreProduct.displayName}, '
            'not ${_forbiddenChrome.join(' / ')}.\n${offenders.join('\n')}',
      );
    },
  );
}

/// Quoted Dart string literals, skipping comments.
Iterable<String> _quotedLiterals(String source) sync* {
  final stripped = _stripComments(source);
  final pattern = RegExp(
    r"""'''(?:[^'\\]|\\.|'{1,2}(?!'))*'''|"""
    r'''"""(?:[^"\\]|\\.|"{1,2}(?!"))*"""|'''
    r"""'(?:[^'\\]|\\.)*'|"""
    r'''"(?:[^"\\]|\\.)*"''',
  );
  for (final match in pattern.allMatches(stripped)) {
    yield match.group(0)!;
  }
}

String _stripComments(String source) {
  final out = StringBuffer();
  var i = 0;
  var inString = false;
  String? quote;
  var inLineComment = false;
  var inBlockComment = false;
  while (i < source.length) {
    final ch = source[i];
    final next = i + 1 < source.length ? source[i + 1] : '';
    if (inLineComment) {
      if (ch == '\n') {
        inLineComment = false;
        out.write(ch);
      }
      i++;
      continue;
    }
    if (inBlockComment) {
      if (ch == '*' && next == '/') {
        inBlockComment = false;
        i += 2;
        continue;
      }
      i++;
      continue;
    }
    if (!inString && ch == '/' && next == '/') {
      inLineComment = true;
      i += 2;
      continue;
    }
    if (!inString && ch == '/' && next == '*') {
      inBlockComment = true;
      i += 2;
      continue;
    }
    if (!inString && (ch == "'" || ch == '"')) {
      inString = true;
      quote = ch;
      out.write(ch);
      i++;
      continue;
    }
    if (inString && ch == r'\' && i + 1 < source.length) {
      out.write(ch);
      out.write(source[i + 1]);
      i += 2;
      continue;
    }
    if (inString && ch == quote) {
      inString = false;
      quote = null;
    }
    out.write(ch);
    i++;
  }
  return out.toString();
}
