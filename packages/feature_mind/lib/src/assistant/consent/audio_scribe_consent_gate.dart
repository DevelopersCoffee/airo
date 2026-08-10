import '../../runtime/models/log_models.dart';
import '../../runtime/ports/operation_log_port.dart';
import 'jurisdiction_consent_rules.dart';

/// Thrown by [AudioScribeConsentGate.startRecording] when the encoder is
/// asked to run before consent was granted.
///
/// The gate's whole job is to make this the only way a caller finds out —
/// there is no boolean to check-then-ignore, because a check that can be
/// skipped is not a gate.
class ConsentRequiredException implements Exception {
  const ConsentRequiredException(this.reason);

  final String reason;

  @override
  String toString() => 'ConsentRequiredException: $reason';
}

/// A recording session's consent state, as recorded on the op log.
class ConsentRecord {
  const ConsentRecord({
    required this.jurisdiction,
    required this.grantedAtMs,
    required this.allPartiesNotified,
    required this.logSequence,
    this.revokedAtMs,
  });

  final ConsentJurisdiction jurisdiction;
  final int grantedAtMs;
  final bool allPartiesNotified;

  /// The sequence number of the `consent` op this record authorised. The
  /// timeline cites this the same way it cites any other op.
  final int logSequence;

  final int? revokedAtMs;

  bool get isRevoked => revokedAtMs != null;

  ConsentRecord revokedAt(int nowMs) => ConsentRecord(
    jurisdiction: jurisdiction,
    grantedAtMs: grantedAtMs,
    allPartiesNotified: allPartiesNotified,
    logSequence: logSequence,
    revokedAtMs: nowMs,
  );
}

/// The single door between an Audio Scribe screen and the microphone
/// encoder.
///
/// [startRecording] is the *only* method on this class that runs the
/// encoder, and it refuses to unless [grant] has already succeeded for this
/// gate instance. A screen that wants to record audio has no other route to
/// the encoder available to it — there is no bypass to reach for, because
/// the gate does not expose one. That is what "no code path reaches the
/// encoder without passing the gate" means in code rather than in prose, and
/// it is what `audio_scribe_consent_gate_test.dart` proves with a mutation
/// test: the guard clause below is the one line that test asserts must
/// exist, by deleting it and watching the suite fail.
class AudioScribeConsentGate {
  ConsentRecord? _consent;

  /// Null until [grant] has been called at least once for this gate.
  ConsentRecord? get consent => _consent;

  bool get isGranted => _consent != null && !_consent!.isRevoked;

  /// Records consent as a signed op and unlocks [startRecording].
  ///
  /// Two-party jurisdictions must pass [allPartiesNotified] as true — the
  /// caller is expected to have shown the "all parties notified" banner and
  /// required it be acknowledged before calling this. One-party
  /// jurisdictions may pass false; the op is still written, because the log
  /// entry — not the notification — is what makes the transcript
  /// defensible later.
  Future<ConsentRecord> grant({
    required OperationLogPort log,
    required String contextId,
    required ConsentJurisdiction jurisdiction,
    required bool allPartiesNotified,
    required int nowMs,
  }) async {
    if (jurisdiction.requiresAllPartyNotification && !allPartiesNotified) {
      throw const ConsentRequiredException(
        'This jurisdiction requires all parties to be notified before '
        'recording can start.',
      );
    }
    final sequence = await log.append(
      kind: MindOpKind.consent,
      title: 'Recording consent confirmed · ${jurisdiction.label}',
      contextId: contextId,
      detail: jurisdiction.requiresAllPartyNotification
          ? 'All parties notified.'
          : 'One-party consent jurisdiction; recorded for the record.',
    );
    final record = ConsentRecord(
      jurisdiction: jurisdiction,
      grantedAtMs: nowMs,
      allPartiesNotified: allPartiesNotified,
      logSequence: sequence,
    );
    _consent = record;
    return record;
  }

  /// Runs [encoderCall] if, and only if, consent is currently granted.
  ///
  /// This is the sole entry point to the encoder. There is no other public
  /// method here that invokes it, and no field exposing the underlying
  /// encoder for a caller to reach around this check.
  Future<T> startRecording<T>(Future<T> Function() encoderCall) async {
    final consent = _consent;
    if (consent == null || consent.isRevoked) {
      throw const ConsentRequiredException(
        'Recording consent has not been granted for this session.',
      );
    }
    return encoderCall();
  }

  /// Withdraws consent mid-recording.
  ///
  /// Appends a `consentRevoked` op and flips [isGranted] to false, so the
  /// next call to [startRecording] throws. Callers are responsible for
  /// stopping the encoder themselves (the encoder call already in flight is
  /// not cancellable from inside the gate) and for marking the transcript
  /// that resulted as partial.
  Future<int> revoke({
    required OperationLogPort log,
    required String contextId,
    required int nowMs,
  }) async {
    final consent = _consent;
    if (consent == null) {
      throw const ConsentRequiredException(
        'No consent has been granted to revoke.',
      );
    }
    _consent = consent.revokedAt(nowMs);
    return log.append(
      kind: MindOpKind.consentRevoked,
      title: 'Recording consent revoked mid-recording',
      contextId: contextId,
      detail: 'Transcript from op #${consent.logSequence} marked partial.',
    );
  }

  /// Resets the gate so a fresh recording session requires fresh consent.
  ///
  /// Consent authorises one capture, not the screen for its lifetime — a
  /// second recording is a second legal act.
  void reset() {
    _consent = null;
  }
}
