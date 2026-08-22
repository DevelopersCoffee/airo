import 'package:core_workers/core_workers.dart';
import 'package:feature_mind/src/agent_chat/domain/services/research/document_intelligence.dart';
import 'package:flutter_test/flutter_test.dart';

/// Uncompressed PDF with a single visible text operator. Not a scanned page.
const _pdf =
    '%PDF-1.1\n'
    '1 0 obj\n'
    '<< /Length 68 >>\n'
    'stream\n'
    'BT /F1 12 Tf (Qwen is a family of language models) Tj ET\n'
    'endstream\n'
    'endobj\n'
    '%%EOF\n';

const _htmlTable = '''
<html><body>
  <h1>Benchmarks</h1>
  <p>Scores come from the official card.</p>
  <table>
    <tr><th>Model</th><th>Score</th></tr>
    <tr><td>Qwen-7B</td><td>64.5</td></tr>
  </table>
  <pre><code>fn main() { println!("qwen"); }</code></pre>
</body></html>
''';

const _markdown = '''
# Qwen

Qwen is a family of language models.

| Model | Params |
| --- | --- |
| Qwen-7B | 7B |

```rust
fn main() {}
```
''';

void main() {
  test('html tables become structured rows, not dumped cells', () {
    final doc = extractDocument(_htmlTable);

    expect(doc.tables, contains('Qwen-7B | 64.5'));
    expect(doc.evidenceText, contains('Qwen-7B | 64.5'));
    expect(doc.codeBlocks.join(' '), contains('fn main()'));
    expect(doc.paragraphs.join(' '), isNot(contains('fn main()')));
  });

  test('uncompressed pdf text is extracted and stays untrusted', () {
    final doc = extractDocument(_pdf, url: 'https://arxiv.org/pdf/2401.12345');

    expect(doc.paragraphs.join(' '), contains('Qwen is a family'));
    expect(doc.evidenceText.toLowerCase(), isNot(contains('%pdf')));
    expect(doc.evidenceText.toLowerCase(), isNot(contains('endobj')));
    expect(doc.trustLevel.name, 'untrusted');
  });

  test('empty pdf without extractable text is empty evidence', () {
    final doc = extractDocument('%PDF-1.1\n1 0 obj\n<< >>\nendobj\n%%EOF\n');

    expect(doc.evidenceText.trim(), isEmpty);
  });

  test('markdown tables and fenced code stay structured', () {
    final doc = extractDocument(
      _markdown,
      url: 'https://example.org/readme.md',
    );

    expect(doc.tables, contains('Qwen-7B | 7B'));
    expect(doc.codeBlocks.join(' '), contains('fn main()'));
    expect(doc.paragraphs.join(' '), contains('Qwen is a family'));
    expect(doc.paragraphs.join(' '), isNot(contains('fn main()')));
  });

  test('document intelligence is isolate-safe via runOffMain', () async {
    final doc = await runOffMain(() => extractDocument(_pdf));

    expect(doc.paragraphs.join(' '), contains('language models'));
  });
}
