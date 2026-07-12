import 'package:core_domain/core_domain.dart';

import '../../connectivity/connectivity_service.dart';
import 'template_registry.dart';

enum LifeTrackTemplateFallbackStatus { noFallbackNeeded, recommended, noMatch }

enum LifeTrackTemplateFallbackReason { offline, generationFailed }

class LifeTrackTemplateFallbackResult {
  const LifeTrackTemplateFallbackResult._({
    required this.status,
    this.reason,
    this.template,
    this.matchedKeywords = const <String>[],
  });

  const LifeTrackTemplateFallbackResult.noFallbackNeeded()
    : this._(status: LifeTrackTemplateFallbackStatus.noFallbackNeeded);

  const LifeTrackTemplateFallbackResult.recommended({
    required LifeTrackTemplateFallbackReason reason,
    required LifeTrackTemplate template,
    required List<String> matchedKeywords,
  }) : this._(
         status: LifeTrackTemplateFallbackStatus.recommended,
         reason: reason,
         template: template,
         matchedKeywords: matchedKeywords,
       );

  const LifeTrackTemplateFallbackResult.noMatch({
    required LifeTrackTemplateFallbackReason reason,
  }) : this._(status: LifeTrackTemplateFallbackStatus.noMatch, reason: reason);

  final LifeTrackTemplateFallbackStatus status;
  final LifeTrackTemplateFallbackReason? reason;
  final LifeTrackTemplate? template;
  final List<String> matchedKeywords;

  bool get shouldFallback =>
      status != LifeTrackTemplateFallbackStatus.noFallbackNeeded;
}

class LifeTrackTemplateFallbackResolver {
  LifeTrackTemplateFallbackResolver({
    required this._registry,
    required this._connectivityService,
    Map<String, List<String>>? templateKeywords,
  }) : _templateKeywords =
           templateKeywords ?? _defaultTemplateKeywordsByTemplateId;

  final TemplateRegistry _registry;
  final ConnectivityService _connectivityService;
  final Map<String, List<String>> _templateKeywords;

  Future<LifeTrackTemplateFallbackResult> resolve(
    String prompt, {
    Object? generationFailure,
  }) async {
    final normalizedPrompt = _normalize(prompt);
    if (normalizedPrompt.isEmpty) {
      return generationFailure != null
          ? const LifeTrackTemplateFallbackResult.noMatch(
              reason: LifeTrackTemplateFallbackReason.generationFailed,
            )
          : const LifeTrackTemplateFallbackResult.noFallbackNeeded();
    }

    if (generationFailure != null) {
      return _resolveMatch(
        normalizedPrompt,
        reason: LifeTrackTemplateFallbackReason.generationFailed,
      );
    }

    if (!await _connectivityService.isConnected) {
      return _resolveMatch(
        normalizedPrompt,
        reason: LifeTrackTemplateFallbackReason.offline,
      );
    }

    return const LifeTrackTemplateFallbackResult.noFallbackNeeded();
  }

  LifeTrackTemplateFallbackResult _resolveMatch(
    String normalizedPrompt, {
    required LifeTrackTemplateFallbackReason reason,
  }) {
    _ScoredTemplateMatch? bestMatch;

    for (final template in _registry.getAll()) {
      final keywords =
          _templateKeywords[template.templateId] ?? const <String>[];
      final matchedKeywords = keywords
          .where((keyword) => _matchesKeyword(normalizedPrompt, keyword))
          .toList(growable: false);
      if (matchedKeywords.isEmpty) {
        continue;
      }

      final candidate = _ScoredTemplateMatch(
        template: template,
        matchedKeywords: matchedKeywords,
      );
      if (bestMatch == null || candidate.score > bestMatch.score) {
        bestMatch = candidate;
      }
    }

    if (bestMatch == null) {
      return LifeTrackTemplateFallbackResult.noMatch(reason: reason);
    }

    return LifeTrackTemplateFallbackResult.recommended(
      reason: reason,
      template: bestMatch.template,
      matchedKeywords: bestMatch.matchedKeywords,
    );
  }

  bool _matchesKeyword(String normalizedPrompt, String keyword) {
    final normalizedKeyword = _normalize(keyword);
    if (normalizedKeyword.contains(' ')) {
      return normalizedPrompt.contains(normalizedKeyword);
    }

    final tokens = normalizedPrompt.split(' ');
    return tokens.contains(normalizedKeyword);
  }

  String _normalize(String value) => value
      .toLowerCase()
      .replaceAll(RegExp(r'[^a-z0-9]+'), ' ')
      .trim()
      .replaceAll(RegExp(r'\s+'), ' ');
}

class _ScoredTemplateMatch {
  const _ScoredTemplateMatch({
    required this.template,
    required this.matchedKeywords,
  });

  final LifeTrackTemplate template;
  final List<String> matchedKeywords;

  int get score => matchedKeywords.length;
}

const Map<String, List<String>> _defaultTemplateKeywordsByTemplateId = {
  'real_estate_under_construction_v1': <String>[
    'flat',
    'apartment',
    'home',
    'house',
    'builder',
    'property',
    'real estate',
    'rera',
  ],
  'university_admission_v1': <String>[
    'admission',
    'college',
    'education',
    'enrollment',
    'student',
    'university',
    'visa',
  ],
  'medical_surgery_v1': <String>[
    'doctor',
    'hospital',
    'medical',
    'operation',
    'procedure',
    'recovery',
    'surgery',
    'treatment',
  ],
  'insurance_claim_v1': <String>[
    'claim',
    'coverage',
    'incident',
    'insurance',
    'insurer',
    'reimbursement',
    'settlement',
  ],
  'car_purchase_v1': <String>[
    'auto',
    'automobile',
    'car',
    'driving',
    'loan',
    'parking',
    'vehicle',
  ],
};
