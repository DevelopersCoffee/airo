import 'package:flutter/foundation.dart';

/// What kind of thing an operation records.
///
/// The Windows runtime console renders each of these differently, so this is a
/// closed set rather than a string: a new op kind must be a deliberate change
/// to the log's vocabulary, not a typo that renders as blank.
enum MindOpKind {
  note,
  scan,
  voice,
  transcript,
  inference,
  automation,
  merge,
  revoke,
  import,

  /// A person confirmed consent to record a conversation, before the encoder
  /// was allowed to run.
  ///
  /// Distinct from [revoke], which is device-key revocation. This kind is the
  /// legal record: it is what makes a transcript defensible later, in a
  /// one-party jurisdiction as much as a two-party one.
  consent,

  /// Consent was withdrawn while a recording was in progress. The encoder
  /// stops and the transcript it produced is marked partial.
  consentRevoked,
}

/// Whether this operation's signature checked out.
///
/// `unverified` is not `unknown`. An op whose signature does not verify must
/// look different from one that does — that difference is the entire reason
/// the column exists.
enum SignatureState { verified, unverified, unsigned }

/// One entry in the append-only log.
///
/// [sequence] is the op number the whole product cites: the agent's answers
/// point at it, the inspector shows it, the console sorts by it.
@immutable
class MindOp {
  const MindOp({
    required this.sequence,
    required this.kind,
    required this.title,
    required this.contextId,
    required this.deviceName,
    required this.signature,
    required this.recordedAtMs,
    this.detail = '',
  });

  final int sequence;
  final MindOpKind kind;
  final String title;

  /// Empty for ops that belong to no context — a device revocation, for one.
  final String contextId;

  /// The device that wrote it, not the device reading it.
  final String deviceName;
  final SignatureState signature;
  final int recordedAtMs;

  /// The console's secondary line. Empty when there is nothing to add; never a
  /// duplicate of [title].
  final String detail;

  MindOp copyWith({SignatureState? signature}) => MindOp(
    sequence: sequence,
    kind: kind,
    title: title,
    contextId: contextId,
    deviceName: deviceName,
    signature: signature ?? this.signature,
    recordedAtMs: recordedAtMs,
    detail: detail,
  );

  @override
  bool operator ==(Object other) =>
      other is MindOp &&
      other.sequence == sequence &&
      other.kind == kind &&
      other.title == title &&
      other.contextId == contextId &&
      other.deviceName == deviceName &&
      other.signature == signature &&
      other.recordedAtMs == recordedAtMs &&
      other.detail == detail;

  @override
  int get hashCode => Object.hash(
    sequence,
    kind,
    title,
    contextId,
    deviceName,
    signature,
    recordedAtMs,
    detail,
  );
}
