import 'package:core_remote_views/core_remote_views.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Airo remote view contracts', () {
    final now = DateTime.utc(2026, 7, 14, 10);

    AiroRemoteViewItem item({
      String itemId = 'media-1',
      AiroRemoteViewItemKind kind = AiroRemoteViewItemKind.media,
      String primaryText = 'Live Sports',
      String? secondaryText = 'Now',
      String? thumbnailRef = 'thumb-1',
      bool playable = true,
      int rank = 0,
      String? contentRef = 'content-1',
    }) {
      return AiroRemoteViewItem(
        itemId: itemId,
        kind: kind,
        primaryText: primaryText,
        secondaryText: secondaryText,
        thumbnailRef: thumbnailRef,
        playable: playable,
        rank: rank,
        contentRef: contentRef,
      );
    }

    AiroRemoteView view({
      String viewId = 'view-1',
      AiroRemoteViewType type = AiroRemoteViewType.searchResults,
      AiroRemoteViewProfile profile = AiroRemoteViewProfile.liteReceiver,
      AiroRemoteViewRenderTier renderTier =
          AiroRemoteViewRenderTier.lightweight,
      AiroRemoteViewCachePolicy cachePolicy =
          AiroRemoteViewCachePolicy.cacheable,
      DateTime? generatedAt,
      DateTime? expiresAt,
      List<AiroRemoteViewItem>? items,
    }) {
      return AiroRemoteView(
        viewId: viewId,
        type: type,
        profile: profile,
        renderTier: renderTier,
        cachePolicy: cachePolicy,
        generatedAt: generatedAt ?? now,
        expiresAt: expiresAt ?? now.add(const Duration(minutes: 5)),
        items: items ?? [item()],
      );
    }

    test('lite search view accepts compact result set', () {
      final remoteView = view(
        items: List.generate(
          20,
          (index) => item(itemId: 'media-$index', rank: index),
        ),
      );

      expect(remoteView.validate(now), const [
        AiroRemoteViewValidationCode.accepted,
      ]);
      expect(remoteView.isExpired(now), isFalse);
      expect(remoteView.toPublicMap()['itemCount'], 20);
    });

    test('current next EPG view is limited for lite receiver', () {
      final accepted = view(
        type: AiroRemoteViewType.currentNextEpg,
        items: [
          item(
            itemId: 'program-current',
            kind: AiroRemoteViewItemKind.program,
            primaryText: 'Current Program',
          ),
          item(
            itemId: 'program-next',
            kind: AiroRemoteViewItemKind.program,
            primaryText: 'Next Program',
            rank: 1,
          ),
        ],
      );
      final rejected = view(
        type: AiroRemoteViewType.currentNextEpg,
        items: [
          item(itemId: 'program-current'),
          item(itemId: 'program-next', rank: 1),
          item(itemId: 'program-extra', rank: 2),
        ],
      );

      expect(accepted.validate(now), const [
        AiroRemoteViewValidationCode.accepted,
      ]);
      expect(
        rejected.validate(now),
        contains(AiroRemoteViewValidationCode.itemLimitExceeded),
      );
    });

    test('profile render tier rules reject rich lite receiver views', () {
      final remoteView = view(renderTier: AiroRemoteViewRenderTier.rich);

      expect(
        remoteView.validate(now),
        contains(AiroRemoteViewValidationCode.profileRenderTierUnsupported),
      );
    });

    test('expired views and invalid cache windows are rejected', () {
      final expired = view(
        generatedAt: now.subtract(const Duration(minutes: 10)),
        expiresAt: now.subtract(const Duration(minutes: 1)),
      );
      final invalidWindow = view(expiresAt: now);

      expect(
        expired.validate(now),
        contains(AiroRemoteViewValidationCode.expired),
      );
      expect(
        invalidWindow.validate(now),
        contains(AiroRemoteViewValidationCode.cacheWindowInvalid),
      );
    });

    test('unsafe refs, missing text, and invalid ranks are rejected', () {
      final remoteView = view(
        viewId: 'view-safe',
        items: [
          item(
            itemId: 'item-safe',
            primaryText: '',
            thumbnailRef: '/Users/example/thumb.jpg',
            rank: -1,
          ),
        ],
      );

      final result = remoteView.validate(now);

      expect(result, contains(AiroRemoteViewValidationCode.itemTextMissing));
      expect(result, contains(AiroRemoteViewValidationCode.unsafeReference));
      expect(result, contains(AiroRemoteViewValidationCode.rankInvalid));
    });

    test('ranked backup stream view exposes compact playable ranks', () {
      final remoteView = view(
        type: AiroRemoteViewType.rankedBackupStreams,
        items: [
          item(
            itemId: 'backup-1',
            kind: AiroRemoteViewItemKind.stream,
            primaryText: 'Backup stream 1',
            rank: 0,
          ),
          item(
            itemId: 'backup-2',
            kind: AiroRemoteViewItemKind.stream,
            primaryText: 'Backup stream 2',
            rank: 1,
          ),
        ],
      );
      final publicMap = remoteView.toPublicMap();
      final flattened = publicMap.toString();

      expect(remoteView.validate(now), const [
        AiroRemoteViewValidationCode.accepted,
      ]);
      expect(flattened, contains('ranked_backup_streams'));
      expect(flattened, isNot(contains('/Users/')));
      expect(flattened, isNot(contains('providerPayload')));
      expect(flattened, isNot(contains('storeConsoleAccount')));
      expect(flattened, isNot(contains('rawCredential')));
    });

    test('fake provider returns registered views deterministically', () async {
      final remoteView = view(type: AiroRemoteViewType.favorites);
      final provider = AiroFakeRemoteViewProvider(
        views: {AiroRemoteViewType.favorites: remoteView},
      );

      final loaded = await provider.load(AiroRemoteViewType.favorites);

      expect(loaded, remoteView);
      expect(
        () => provider.load(AiroRemoteViewType.compactCards),
        throwsA(isA<StateError>()),
      );
    });
  });
}
