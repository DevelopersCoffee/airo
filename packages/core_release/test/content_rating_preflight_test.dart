import 'package:core_release/core_release.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Airo content rating preflight', () {
    AiroContentRatingPreflight run({
      String profileId = 'tv',
      int targetAudienceMinimumAge = 16,
      bool userProvidedExternalMedia = true,
      bool hasAds = false,
      bool hasInAppPurchases = false,
      bool hasGambling = false,
      bool hasUserChat = false,
      bool hasLocationSharing = false,
      bool requiresAccountForPlayback = false,
      bool hasAppHostedMatureContent = false,
      bool appStoreConnectInScope = false,
    }) {
      return AiroContentRatingPreflightRunner(
        matrix: AiroReleaseMatrix.v2Default(),
      ).run(
        AiroContentRatingPreflightRequest(
          profileId: profileId,
          targetAudienceMinimumAge: targetAudienceMinimumAge,
          userProvidedExternalMedia: userProvidedExternalMedia,
          hasAds: hasAds,
          hasInAppPurchases: hasInAppPurchases,
          hasGambling: hasGambling,
          hasUserChat: hasUserChat,
          hasLocationSharing: hasLocationSharing,
          requiresAccountForPlayback: requiresAccountForPlayback,
          hasAppHostedMatureContent: hasAppHostedMatureContent,
          appStoreConnectInScope: appStoreConnectInScope,
        ),
      );
    }

    test('builds console-ready default posture for Airo TV', () {
      final preflight = run();

      expect(preflight.readyForConsoleEntry, isTrue);
      expect(preflight.profileId, 'tv');
      expect(preflight.packageId, 'io.airo.app.tv');
      expect(preflight.googlePlayExpectedRating, contains('Teen / 12+'));
      expect(preflight.appStoreExpectedRating, contains('12+'));
      expect(
        preflight.questionnaireAnswers.map((answer) => answer.toPublicMap()),
        containsAll([
          containsPair('topic', 'Ads'),
          containsPair('topic', 'In-app purchases'),
          containsPair(
            'topic',
            'User-provided external media / unrestricted network content',
          ),
        ]),
      );
      expect(
        preflight.questionnaireAnswers
            .singleWhere((answer) => answer.topic == 'Ads')
            .answer,
        'No',
      );
      expect(
        preflight.questionnaireAnswers
            .singleWhere(
              (answer) => answer.topic.startsWith('User-provided external'),
            )
            .answer,
        'Yes',
      );
    });

    test('keeps console-assigned final rating as non-blocking finding', () {
      final preflight = run();

      expect(
        preflight.findings.map((finding) => finding.code),
        contains(AiroContentRatingFindingCode.finalRatingRequiresConsole),
      );
      expect(
        preflight.findings
            .where(
              (finding) =>
                  finding.code ==
                      AiroContentRatingFindingCode.finalRatingRequiresConsole &&
                  finding.blocking,
            )
            .toList(),
        isEmpty,
      );
    });

    test('marks App Store Connect deferred unless it is in scope', () {
      final deferred = run();
      final inScope = run(appStoreConnectInScope: true);

      expect(
        deferred.findings.map((finding) => finding.code),
        contains(AiroContentRatingFindingCode.appStoreConnectDeferred),
      );
      expect(
        inScope.findings.map((finding) => finding.code),
        isNot(contains(AiroContentRatingFindingCode.appStoreConnectDeferred)),
      );
      expect(inScope.readyForConsoleEntry, isTrue);
    });

    test('blocks if target audience conflicts with privacy posture', () {
      final preflight = run(targetAudienceMinimumAge: 12);

      expect(preflight.readyForConsoleEntry, isFalse);
      expect(
        preflight.findings.map((finding) => finding.code),
        contains(AiroContentRatingFindingCode.childDirectedConflict),
      );
    });

    test('blocks when newly declared capabilities need rating review', () {
      final preflight = run(
        hasAds: true,
        hasInAppPurchases: true,
        hasGambling: true,
        hasUserChat: true,
        hasLocationSharing: true,
        requiresAccountForPlayback: true,
        hasAppHostedMatureContent: true,
      );

      expect(preflight.readyForConsoleEntry, isFalse);
      expect(
        preflight.findings
            .where(
              (finding) =>
                  finding.code ==
                  AiroContentRatingFindingCode.capabilityRequiresRatingReview,
            )
            .length,
        7,
      );
    });

    test('rejects unknown profiles', () {
      final preflight = run(profileId: 'missing');

      expect(preflight.readyForConsoleEntry, isFalse);
      expect(preflight.packageId, isNull);
      expect(
        preflight.findings.map((finding) => finding.code),
        contains(AiroContentRatingFindingCode.unknownProfile),
      );
    });

    test('public output does not claim store ratings are final', () {
      final output = run().toPublicMap();

      expect(output['readyForConsoleEntry'], isTrue);
      expect(
        (output['googlePlay']!
            as Map<String, Object?>)['finalRatingAssignedByConsole'],
        isTrue,
      );
      expect(output.toString(), isNot(contains('finalRating:')));
      expect(output.toString(), contains('finalRatingAssignedByConsole'));
    });
  });
}
