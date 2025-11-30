import 'dart:convert';

import 'package:core_domain/core_domain.dart';

/// Utilities for parsing structured data from LLM responses.
///
/// LLMs often return JSON embedded in markdown or with extra text.
/// These utilities help extract and validate the structured data.
abstract final class LLMJsonParser {
  /// Extracts JSON object from LLM response text.
  ///
  /// Handles common patterns:
  /// - Pure JSON
  /// - JSON in markdown code blocks
  /// - JSON with surrounding text
  static Result<Map<String, dynamic>> parseObject(String text) {
    try {
      final cleaned = _extractJson(text);
      if (cleaned == null) {
        return const Failure(
          ValidationFailure(message: 'No JSON object found in response'),
        );
      }

      final parsed = jsonDecode(cleaned);
      if (parsed is! Map<String, dynamic>) {
        return const Failure(
          ValidationFailure(message: 'Response is not a JSON object'),
        );
      }

      return Success(parsed);
    } on FormatException catch (e) {
      return Failure(ValidationFailure(
        message: 'Invalid JSON: ${e.message}',
        cause: e,
      ));
    }
  }

  /// Extracts JSON array from LLM response text.
  static Result<List<dynamic>> parseArray(String text) {
    try {
      final cleaned = _extractJson(text);
      if (cleaned == null) {
        return const Failure(
          ValidationFailure(message: 'No JSON array found in response'),
        );
      }

      final parsed = jsonDecode(cleaned);
      if (parsed is! List) {
        return const Failure(
          ValidationFailure(message: 'Response is not a JSON array'),
        );
      }

      return Success(parsed);
    } on FormatException catch (e) {
      return Failure(ValidationFailure(
        message: 'Invalid JSON: ${e.message}',
        cause: e,
      ));
    }
  }

  /// Extracts and validates JSON with a schema.
  static Result<T> parseWithSchema<T>({
    required String text,
    required T Function(Map<String, dynamic>) fromJson,
    List<String>? requiredFields,
  }) {
    final objResult = parseObject(text);
    if (objResult.isFailure) {
      return Failure(objResult.failure);
    }

    final obj = objResult.value;

    // Validate required fields
    if (requiredFields != null) {
      final missing = requiredFields.where((f) => !obj.containsKey(f)).toList();
      if (missing.isNotEmpty) {
        return Failure(ValidationFailure(
          message: 'Missing required fields: ${missing.join(", ")}',
          errors: {for (final f in missing) f: 'Required field missing'},
        ));
      }
    }

    try {
      return Success(fromJson(obj));
    } catch (e) {
      return Failure(ValidationFailure(
        message: 'Failed to parse response: $e',
        cause: e,
      ));
    }
  }

  /// Extracts JSON string from text with various formats.
  static String? _extractJson(String text) {
    final trimmed = text.trim();

    // Already valid JSON
    if (_isValidJson(trimmed)) {
      return trimmed;
    }

    // Extract from markdown code block
    final codeBlockMatch = RegExp(
      r'```(?:json)?\s*([\s\S]*?)\s*```',
      multiLine: true,
    ).firstMatch(trimmed);
    if (codeBlockMatch != null) {
      final content = codeBlockMatch.group(1)?.trim();
      if (content != null && _isValidJson(content)) {
        return content;
      }
    }

    // Find JSON object or array in text
    final objectMatch = RegExp(r'\{[\s\S]*\}').firstMatch(trimmed);
    if (objectMatch != null && _isValidJson(objectMatch.group(0)!)) {
      return objectMatch.group(0);
    }

    final arrayMatch = RegExp(r'\[[\s\S]*\]').firstMatch(trimmed);
    if (arrayMatch != null && _isValidJson(arrayMatch.group(0)!)) {
      return arrayMatch.group(0);
    }

    return null;
  }

  static bool _isValidJson(String text) {
    try {
      jsonDecode(text);
      return true;
    } catch (_) {
      return false;
    }
  }
}

/// Common response parsers for Airo use cases.
abstract final class AiroParsers {
  /// Parses receipt extraction response.
  static Result<ReceiptData> parseReceipt(String response) =>
      LLMJsonParser.parseWithSchema(
        text: response,
        fromJson: ReceiptData.fromJson,
        requiredFields: ['items', 'total'],
      );

  /// Parses bill split suggestion response.
  static Result<BillSplitData> parseBillSplit(String response) =>
      LLMJsonParser.parseWithSchema(
        text: response,
        fromJson: BillSplitData.fromJson,
        requiredFields: ['splits'],
      );
}

/// Receipt extraction result.
class ReceiptData {
  const ReceiptData({
    required this.items,
    required this.total,
    this.vendor,
    this.date,
    this.subtotal,
    this.tax,
  });

  factory ReceiptData.fromJson(Map<String, dynamic> json) => ReceiptData(
        items: (json['items'] as List)
            .map((e) => ReceiptItem.fromJson(e as Map<String, dynamic>))
            .toList(),
        total: (json['total'] as num).toDouble(),
        vendor: json['vendor'] as String?,
        date: json['date'] as String?,
        subtotal: (json['subtotal'] as num?)?.toDouble(),
        tax: (json['tax'] as num?)?.toDouble(),
      );

  final List<ReceiptItem> items;
  final double total;
  final String? vendor;
  final String? date;
  final double? subtotal;
  final double? tax;
}

/// Single item from a receipt.
class ReceiptItem {
  const ReceiptItem({
    required this.name,
    required this.price,
    this.quantity = 1,
  });

  factory ReceiptItem.fromJson(Map<String, dynamic> json) => ReceiptItem(
        name: json['name'] as String,
        price: (json['price'] as num).toDouble(),
        quantity: json['quantity'] as int? ?? 1,
      );

  final String name;
  final double price;
  final int quantity;
}

/// Bill split result.
class BillSplitData {
  const BillSplitData({required this.splits, this.totalAmount});

  factory BillSplitData.fromJson(Map<String, dynamic> json) => BillSplitData(
        splits: (json['splits'] as List)
            .map((e) => PersonSplit.fromJson(e as Map<String, dynamic>))
            .toList(),
        totalAmount: (json['totalAmount'] as num?)?.toDouble(),
      );

  final List<PersonSplit> splits;
  final double? totalAmount;
}

/// Single person's split.
class PersonSplit {
  const PersonSplit({required this.name, required this.amount, this.items});

  factory PersonSplit.fromJson(Map<String, dynamic> json) => PersonSplit(
        name: json['name'] as String,
        amount: (json['amount'] as num).toDouble(),
        items: (json['items'] as List?)?.cast<String>(),
      );

  final String name;
  final double amount;
  final List<String>? items;
}

