import 'dart:convert';

import 'package:uuid/uuid.dart';

import '../../../../core/services/litert_lm_service.dart';
import '../models/receipt_item.dart';

/// Parses OCR text into receipt structure using a local LiteRT-LM model.
class ReceiptLiteRtLmExtractionService {
  ReceiptLiteRtLmExtractionService({
    LiteRtLmService? llm,
    this._uuid = const Uuid(),
  }) : _llm = llm ?? LiteRtLmService();

  final LiteRtLmService _llm;
  final Uuid _uuid;

  Future<ParsedReceipt?> parseReceiptText(
    String rawText, {
    String? imagePath,
  }) async {
    final normalizedText = rawText.trim();
    if (normalizedText.isEmpty || !await _llm.isAvailable()) return null;

    final response = await _llm.generateText(
      _buildPrompt(normalizedText),
      systemPrompt: _systemPrompt,
    );
    if (response == null || response.trim().isEmpty) return null;

    return _parseResponse(response, imagePath: imagePath);
  }

  String _buildPrompt(String rawText) {
    return '''
Extract the line-item receipt data from this OCR text.

Receipt OCR:
$rawText
''';
  }

  String get _systemPrompt => '''
Return only valid JSON for this schema:
{
  "vendor": "store name or null",
  "items": [{"name": "item name", "price": 45.00, "quantity": 1}],
  "fees": [{"label": "delivery fee", "amount": 10.00}],
  "total": 133.00
}
Use rupee decimal numbers. Ignore addresses, status text, payment IDs, and ads.
''';

  ParsedReceipt? _parseResponse(String response, {String? imagePath}) {
    try {
      final jsonText = _extractJsonObject(response);
      if (jsonText == null) return null;

      final decoded = json.decode(jsonText);
      if (decoded is! Map<String, dynamic>) return null;

      final items = _parseItems(decoded['items']);
      if (items.isEmpty) return null;

      final fees = _parseFees(decoded['fees']);
      final itemTotal = items.fold<int>(
        0,
        (sum, item) => sum + item.totalPricePaise,
      );
      final feeTotal = fees
          .where((fee) => !fee.isFree)
          .fold<int>(0, (sum, fee) => sum + fee.amountPaise);
      final grandTotal = _readPaise(decoded['total']) ?? itemTotal + feeTotal;

      return ParsedReceipt(
        id: _uuid.v4(),
        vendor: decoded['vendor']?.toString(),
        orderDate: DateTime.now(),
        items: items,
        fees: fees,
        itemTotalPaise: itemTotal,
        grandTotalPaise: grandTotal,
        imagePath: imagePath,
        parsedAt: DateTime.now(),
      );
    } on FormatException {
      return null;
    } on TypeError {
      return null;
    }
  }

  List<ReceiptItem> _parseItems(Object? value) {
    if (value is! List) return const [];

    final items = <ReceiptItem>[];
    for (final item in value) {
      if (item is! Map) continue;
      final name = item['name']?.toString().trim() ?? '';
      final unitPrice = _readPaise(item['price']);
      final quantity = _readQuantity(item['quantity']);
      if (name.isEmpty || unitPrice == null || unitPrice <= 0) continue;

      items.add(
        ReceiptItem(
          id: _uuid.v4(),
          name: name,
          quantity: quantity,
          unitPricePaise: unitPrice,
          totalPricePaise: unitPrice * quantity,
        ),
      );
    }
    return items;
  }

  List<ReceiptFee> _parseFees(Object? value) {
    if (value is! List) return const [];

    final fees = <ReceiptFee>[];
    for (final fee in value) {
      if (fee is! Map) continue;
      final amount = _readPaise(fee['amount']);
      if (amount == null || amount <= 0) continue;
      fees.add(
        ReceiptFee(
          type: _feeTypeFromLabel(fee['label']?.toString()),
          amountPaise: amount,
        ),
      );
    }
    return fees;
  }

  FeeType _feeTypeFromLabel(String? label) {
    final normalized = label?.toLowerCase() ?? '';
    if (normalized.contains('delivery')) return FeeType.delivery;
    if (normalized.contains('handling')) return FeeType.handling;
    if (normalized.contains('pack')) return FeeType.packaging;
    if (normalized.contains('tax') || normalized.contains('gst')) {
      return FeeType.tax;
    }
    if (normalized.contains('tip')) return FeeType.tip;
    return FeeType.other;
  }

  int _readQuantity(Object? value) {
    if (value is int && value > 0) return value;
    if (value is num && value > 0) return value.round();
    return int.tryParse(value?.toString() ?? '') ?? 1;
  }

  int? _readPaise(Object? value) {
    if (value is num) return (value * 100).round();
    final text = value?.toString().replaceAll(RegExp(r'[^\d.]'), '') ?? '';
    if (text.isEmpty) return null;
    final parsed = double.tryParse(text);
    return parsed == null ? null : (parsed * 100).round();
  }

  String? _extractJsonObject(String response) {
    final match = RegExp(r'\{[\s\S]*\}').firstMatch(response);
    return match?.group(0);
  }
}
