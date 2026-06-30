import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/bill_split_models.dart';
import '../models/split_result.dart';

/// Storage service for persisting bill split data
///
/// TODO: OPTIMIZATION - Replace with SQLCipher for encrypted on-device storage
/// For MVP, we use SharedPreferences + JSON which is fast to implement but:
/// - Not encrypted (use SQLCipher for sensitive financial data)
/// - Limited storage (use Drift/SQLite for large datasets)
/// - No offline sync (use Firebase Firestore for cloud backup)
///
/// Migration path: SharedPreferences → SQLCipher → Firestore hybrid
abstract class BillSplitStorageService {
  Future<void> saveSplitHistory(SplitResult result);
  Future<List<SplitResult>> getSplitHistory();
  Future<void> saveBill(Bill bill);
  Future<List<Bill>> getBillHistory();
  Future<void> clearHistory();
}

/// Implementation using SharedPreferences + JSON
/// Fast to implement for MVP, can be replaced with SQLCipher later
class LocalBillSplitStorage implements BillSplitStorageService {
  static const _splitHistoryKey = 'bill_split_history';
  static const _billHistoryKey = 'bill_history';

  SharedPreferences? _prefs;

  Future<SharedPreferences> get _preferences async {
    _prefs ??= await SharedPreferences.getInstance();
    return _prefs!;
  }

  @override
  Future<void> saveSplitHistory(SplitResult result) async {
    try {
      final prefs = await _preferences;
      final history = await getSplitHistory();
      history.insert(0, result); // Add to front (most recent first)

      // Keep only last 100 splits
      final trimmed = history.take(100).toList();
      final jsonList = trimmed.map((r) => _splitResultToJson(r)).toList();
      await prefs.setString(_splitHistoryKey, jsonEncode(jsonList));

      final summary = result.generateSummaryMessage();
      debugPrint(
        'Saved split: ${summary.substring(0, summary.length.clamp(0, 50))}...',
      );
    } catch (e) {
      debugPrint('Error saving split history: $e');
    }
  }

  @override
  Future<List<SplitResult>> getSplitHistory() async {
    try {
      final prefs = await _preferences;
      final jsonStr = prefs.getString(_splitHistoryKey);
      if (jsonStr == null) return [];

      final List<dynamic> jsonList = jsonDecode(jsonStr);
      return jsonList.map((j) => _splitResultFromJson(j)).toList();
    } catch (e) {
      debugPrint('Error loading split history: $e');
      return [];
    }
  }

  @override
  Future<void> saveBill(Bill bill) async {
    try {
      final prefs = await _preferences;
      final history = await getBillHistory();
      history.insert(0, bill);

      // Keep only last 50 bills
      final trimmed = history.take(50).toList();
      final jsonList = trimmed.map((b) => _billToJson(b)).toList();
      await prefs.setString(_billHistoryKey, jsonEncode(jsonList));
    } catch (e) {
      debugPrint('Error saving bill: $e');
    }
  }

  @override
  Future<List<Bill>> getBillHistory() async {
    try {
      final prefs = await _preferences;
      final jsonStr = prefs.getString(_billHistoryKey);
      if (jsonStr == null) return [];

      final List<dynamic> jsonList = jsonDecode(jsonStr);
      return jsonList.map((j) => _billFromJson(j)).toList();
    } catch (e) {
      debugPrint('Error loading bill history: $e');
      return [];
    }
  }

  @override
  Future<void> clearHistory() async {
    final prefs = await _preferences;
    await prefs.remove(_splitHistoryKey);
    await prefs.remove(_billHistoryKey);
  }

  // ============================================================================
  // JSON SERIALIZATION (TODO: Use freezed/json_serializable for production)
  // ============================================================================

  Map<String, dynamic> _splitResultToJson(SplitResult result) {
    return {
      'id': result.id,
      'bill': _billToJson(result.bill),
      'splits': result.splits
          .map(
            (s) => {
              'participantId': s.participant.id,
              'participantName': s.participant.name,
              'participantPhone': s.participant.phone,
              'amountPaise': s.amountPaise,
            },
          )
          .toList(),
      'splitType': result.splitType.name,
      'paidBy': result.paidBy.name,
      'splitOption': result.splitOption.name,
      'createdAt': result.createdAt.toIso8601String(),
      'note': result.note,
    };
  }

  SplitResult _splitResultFromJson(Map<String, dynamic> json) {
    final splits = (json['splits'] as List)
        .map(
          (s) => ParticipantSplit(
            participant: Participant(
              id: s['participantId'] ?? '',
              name: s['participantName'] ?? '',
              phone: s['participantPhone'],
            ),
            amountPaise: s['amountPaise'] ?? 0,
          ),
        )
        .toList();

    return SplitResult(
      id: json['id'] ?? '',
      bill: json['bill'] != null
          ? _billFromJson(json['bill'])
          : _createEmptyBill(),
      splits: splits,
      splitType: _parseSplitType(json['splitType']),
      paidBy: _parsePaidBy(json['paidBy']),
      splitOption: _parseSplitOption(json['splitOption']),
      createdAt: json['createdAt'] != null
          ? DateTime.parse(json['createdAt'])
          : DateTime.now(),
      note: json['note'],
    );
  }

  Bill _createEmptyBill() {
    return Bill(
      id: '',
      date: DateTime.now(),
      items: const [],
      subtotalPaise: 0,
      totalPaise: 0,
      createdAt: DateTime.now(),
    );
  }

  SplitType _parseSplitType(String? value) {
    if (value == null) return SplitType.equal;
    return SplitType.values.firstWhere(
      (e) => e.name == value,
      orElse: () => SplitType.equal,
    );
  }

  PaidBy _parsePaidBy(String? value) {
    if (value == null) return PaidBy.you;
    return PaidBy.values.firstWhere(
      (e) => e.name == value,
      orElse: () => PaidBy.you,
    );
  }

  SplitOption _parseSplitOption(String? value) {
    if (value == null) return SplitOption.equalSplit;
    return SplitOption.values.firstWhere(
      (e) => e.name == value,
      orElse: () => SplitOption.equalSplit,
    );
  }

  Map<String, dynamic> _billToJson(Bill bill) {
    return {
      'id': bill.id,
      'vendor': bill.vendor,
      'date': bill.date.toIso8601String(),
      'totalPaise': bill.totalPaise,
      'subtotalPaise': bill.subtotalPaise,
      'taxPaise': bill.taxPaise,
      'tipPaise': bill.tipPaise,
      'createdAt': bill.createdAt.toIso8601String(),
    };
  }

  Bill _billFromJson(Map<String, dynamic> json) {
    return Bill(
      id: json['id'] ?? '',
      vendor: json['vendor'],
      date: DateTime.parse(json['date']),
      items: const [], // Items not stored for history view
      totalPaise: json['totalPaise'] ?? 0,
      subtotalPaise: json['subtotalPaise'] ?? 0,
      taxPaise: json['taxPaise'] ?? 0,
      tipPaise: json['tipPaise'] ?? 0,
      createdAt: DateTime.parse(json['createdAt']),
    );
  }
}
