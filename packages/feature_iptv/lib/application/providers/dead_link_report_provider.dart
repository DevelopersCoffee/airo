import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'iptv_providers.dart' show sharedPreferencesProvider;

const deadLinkReportsStorageKey = 'dead_link_reports_v1';
const deadLinkReportsMaxStored = 20;

/// A user-triggered "this channel is broken" report (issues/04-recovery-
/// states.md). [technicalDetail] is already redacted upstream by
/// [AiroPlaybackDiagnostic.technicalDetail] -- source URIs never appear
/// here beyond `scheme://host[:port]`.
class DeadLinkReport {
  const DeadLinkReport({
    required this.channelName,
    required this.diagnosticCode,
    required this.userMessage,
    required this.reportedAt,
    this.technicalDetail,
  });

  final String channelName;
  final String diagnosticCode;
  final String userMessage;
  final DateTime reportedAt;
  final String? technicalDetail;

  Map<String, Object?> toJson() => {
    'channelName': channelName,
    'diagnosticCode': diagnosticCode,
    'userMessage': userMessage,
    'reportedAt': reportedAt.toIso8601String(),
    'technicalDetail': technicalDetail,
  };

  static DeadLinkReport fromJson(Map<String, Object?> json) => DeadLinkReport(
    channelName: json['channelName'] as String,
    diagnosticCode: json['diagnosticCode'] as String,
    userMessage: json['userMessage'] as String,
    reportedAt: DateTime.parse(json['reportedAt'] as String),
    technicalDetail: json['technicalDetail'] as String?,
  );
}

/// Persists dead-link reports to device storage only. Nothing here ever
/// makes a network call or leaves the device -- sending reports elsewhere
/// requires a separate, explicit user action that does not exist yet.
class DeadLinkReportStorage {
  DeadLinkReportStorage(this._prefs);

  final SharedPreferences _prefs;

  List<DeadLinkReport> readAll() {
    final raw = _prefs.getStringList(deadLinkReportsStorageKey) ?? const [];
    return raw
        .map(
          (entry) => DeadLinkReport.fromJson(
            jsonDecode(entry) as Map<String, Object?>,
          ),
        )
        .toList(growable: false);
  }

  Future<void> save(DeadLinkReport report) async {
    final updated = [report, ...readAll()]
        .take(deadLinkReportsMaxStored)
        .map((r) => jsonEncode(r.toJson()))
        .toList(growable: false);
    await _prefs.setStringList(deadLinkReportsStorageKey, updated);
  }
}

final deadLinkReportStorageProvider = Provider<DeadLinkReportStorage>((ref) {
  return DeadLinkReportStorage(ref.watch(sharedPreferencesProvider));
});
