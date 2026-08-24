import 'package:core_data/core_data.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('encodeLine produces compact single-line JSON', () {
    final line = CompactJsonl.encodeLine({
      'template_id': 'insurance_claim_v1',
      'title': 'Insurance',
    });
    expect(line.contains('\n'), isFalse);
    expect(line.contains(' '), isFalse);
    expect(CompactJsonl.decodeLine(line)['template_id'], 'insurance_claim_v1');
  });

  test('parse and encodeAll round-trip JSONL rows', () {
    final rows = [
      {'a': 1, 'b': 'two'},
      {'c': true},
    ];
    final encoded = CompactJsonl.encodeAll(rows);
    expect(encoded.split('\n'), hasLength(2));
    expect(CompactJsonl.parse(encoded), rows);
  });
}
