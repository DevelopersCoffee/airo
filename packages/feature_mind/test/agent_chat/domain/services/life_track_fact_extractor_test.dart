import 'package:core_domain/core_domain.dart';
import 'package:feature_mind/src/agent_chat/domain/services/life_track_fact_extractor.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const extractor = LifeTrackFactExtractor();

  test('extracts claim ids, broker, and document status from pasted text', () {
    final extracted = extractor.extractInsuranceClaim(
      'Track this claim from Policybazaar for Niva Bupa ReAssure 2.0. '
      'Claim ID 9001001, PB Ref ID 8002002. All documents received. Missed call.',
    );

    expect(extracted.templateId, 'insurance_claim_v1');
    expect(extracted.facts['Insurer'], 'Niva Bupa');
    expect(extracted.facts['Broker / Intermediary'], 'Policybazaar');
    expect(extracted.facts['Claim ID'], '9001001');
    expect(extracted.facts['Intermediary Reference'], '8002002');
    expect(extracted.facts['Product Name'], 'ReAssure 2.0');
    expect(
      extracted.facts[LifeTrackFactPatch.documentsReceivedKey],
      'received',
    );
    expect(extracted.facts['Follow-up Log'], contains('Missed call'));
    expect(extracted.title, contains('Niva Bupa'));
  });

  test('does not treat a pending-status question as a save request', () {
    expect(
      extractor.wantsRecord('What is pending on my insurance track?'),
      isFalse,
    );
    expect(
      extractor.wantsRecord('Track this claim: Niva Bupa Claim ID 9001001'),
      isTrue,
    );
  });

  test('detects study-progress storage without inventing a notes app', () {
    const prompt = 'how can i store my study progress with airo mind';
    expect(extractor.wantsStudyRecord(prompt), isTrue);
    expect(extractor.wantsRecord(prompt), isFalse);

    final extracted = extractor.extractStudyProgress(prompt);
    expect(extracted.templateId, 'study_progress_v1');
    expect(extracted.title, 'Study progress');
    expect(extracted.facts['Progress Notes'], contains('study progress'));
  });

  test('extracts a named subject for study progress', () {
    final extracted = extractor.extractStudyProgress(
      'Store my study progress for Java. Topic: queues using stacks.',
    );
    expect(extracted.title, 'Java study progress');
    expect(extracted.facts['Subject'], 'Java');
    expect(extracted.facts['Current Topic'], contains('queues'));
  });
}
