import 'package:equatable/equatable.dart';

import 'release_matrix.dart';

enum AiroContentRatingTarget {
  googlePlayIarc('google_play_iarc'),
  appStoreConnectAgeRating('app_store_connect_age_rating');

  const AiroContentRatingTarget(this.stableId);

  final String stableId;
}

enum AiroContentRatingFindingCode {
  unknownProfile('unknown_profile'),
  profileNotStoreEligible('profile_not_store_eligible'),
  finalRatingRequiresConsole('final_rating_requires_console'),
  appStoreConnectDeferred('app_store_connect_deferred'),
  childDirectedConflict('child_directed_conflict'),
  capabilityRequiresRatingReview('capability_requires_rating_review');

  const AiroContentRatingFindingCode(this.stableId);

  final String stableId;
}

class AiroContentRatingFinding extends Equatable {
  const AiroContentRatingFinding({
    required this.target,
    required this.code,
    required this.message,
    this.blocking = true,
  });

  final AiroContentRatingTarget target;
  final AiroContentRatingFindingCode code;
  final String message;
  final bool blocking;

  Map<String, Object?> toPublicMap() {
    return {
      'target': target.stableId,
      'code': code.stableId,
      'message': message,
      'blocking': blocking,
    };
  }

  @override
  List<Object?> get props => [target, code, message, blocking];
}

class AiroContentRatingQuestionAnswer extends Equatable {
  const AiroContentRatingQuestionAnswer({
    required this.topic,
    required this.answer,
    required this.note,
  });

  final String topic;
  final String answer;
  final String note;

  Map<String, Object?> toPublicMap() {
    return {'topic': topic, 'answer': answer, 'note': note};
  }

  @override
  List<Object?> get props => [topic, answer, note];
}

class AiroContentRatingPreflightRequest extends Equatable {
  const AiroContentRatingPreflightRequest({
    required this.profileId,
    this.targetAudienceMinimumAge = 16,
    this.userProvidedExternalMedia = true,
    this.hasAds = false,
    this.hasInAppPurchases = false,
    this.hasGambling = false,
    this.hasUserChat = false,
    this.hasLocationSharing = false,
    this.requiresAccountForPlayback = false,
    this.hasAppHostedMatureContent = false,
    this.hasViolenceInUi = false,
    this.hasSexualContentInUi = false,
    this.hasProfanityInUi = false,
    this.appStoreConnectInScope = false,
  });

  final String profileId;
  final int targetAudienceMinimumAge;
  final bool userProvidedExternalMedia;
  final bool hasAds;
  final bool hasInAppPurchases;
  final bool hasGambling;
  final bool hasUserChat;
  final bool hasLocationSharing;
  final bool requiresAccountForPlayback;
  final bool hasAppHostedMatureContent;
  final bool hasViolenceInUi;
  final bool hasSexualContentInUi;
  final bool hasProfanityInUi;
  final bool appStoreConnectInScope;

  @override
  List<Object?> get props => [
    profileId,
    targetAudienceMinimumAge,
    userProvidedExternalMedia,
    hasAds,
    hasInAppPurchases,
    hasGambling,
    hasUserChat,
    hasLocationSharing,
    requiresAccountForPlayback,
    hasAppHostedMatureContent,
    hasViolenceInUi,
    hasSexualContentInUi,
    hasProfanityInUi,
    appStoreConnectInScope,
  ];
}

class AiroContentRatingPreflight extends Equatable {
  AiroContentRatingPreflight({
    required this.profileId,
    required this.packageId,
    required this.displayName,
    required this.targetAudienceMinimumAge,
    required this.googlePlayExpectedRating,
    required this.appStoreExpectedRating,
    required this.appStoreConnectInScope,
    required Iterable<AiroContentRatingQuestionAnswer> questionnaireAnswers,
    required Iterable<AiroContentRatingFinding> findings,
    this.schemaVersion = kAiroReleaseMatrixSchemaVersion,
  }) : questionnaireAnswers = List.unmodifiable(questionnaireAnswers),
       findings = List.unmodifiable(findings);

  final String schemaVersion;
  final String profileId;
  final String? packageId;
  final String displayName;
  final int targetAudienceMinimumAge;
  final String googlePlayExpectedRating;
  final String appStoreExpectedRating;
  final bool appStoreConnectInScope;
  final List<AiroContentRatingQuestionAnswer> questionnaireAnswers;
  final List<AiroContentRatingFinding> findings;

  bool get readyForConsoleEntry {
    return !findings.any((finding) => finding.blocking);
  }

  Map<String, Object?> toPublicMap() {
    return {
      'schemaVersion': schemaVersion,
      'profileId': profileId,
      'packageId': packageId,
      'displayName': displayName,
      'targetAudienceMinimumAge': targetAudienceMinimumAge,
      'googlePlay': {
        'expectedRating': googlePlayExpectedRating,
        'finalRatingAssignedByConsole': true,
      },
      'appStoreConnect': {
        'expectedRating': appStoreExpectedRating,
        'inScope': appStoreConnectInScope,
        'finalRatingAssignedByConsole': true,
      },
      'readyForConsoleEntry': readyForConsoleEntry,
      'questionnaireAnswers': questionnaireAnswers
          .map((answer) => answer.toPublicMap())
          .toList(),
      'findings': findings.map((finding) => finding.toPublicMap()).toList(),
    };
  }

  String toMarkdown() {
    final buffer = StringBuffer()
      ..writeln('# Content Rating Preflight')
      ..writeln()
      ..writeln('| Area | Value |')
      ..writeln('| --- | --- |')
      ..writeln('| Profile | `$profileId` |')
      ..writeln('| Package | `${packageId ?? 'unknown'}` |')
      ..writeln('| Product | $displayName |')
      ..writeln('| Target audience minimum age | `$targetAudienceMinimumAge` |')
      ..writeln('| Ready for console entry | `$readyForConsoleEntry` |')
      ..writeln('| Google Play expected result | $googlePlayExpectedRating |')
      ..writeln('| App Store expected result | $appStoreExpectedRating |')
      ..writeln('| App Store Connect in scope | `$appStoreConnectInScope` |')
      ..writeln()
      ..writeln(
        'Final age ratings are assigned by store consoles after maintainers '
        'submit the questionnaires.',
      )
      ..writeln()
      ..writeln('## Questionnaire Answers')
      ..writeln()
      ..writeln('| Topic | Answer | Note |')
      ..writeln('| --- | --- | --- |');

    for (final answer in questionnaireAnswers) {
      buffer.writeln('| ${answer.topic} | ${answer.answer} | ${answer.note} |');
    }

    if (findings.isEmpty) {
      buffer
        ..writeln()
        ..writeln('No findings.');
      return buffer.toString();
    }

    buffer
      ..writeln()
      ..writeln('## Findings')
      ..writeln()
      ..writeln('| Target | Code | Blocking | Message |')
      ..writeln('| --- | --- | --- | --- |');
    for (final finding in findings) {
      buffer.writeln(
        '| `${finding.target.stableId}` | `${finding.code.stableId}` | '
        '`${finding.blocking}` | ${finding.message} |',
      );
    }

    return buffer.toString();
  }

  @override
  List<Object?> get props => [
    schemaVersion,
    profileId,
    packageId,
    displayName,
    targetAudienceMinimumAge,
    googlePlayExpectedRating,
    appStoreExpectedRating,
    appStoreConnectInScope,
    questionnaireAnswers,
    findings,
  ];
}

class AiroContentRatingPreflightRunner {
  const AiroContentRatingPreflightRunner({required this.matrix});

  final AiroReleaseMatrix matrix;

  AiroContentRatingPreflight run(AiroContentRatingPreflightRequest request) {
    final findings = <AiroContentRatingFinding>[];
    AiroReleaseProfile? profile;
    try {
      profile = matrix.profileById(request.profileId);
    } on StateError {
      findings.add(
        AiroContentRatingFinding(
          target: AiroContentRatingTarget.googlePlayIarc,
          code: AiroContentRatingFindingCode.unknownProfile,
          message: 'Unknown release profile: ${request.profileId}.',
        ),
      );
    }

    final googlePlayRule = profile?.distributionFor(
      AiroReleaseDistributionChannel.googlePlay,
    );
    if (profile != null &&
        (googlePlayRule == null ||
            googlePlayRule.status == AiroReleaseDistributionStatus.deferred ||
            googlePlayRule.status ==
                AiroReleaseDistributionStatus.unsupported ||
            googlePlayRule.status ==
                AiroReleaseDistributionStatus.validationOnly)) {
      findings.add(
        AiroContentRatingFinding(
          target: AiroContentRatingTarget.googlePlayIarc,
          code: AiroContentRatingFindingCode.profileNotStoreEligible,
          message:
              'Profile ${profile.id} is not in scope for Google Play rating.',
        ),
      );
    }

    findings.add(
      const AiroContentRatingFinding(
        target: AiroContentRatingTarget.googlePlayIarc,
        code: AiroContentRatingFindingCode.finalRatingRequiresConsole,
        blocking: false,
        message:
            'Google Play/IARC assigns the final rating after questionnaire '
            'submission.',
      ),
    );

    if (!request.appStoreConnectInScope) {
      findings.add(
        const AiroContentRatingFinding(
          target: AiroContentRatingTarget.appStoreConnectAgeRating,
          code: AiroContentRatingFindingCode.appStoreConnectDeferred,
          blocking: false,
          message:
              'App Store Connect age rating is deferred until iOS/tvOS enters '
              'release scope.',
        ),
      );
    } else {
      findings.add(
        const AiroContentRatingFinding(
          target: AiroContentRatingTarget.appStoreConnectAgeRating,
          code: AiroContentRatingFindingCode.finalRatingRequiresConsole,
          blocking: false,
          message:
              'App Store Connect assigns the final rating after questionnaire '
              'submission.',
        ),
      );
    }

    if (request.targetAudienceMinimumAge < 16) {
      findings.add(
        const AiroContentRatingFinding(
          target: AiroContentRatingTarget.googlePlayIarc,
          code: AiroContentRatingFindingCode.childDirectedConflict,
          message:
              'Target audience under 16 conflicts with the current privacy '
              'posture and must be reviewed before rating submission.',
        ),
      );
    }

    _addCapabilityFinding(findings, enabled: request.hasAds, capability: 'ads');
    _addCapabilityFinding(
      findings,
      enabled: request.hasInAppPurchases,
      capability: 'in-app purchases',
    );
    _addCapabilityFinding(
      findings,
      enabled: request.hasGambling,
      capability: 'gambling or contests',
    );
    _addCapabilityFinding(
      findings,
      enabled: request.hasUserChat,
      capability: 'chat or user-to-user interaction',
    );
    _addCapabilityFinding(
      findings,
      enabled: request.hasLocationSharing,
      capability: 'location sharing',
    );
    _addCapabilityFinding(
      findings,
      enabled: request.requiresAccountForPlayback,
      capability: 'account-gated playback',
    );
    _addCapabilityFinding(
      findings,
      enabled: request.hasAppHostedMatureContent,
      capability: 'app-hosted mature content',
    );

    return AiroContentRatingPreflight(
      profileId: request.profileId,
      packageId: profile?.packageId,
      displayName: profile?.displayName ?? request.profileId,
      targetAudienceMinimumAge: request.targetAudienceMinimumAge,
      googlePlayExpectedRating:
          'Teen / 12+ or stricter if questionnaire output requires it',
      appStoreExpectedRating:
          '12+ or stricter if questionnaire output requires it',
      appStoreConnectInScope: request.appStoreConnectInScope,
      questionnaireAnswers: _questionnaireAnswers(request),
      findings: findings,
    );
  }

  void _addCapabilityFinding(
    List<AiroContentRatingFinding> findings, {
    required bool enabled,
    required String capability,
  }) {
    if (!enabled) {
      return;
    }
    findings.add(
      AiroContentRatingFinding(
        target: AiroContentRatingTarget.googlePlayIarc,
        code: AiroContentRatingFindingCode.capabilityRequiresRatingReview,
        message:
            'Detected $capability; update the content-rating worksheet and '
            'store declarations before submission.',
      ),
    );
  }

  List<AiroContentRatingQuestionAnswer> _questionnaireAnswers(
    AiroContentRatingPreflightRequest request,
  ) {
    String yesNo(bool value) => value ? 'Yes' : 'No';

    return [
      AiroContentRatingQuestionAnswer(
        topic: 'User-provided external media / unrestricted network content',
        answer: yesNo(request.userProvidedExternalMedia),
        note:
            'Users can enter playlist or stream URLs; Airo does not provide '
            'channels, subscriptions, playlists, or streams.',
      ),
      AiroContentRatingQuestionAnswer(
        topic: 'Ads',
        answer: yesNo(request.hasAds),
        note: 'No advertising SDK or ad placement in the current TV profile.',
      ),
      AiroContentRatingQuestionAnswer(
        topic: 'In-app purchases',
        answer: yesNo(request.hasInAppPurchases),
        note: 'No purchase flow in the current TV profile.',
      ),
      AiroContentRatingQuestionAnswer(
        topic: 'Gambling or contests',
        answer: yesNo(request.hasGambling),
        note: 'No gambling, betting, or contest mechanic.',
      ),
      AiroContentRatingQuestionAnswer(
        topic: 'Chat or user interaction',
        answer: yesNo(request.hasUserChat),
        note: 'No chat, social feed, or user-to-user communication.',
      ),
      AiroContentRatingQuestionAnswer(
        topic: 'Location sharing',
        answer: yesNo(request.hasLocationSharing),
        note: 'No location sharing in the TV IPTV flow.',
      ),
      AiroContentRatingQuestionAnswer(
        topic: 'Account required for playback',
        answer: yesNo(request.requiresAccountForPlayback),
        note: 'IPTV playback does not require account sign-in.',
      ),
      AiroContentRatingQuestionAnswer(
        topic: 'App-hosted mature content',
        answer: yesNo(request.hasAppHostedMatureContent),
        note: 'Airo TV is a media player and does not host media content.',
      ),
      AiroContentRatingQuestionAnswer(
        topic: 'Violence in app UI',
        answer: yesNo(request.hasViolenceInUi),
        note: 'No violent content is provided by the app UI.',
      ),
      AiroContentRatingQuestionAnswer(
        topic: 'Sexual content or nudity in app UI',
        answer: yesNo(request.hasSexualContentInUi),
        note: 'No sexual content or nudity is provided by the app UI.',
      ),
      AiroContentRatingQuestionAnswer(
        topic: 'Profanity or crude humor in app UI',
        answer: yesNo(request.hasProfanityInUi),
        note: 'No profanity or crude humor is provided by the app UI.',
      ),
      const AiroContentRatingQuestionAnswer(
        topic: 'Content disclaimer',
        answer: 'Yes',
        note:
            'Airo TV is a media player only; users are responsible for their '
            'own lawful content sources.',
      ),
    ];
  }
}
