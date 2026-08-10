/// Jurisdiction-aware consent rules for Audio Scribe.
///
/// Not a legal database — a small static table naming the jurisdictions where
/// recording a conversation without telling every party is a crime, and
/// treating everywhere else as one-party consent. A one-party jurisdiction
/// still requires *a* consent record (that is what makes a transcript
/// defensible later); it just does not require the notification step before
/// the encoder is allowed to start.
library;

/// Whether a jurisdiction requires every party to be notified before
/// recording, or only the recording party's own consent.
enum ConsentRule {
  /// Only the person operating Audio Scribe needs to consent. The consent
  /// event is still logged, but no "all parties notified" step blocks
  /// recording.
  onePartyConsent,

  /// Every party to the conversation must be notified before recording
  /// starts. Audio Scribe's consent banner blocks on this notification step.
  twoPartyConsent,
}

/// One jurisdiction Audio Scribe knows the recording law for.
class ConsentJurisdiction {
  const ConsentJurisdiction({
    required this.code,
    required this.label,
    required this.rule,
  });

  /// Short stable identifier, e.g. `US-CA` or `DE`. Stored on the consent op
  /// so the log can show which rule governed a given recording.
  final String code;

  /// Human-readable name shown in the jurisdiction picker.
  final String label;

  final ConsentRule rule;

  bool get requiresAllPartyNotification => rule == ConsentRule.twoPartyConsent;
}

/// The jurisdictions Audio Scribe has an explicit rule for.
///
/// Two-party (all-party) consent US states, per the commonly cited list of
/// states whose wiretapping statutes require every participant's consent:
/// California, Connecticut, Florida, Illinois, Maryland, Massachusetts,
/// Montana, Nevada, New Hampshire, Pennsylvania, Washington. Plus a small set
/// of countries whose recording law is commonly described as all-party.
/// Everywhere else defaults to one-party via [defaultJurisdiction] — this is
/// deliberately not exhaustive; it is the seam a legal review tightens later,
/// not a substitute for one.
const List<ConsentJurisdiction> knownJurisdictions = [
  ConsentJurisdiction(
    code: 'US-CA',
    label: 'United States — California',
    rule: ConsentRule.twoPartyConsent,
  ),
  ConsentJurisdiction(
    code: 'US-CT',
    label: 'United States — Connecticut',
    rule: ConsentRule.twoPartyConsent,
  ),
  ConsentJurisdiction(
    code: 'US-FL',
    label: 'United States — Florida',
    rule: ConsentRule.twoPartyConsent,
  ),
  ConsentJurisdiction(
    code: 'US-IL',
    label: 'United States — Illinois',
    rule: ConsentRule.twoPartyConsent,
  ),
  ConsentJurisdiction(
    code: 'US-MD',
    label: 'United States — Maryland',
    rule: ConsentRule.twoPartyConsent,
  ),
  ConsentJurisdiction(
    code: 'US-MA',
    label: 'United States — Massachusetts',
    rule: ConsentRule.twoPartyConsent,
  ),
  ConsentJurisdiction(
    code: 'US-MT',
    label: 'United States — Montana',
    rule: ConsentRule.twoPartyConsent,
  ),
  ConsentJurisdiction(
    code: 'US-NV',
    label: 'United States — Nevada',
    rule: ConsentRule.twoPartyConsent,
  ),
  ConsentJurisdiction(
    code: 'US-NH',
    label: 'United States — New Hampshire',
    rule: ConsentRule.twoPartyConsent,
  ),
  ConsentJurisdiction(
    code: 'US-PA',
    label: 'United States — Pennsylvania',
    rule: ConsentRule.twoPartyConsent,
  ),
  ConsentJurisdiction(
    code: 'US-WA',
    label: 'United States — Washington',
    rule: ConsentRule.twoPartyConsent,
  ),
  ConsentJurisdiction(
    code: 'DE',
    label: 'Germany',
    rule: ConsentRule.twoPartyConsent,
  ),
  ConsentJurisdiction(
    code: 'FR',
    label: 'France',
    rule: ConsentRule.twoPartyConsent,
  ),
  ConsentJurisdiction(
    code: 'US-OTHER',
    label: 'United States — other state',
    rule: ConsentRule.onePartyConsent,
  ),
  ConsentJurisdiction(
    code: 'GB',
    label: 'United Kingdom',
    rule: ConsentRule.onePartyConsent,
  ),
  ConsentJurisdiction(
    code: 'IN',
    label: 'India',
    rule: ConsentRule.onePartyConsent,
  ),
];

/// Used when a person has not picked a jurisdiction yet. Defaults to the
/// strictest posture available before a jurisdiction is chosen: a two-party
/// rule blocks on notification, so an unset jurisdiction never lets a
/// recording start on a weaker assumption than the one it will end up under.
const ConsentJurisdiction unselectedJurisdiction = ConsentJurisdiction(
  code: 'UNSELECTED',
  label: 'Select where this conversation is taking place…',
  rule: ConsentRule.twoPartyConsent,
);

ConsentJurisdiction jurisdictionByCode(String code) =>
    knownJurisdictions.firstWhere(
      (jurisdiction) => jurisdiction.code == code,
      orElse: () => unselectedJurisdiction,
    );
