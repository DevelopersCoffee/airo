import 'package:core_domain/core_domain.dart';

/// Safety check result.
class SafetyCheckResult {
  final bool isAllowed;
  final String? blockedReason;
  final List<String> warnings;

  const SafetyCheckResult({
    required this.isAllowed,
    this.blockedReason,
    this.warnings = const [],
  });

  factory SafetyCheckResult.allowed({List<String> warnings = const []}) {
    return SafetyCheckResult(isAllowed: true, warnings: warnings);
  }

  factory SafetyCheckResult.blocked(String reason) {
    return SafetyCheckResult(isAllowed: false, blockedReason: reason);
  }
}

/// Safety rule for content filtering.
abstract interface class SafetyRule {
  /// Unique identifier for this rule.
  String get id;

  /// Human-readable description.
  String get description;

  /// Check if the input passes this rule.
  SafetyCheckResult check(String input);
}

/// Rule that blocks medical advice requests.
class NoMedicalAdviceRule implements SafetyRule {
  @override
  String get id => 'no_medical_advice';

  @override
  String get description =>
      'Blocks requests for medical diagnosis or treatment advice';

  static final _medicalPatterns = [
    RegExp(
      r'\b(diagnos|symptom|treatment|cure|medic|prescri|dosage)\b',
      caseSensitive: false,
    ),
    RegExp(
      r'\b(should i take|what medicine|is it cancer|do i have)\b',
      caseSensitive: false,
    ),
  ];

  @override
  SafetyCheckResult check(String input) {
    for (final pattern in _medicalPatterns) {
      if (pattern.hasMatch(input)) {
        return SafetyCheckResult.blocked(
          'I cannot provide medical advice. Please consult a healthcare professional.',
        );
      }
    }
    return SafetyCheckResult.allowed();
  }
}

/// Rule that blocks investment/financial advice requests.
class NoInvestmentAdviceRule implements SafetyRule {
  @override
  String get id => 'no_investment_advice';

  @override
  String get description =>
      'Blocks requests for investment or financial advice';

  static final _investmentPatterns = [
    RegExp(
      r'\b(should i (buy|sell|invest)|stock tip|crypto advice)\b',
      caseSensitive: false,
    ),
    RegExp(
      r'\b(guaranteed return|get rich|financial advice)\b',
      caseSensitive: false,
    ),
  ];

  @override
  SafetyCheckResult check(String input) {
    for (final pattern in _investmentPatterns) {
      if (pattern.hasMatch(input)) {
        return SafetyCheckResult.blocked(
          'I cannot provide investment advice. Please consult a financial advisor.',
        );
      }
    }
    return SafetyCheckResult.allowed();
  }
}

/// Rule that blocks harmful content requests.
class NoHarmfulContentRule implements SafetyRule {
  @override
  String get id => 'no_harmful_content';

  @override
  String get description => 'Blocks requests for harmful or dangerous content';

  static final _harmfulPatterns = [
    RegExp(r'\b(how to (hack|steal|hurt|kill|harm))\b', caseSensitive: false),
    RegExp(r'\b(make (bomb|weapon|drug))\b', caseSensitive: false),
  ];

  @override
  SafetyCheckResult check(String input) {
    for (final pattern in _harmfulPatterns) {
      if (pattern.hasMatch(input)) {
        return SafetyCheckResult.blocked('I cannot help with this request.');
      }
    }
    return SafetyCheckResult.allowed();
  }
}

/// Rule that detects potential PII (Personally Identifiable Information).
class PIIDetectionRule implements SafetyRule {
  @override
  String get id => 'pii_detection';

  @override
  String get description => 'Warns about potential PII in input';

  static final _piiPatterns = [
    // Email
    RegExp(r'\b[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Z|a-z]{2,}\b'),
    // Phone (various formats)
    RegExp(r'\b(\+\d{1,3}[-.\s]?)?\(?\d{3}\)?[-.\s]?\d{3}[-.\s]?\d{4}\b'),
    // SSN
    RegExp(r'\b\d{3}[-.\s]?\d{2}[-.\s]?\d{4}\b'),
    // Credit card
    RegExp(r'\b\d{4}[-.\s]?\d{4}[-.\s]?\d{4}[-.\s]?\d{4}\b'),
  ];

  @override
  SafetyCheckResult check(String input) {
    final warnings = <String>[];
    for (final pattern in _piiPatterns) {
      if (pattern.hasMatch(input)) {
        warnings.add('Input may contain personal information');
        break;
      }
    }
    return SafetyCheckResult.allowed(warnings: warnings);
  }
}

/// Rule that limits input length.
class MaxLengthRule implements SafetyRule {
  final int maxLength;

  MaxLengthRule({this.maxLength = 10000});

  @override
  String get id => 'max_length';

  @override
  String get description => 'Limits input length to prevent abuse';

  @override
  SafetyCheckResult check(String input) {
    if (input.length > maxLength) {
      return SafetyCheckResult.blocked(
        'Input too long. Maximum $maxLength characters allowed.',
      );
    }
    return SafetyCheckResult.allowed();
  }
}

/// Safety guardrails manager.
class SafetyGuardrails {
  final List<SafetyRule> _inputRules = [];
  final List<SafetyRule> _outputRules = [];

  /// Default constructor.
  SafetyGuardrails();

  /// Add a safety rule for input filtering.
  void addInputRule(SafetyRule rule) {
    _inputRules.add(rule);
  }

  /// Add a safety rule for output filtering.
  void addOutputRule(SafetyRule rule) {
    _outputRules.add(rule);
  }

  /// Add a rule (legacy - adds to input rules).
  void addRule(SafetyRule rule) {
    _inputRules.add(rule);
  }

  /// Remove a rule by ID from both input and output rules.
  void removeRule(String ruleId) {
    _inputRules.removeWhere((r) => r.id == ruleId);
    _outputRules.removeWhere((r) => r.id == ruleId);
  }

  /// Check input against all input rules.
  Result<String> checkInput(String input) {
    final warnings = <String>[];

    for (final rule in _inputRules) {
      final result = rule.check(input);
      if (!result.isAllowed) {
        return Err(
          AIError(result.blockedReason ?? 'Content blocked by safety rules'),
          StackTrace.current,
        );
      }
      warnings.addAll(result.warnings);
    }

    return Ok(input);
  }

  /// Check output against all output rules.
  Result<String> checkOutput(String output) {
    final warnings = <String>[];

    for (final rule in _outputRules) {
      final result = rule.check(output);
      if (!result.isAllowed) {
        return Err(
          AIError(result.blockedReason ?? 'Output blocked by safety rules'),
          StackTrace.current,
        );
      }
      warnings.addAll(result.warnings);
    }

    return Ok(output);
  }

  /// Get all registered input rules.
  List<SafetyRule> get inputRules => List.unmodifiable(_inputRules);

  /// Get all registered output rules.
  List<SafetyRule> get outputRules => List.unmodifiable(_outputRules);

  /// Get all registered rules (legacy - returns input rules).
  List<SafetyRule> get rules => List.unmodifiable(_inputRules);

  /// Create with default rules.
  factory SafetyGuardrails.withDefaults() {
    final guardrails = SafetyGuardrails();
    // Input rules
    guardrails.addInputRule(NoMedicalAdviceRule());
    guardrails.addInputRule(NoInvestmentAdviceRule());
    guardrails.addInputRule(NoHarmfulContentRule());
    guardrails.addInputRule(PIIDetectionRule());
    guardrails.addInputRule(MaxLengthRule());
    // Output rules (same harmful content check)
    guardrails.addOutputRule(NoHarmfulContentRule());
    return guardrails;
  }
}
