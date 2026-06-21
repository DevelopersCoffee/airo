import 'package:airo_app/core/services/litert_lm_service.dart';
import 'package:airo_app/features/bill_split/domain/services/receipt_litert_lm_extraction_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('extracts receipt items from local LiteRT-LM JSON output', () async {
    final client = _FakeLiteRtLmClient(
      response: '''
{
  "vendor": "Instamart",
  "items": [
    {"name": "Potato 1kg", "price": 55.00, "quantity": 1},
    {"name": "Milk", "price": 34.00, "quantity": 2}
  ],
  "fees": [{"label": "Delivery fee", "amount": 15.00}],
  "total": 138.00
}
''',
    );
    final service = ReceiptLiteRtLmExtractionService(
      llm: LiteRtLmService(client: client),
    );

    final receipt = await service.parseReceiptText(
      'Instamart Potato 55 Milk 34 x2 Delivery 15 Total 138',
      imagePath: '/tmp/receipt.jpg',
    );

    expect(receipt, isNotNull);
    expect(receipt!.vendor, 'Instamart');
    expect(receipt.items.map((item) => item.name), ['Potato 1kg', 'Milk']);
    expect(receipt.items[1].quantity, 2);
    expect(receipt.itemTotalPaise, 12300);
    expect(receipt.fees.single.amountPaise, 1500);
    expect(receipt.grandTotalPaise, 13800);
    expect(client.generatedPrompts.single, contains('Instamart Potato'));
    expect(client.generatedSystemPrompts.single, contains('valid JSON'));
  });
}

class _FakeLiteRtLmClient implements LiteRtLmClient {
  _FakeLiteRtLmClient({required this.response});

  final String response;
  final generatedPrompts = <String>[];
  final generatedSystemPrompts = <String?>[];

  @override
  Future<bool> activeModelExists() async => true;

  @override
  Future<String> generate({
    required String prompt,
    required LiteRtLmBackend backend,
    required int maxTokens,
    String? systemPrompt,
  }) async {
    generatedPrompts.add(prompt);
    generatedSystemPrompts.add(systemPrompt);
    return response;
  }

  @override
  Future<void> initialize({String? huggingFaceToken}) async {}

  @override
  Future<void> installModel({
    required String url,
    required LiteRtLmModelKind modelKind,
    String? huggingFaceToken,
  }) async {}
}
