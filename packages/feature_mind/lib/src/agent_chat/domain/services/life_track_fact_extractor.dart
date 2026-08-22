import 'package:core_domain/core_domain.dart';

class ExtractedLifeTrackFacts {
  const ExtractedLifeTrackFacts({
    required this.title,
    required this.templateId,
    required this.facts,
  });

  final String title;
  final String templateId;
  final Map<String, String> facts;

  bool get isEmpty => facts.isEmpty;
}

/// Pulls insurer, policy, claim IDs, and document status from user-provided
/// text. Does not read email or attachments — only what the user pasted.
class LifeTrackFactExtractor {
  const LifeTrackFactExtractor();

  ExtractedLifeTrackFacts extractInsuranceClaim(String prompt) {
    final facts = <String, String>{};
    final insurer = _insurer(prompt);
    if (insurer != null) facts['Insurer'] = insurer;

    final policyNumber = _firstMatch(prompt, _policyNumberPattern);
    if (policyNumber != null) facts['Policy Number'] = policyNumber;

    final broker = _broker(prompt);
    if (broker != null) facts['Broker / Intermediary'] = broker;

    final product = _product(prompt);
    if (product != null) facts['Product Name'] = product;

    final claimId = _firstMatch(prompt, _claimIdPattern);
    if (claimId != null) facts['Claim ID'] = claimId;

    final intermediaryRef = _firstMatch(prompt, _intermediaryRefPattern);
    if (intermediaryRef != null) {
      facts['Intermediary Reference'] = intermediaryRef;
    }

    if (claimId != null || intermediaryRef != null) {
      facts['Claim Submission Reference'] = intermediaryRef ?? claimId!;
    }

    final claimType = _claimType(prompt);
    if (claimType != null) facts['Claim Type'] = claimType;

    if (_documentsReceived(prompt)) {
      facts[LifeTrackFactPatch.documentsReceivedKey] = 'received';
      facts['Evidence Notes'] = 'Documents received for this claim.';
    }

    final followUp = _followUp(prompt);
    if (followUp != null) facts['Follow-up Log'] = followUp;

    return ExtractedLifeTrackFacts(
      title: _title(insurer: insurer, claimType: claimType, claimId: claimId),
      templateId: 'insurance_claim_v1',
      facts: facts,
    );
  }

  bool wantsRecord(String prompt) {
    final lower = prompt.toLowerCase();
    final mentionsJourney =
        lower.contains('claim') ||
        lower.contains('insurance') ||
        lower.contains('reimbursement');
    if (!mentionsJourney) return false;
    return RegExp(
      r'(save|store|record|log)\s+(this|my|the)|start tracking|help me track|track this',
      caseSensitive: false,
    ).hasMatch(prompt);
  }

  bool wantsStudyRecord(String prompt) {
    final lower = prompt.toLowerCase();
    if (wantsRecord(prompt)) return false;
    if (lower.contains('study progress') ||
        lower.contains('revision progress') ||
        lower.contains('learning progress')) {
      return true;
    }
    final mentionsStudy =
        lower.contains('study') ||
        lower.contains('exam') ||
        lower.contains('homework') ||
        lower.contains('syllabus') ||
        lower.contains('coursework');
    if (!mentionsStudy) return false;
    return RegExp(
      r'\b(store|save|record|log|track|progress)\b',
      caseSensitive: false,
    ).hasMatch(prompt);
  }

  ExtractedLifeTrackFacts extractStudyProgress(String prompt) {
    final facts = <String, String>{};
    final subject = _studySubject(prompt);
    if (subject != null) facts['Subject'] = subject;

    final topic = _labeledValue(prompt, const [
      'topic',
      'chapter',
      'current topic',
    ]);
    if (topic != null) facts['Current Topic'] = topic;

    final exam = _labeledValue(prompt, const [
      'exam',
      'exam date',
      'goal date',
    ]);
    if (exam != null) facts['Exam or Goal Date'] = exam;

    final next = _labeledValue(prompt, const ['next', 'next session']);
    if (next != null) facts['Next Session Plan'] = next;

    facts['Progress Notes'] = _studyProgressNotes(prompt);

    return ExtractedLifeTrackFacts(
      title: subject == null ? 'Study progress' : '$subject study progress',
      templateId: 'study_progress_v1',
      facts: facts,
    );
  }

  ExtractedLifeTrackFacts extractHospitalStay(String prompt) {
    final facts = <String, String>{};
    final hospital = _hospital(prompt);
    if (hospital != null) facts['Hospital'] = hospital;

    final date = _surgeryDate(prompt);
    if (date != null) facts['Surgery Date'] = date;

    final tests = _preOpTests(prompt);
    if (tests != null) facts['Required Tests List'] = tests;

    final auth = _authRef(prompt);
    if (auth != null) facts['Insurance Authorization Reference'] = auth;

    return ExtractedLifeTrackFacts(
      title: hospital == null ? 'Hospital stay' : 'Surgery at $hospital',
      templateId: 'medical_surgery_v1',
      facts: facts,
    );
  }

  ExtractedLifeTrackFacts extractPropertyPurchase(String prompt) {
    final facts = <String, String>{};
    final rera = _rera(prompt);
    if (rera != null) facts['RERA Registration Number'] = rera;

    final builder = _builderName(prompt);
    if (builder != null) facts['Builder Track Record Notes'] = builder;

    final floor = _targetFloor(prompt);
    if (floor != null) facts['Your Target Floor'] = floor;

    final project = _propertyProject(prompt);
    if (project != null) facts['Project'] = project;

    final title = [
      if (builder != null) builder,
      if (project != null) project,
      if (builder == null && project == null) 'Property purchase',
    ].join(' ');
    return ExtractedLifeTrackFacts(
      title: title,
      templateId: 'real_estate_under_construction_v1',
      facts: facts,
    );
  }

  String? _studySubject(String prompt) {
    final labeled = _labeledValue(prompt, const [
      'subject',
      'course',
      'class',
      'paper',
    ]);
    if (labeled != null) return labeled;
    final match = RegExp(
      r'\b(?:in|for|on)\s+([A-Za-z][A-Za-z0-9+#.]{1,24})\b',
    ).firstMatch(prompt);
    final value = match?.group(1)?.trim();
    if (value == null) return null;
    const skip = {
      'my',
      'the',
      'this',
      'airo',
      'mind',
      'chat',
      'local',
      'device',
    };
    if (skip.contains(value.toLowerCase())) return null;
    return value;
  }

  String _studyProgressNotes(String prompt) {
    final trimmed = prompt.trim();
    if (trimmed.length <= 160) return trimmed;
    return '${trimmed.substring(0, 157).trimRight()}...';
  }

  String _title({
    required String? insurer,
    required String? claimType,
    required String? claimId,
  }) {
    final buffer = StringBuffer(insurer ?? 'Insurance');
    if (claimType != null) {
      buffer.write(' $claimType');
    } else {
      buffer.write(' claim');
    }
    if (claimId != null) {
      buffer.write(' $claimId');
    }
    return buffer.toString();
  }

  String? _insurer(String prompt) {
    final lower = prompt.toLowerCase();
    if (lower.contains('niva bupa') ||
        RegExp(r'\bniva\b', caseSensitive: false).hasMatch(prompt)) {
      return 'Niva Bupa';
    }
    if (lower.contains('star insurance') || lower.contains('star health')) {
      return 'Star Insurance';
    }
    return _labeledValue(prompt, const ['insurer', 'insurance company']);
  }

  String? _broker(String prompt) {
    final lower = prompt.toLowerCase();
    if (lower.contains('policybazaar') || lower.contains('policy bazaar')) {
      return 'Policybazaar';
    }
    return _labeledValue(prompt, const ['broker', 'intermediary']);
  }

  String? _product(String prompt) {
    final match = RegExp(
      r'reassure\s*2\.0',
      caseSensitive: false,
    ).firstMatch(prompt);
    if (match != null) return 'ReAssure 2.0';
    return null;
  }

  String? _claimType(String prompt) {
    final lower = prompt.toLowerCase();
    if (lower.contains('reimbursement')) return 'reimbursement';
    if (lower.contains('cashless')) return 'cashless';
    return null;
  }

  bool _documentsReceived(String prompt) {
    final lower = prompt.toLowerCase();
    return lower.contains('documents received') ||
        lower.contains('all documents received') ||
        lower.contains('docs received');
  }

  String? _followUp(String prompt) {
    final lower = prompt.toLowerCase();
    final parts = <String>[];
    if (lower.contains('missed call')) {
      parts.add('Missed call from claims team.');
    }
    if (_documentsReceived(prompt)) {
      parts.add('Broker confirmed documents received.');
    }
    if (lower.contains('claim') &&
        (lower.contains('initiated') || lower.contains('has been initiated'))) {
      parts.add('Claim initiated.');
    }
    if (parts.isEmpty) return null;
    return parts.join(' ');
  }

  String? _hospital(String prompt) {
    final match = RegExp(
      r'(?:surgery|stay|admitted)?\s*(?:at|in)\s+'
      r'([A-Z][A-Za-z0-9& ]{1,40}Hospital)',
      caseSensitive: false,
    ).firstMatch(prompt);
    final value = match?.group(1)?.trim();
    if (value == null || value.isEmpty) return null;
    return value.replaceAll(RegExp(r'\s+'), ' ');
  }

  String? _surgeryDate(String prompt) {
    final match = RegExp(
      r'\b(\d{1,2}(?:st|nd|rd|th)?\s+'
      r'(?:Jan|Feb|Mar|Apr|May|Jun|Jul|Aug|Sep|Sept|Oct|Nov|Dec)[a-z]*)\b',
      caseSensitive: false,
    ).firstMatch(prompt);
    return match?.group(1)?.trim();
  }

  String? _preOpTests(String prompt) {
    final match = RegExp(
      r'pre-?op(?:erative)?\s+tests?\s+(.+?)(?:,\s*auth|\.|$)',
      caseSensitive: false,
    ).firstMatch(prompt);
    final value = match?.group(1)?.trim();
    if (value == null || value.isEmpty) return null;
    return value.replaceAll(RegExp(r'\s+and\s+', caseSensitive: false), ', ');
  }

  String? _authRef(String prompt) {
    return _firstMatch(
      prompt,
      RegExp(
        r'auth(?:orization)?\s*ref(?:erence)?\s*[:\-–]?\s*([A-Z0-9][A-Z0-9\-]{3,})',
        caseSensitive: false,
      ),
    );
  }

  String? _rera(String prompt) {
    return _firstMatch(
      prompt,
      RegExp(r'\bRERA\s+([A-Z0-9]{8,})\b', caseSensitive: false),
    );
  }

  String? _builderName(String prompt) {
    final match = RegExp(
      r'\bfrom\s+([A-Z][A-Za-z0-9&]+(?:\s+[A-Z][A-Za-z0-9&]+)?)\b',
    ).firstMatch(prompt);
    return match?.group(1)?.trim();
  }

  String? _targetFloor(String prompt) {
    return _firstMatch(
      prompt,
      RegExp(r'\bfloor\s+(\d{1,3})\b', caseSensitive: false),
    );
  }

  String? _propertyProject(String prompt) {
    final tower = RegExp(
      r'\b(Tower\s+[A-Z0-9]+)\b',
      caseSensitive: false,
    ).firstMatch(prompt);
    if (tower != null) {
      final value = tower.group(1)!.trim();
      return value
          .split(' ')
          .map(
            (part) => part.isEmpty
                ? part
                : '${part[0].toUpperCase()}${part.substring(1)}',
          )
          .join(' ');
    }
    return _labeledValue(prompt, const ['project', 'tower']);
  }

  String? _firstMatch(String prompt, RegExp pattern) {
    return pattern.firstMatch(prompt)?.group(1)?.trim();
  }

  String? _labeledValue(String prompt, List<String> labels) {
    for (final label in labels) {
      final match = RegExp(
        '$label\\s*[:\\-]\\s*(.+)',
        caseSensitive: false,
      ).firstMatch(prompt);
      final value = match?.group(1)?.trim();
      if (value != null && value.isNotEmpty) {
        return value.split(RegExp(r'[\n,.]')).first.trim();
      }
    }
    return null;
  }

  static final _claimIdPattern = RegExp(
    r'(?:claim\s*id|claim\s*no\.?)\s*[:\-–]?\s*([A-Z0-9]{5,20})',
    caseSensitive: false,
  );

  static final _intermediaryRefPattern = RegExp(
    r'(?:pb\s*ref(?:erence)?(?:\s*id)?|ref(?:erence)?\.?\s*id|ref\.?\s*id)\s*[:\-–]?\s*([A-Z0-9]{5,20})',
    caseSensitive: false,
  );

  static final _policyNumberPattern = RegExp(
    r'(?:policy\s*(?:no\.?|number))\s*[:\-–]?\s*(P\/[0-9\/]+|[A-Z0-9][A-Z0-9\/\-]{8,})',
    caseSensitive: false,
  );
}
