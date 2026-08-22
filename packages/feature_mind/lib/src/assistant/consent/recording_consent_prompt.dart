import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'jurisdiction_consent_rules.dart';

/// Whether a recording screen asks the person to pick a jurisdiction and
/// confirm consent before the microphone can start.
///
/// Off by default: the jurisdiction picker sat between "open the recorder" and
/// "record", and every capture paid it again because
/// [AudioScribeConsentGate.reset]'s rule is that consent authorises one
/// capture, not the screen. Turning it off does **not** remove the gate —
/// `AudioScribeConsentGate` is still the only route to the encoder, and a
/// consent op is still appended to the Mind log before recording starts, now
/// under [implicitConsentJurisdiction] instead of a picked one. What changes is
/// who supplies the jurisdiction, not whether the act is recorded.
///
/// Override to `true` to restore the picker — that is how the consent-flow
/// widget tests still exercise it, and how a legal review re-enables it for a
/// build or a region without touching either screen.
final recordingConsentPromptProvider = Provider<bool>((ref) => false);

/// The jurisdiction a consent op carries when [recordingConsentPromptProvider]
/// is off and nobody picked one.
///
/// One-party so the gate does not block on an "all parties notified"
/// acknowledgment that no UI asked for — claiming everyone was notified when
/// nothing said so would make the op log lie. The label is what the log shows,
/// so it says plainly that no jurisdiction was declared.
const ConsentJurisdiction implicitConsentJurisdiction = ConsentJurisdiction(
  code: 'UNSPECIFIED',
  label: 'Not specified — consent prompt disabled',
  rule: ConsentRule.onePartyConsent,
);
