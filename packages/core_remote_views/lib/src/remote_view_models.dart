import 'package:equatable/equatable.dart';

const String kAiroRemoteViewSchemaVersion = '1.0.0';

enum AiroRemoteViewProfile {
  fullTv('full_tv'),
  standardTv('standard_tv'),
  liteReceiver('lite_receiver'),
  embeddedReceiver('embedded_receiver');

  const AiroRemoteViewProfile(this.stableId);

  final String stableId;
}

enum AiroRemoteViewType {
  searchResults('search_results'),
  currentNextEpg('current_next_epg'),
  favorites('favorites'),
  compactCards('compact_cards'),
  rankedBackupStreams('ranked_backup_streams');

  const AiroRemoteViewType(this.stableId);

  final String stableId;
}

enum AiroRemoteViewItemKind {
  media('media'),
  channel('channel'),
  program('program'),
  stream('stream'),
  action('action');

  const AiroRemoteViewItemKind(this.stableId);

  final String stableId;
}

enum AiroRemoteViewRenderTier {
  rich('rich'),
  standard('standard'),
  lightweight('lightweight');

  const AiroRemoteViewRenderTier(this.stableId);

  final String stableId;
}

enum AiroRemoteViewCachePolicy {
  transient('transient'),
  cacheable('cacheable'),
  pinned('pinned');

  const AiroRemoteViewCachePolicy(this.stableId);

  final String stableId;
}

enum AiroRemoteViewValidationCode {
  accepted('accepted'),
  viewIdMissing('view_id_missing'),
  expired('expired'),
  cacheWindowInvalid('cache_window_invalid'),
  itemLimitExceeded('item_limit_exceeded'),
  profileRenderTierUnsupported('profile_render_tier_unsupported'),
  itemTextMissing('item_text_missing'),
  unsafeReference('unsafe_reference'),
  rankInvalid('rank_invalid');

  const AiroRemoteViewValidationCode(this.stableId);

  final String stableId;
}

class AiroRemoteViewItem extends Equatable {
  const AiroRemoteViewItem({
    required this.itemId,
    required this.kind,
    required this.primaryText,
    this.secondaryText,
    this.thumbnailRef,
    this.playable = false,
    this.rank = 0,
    this.contentRef,
  });

  final String itemId;
  final AiroRemoteViewItemKind kind;
  final String primaryText;
  final String? secondaryText;
  final String? thumbnailRef;
  final bool playable;
  final int rank;
  final String? contentRef;

  bool get hasUnsafeReference =>
      _isUnsafeReference(itemId) ||
      _isUnsafeReference(thumbnailRef) ||
      _isUnsafeReference(contentRef);

  bool get hasDisplayText => primaryText.trim().isNotEmpty;

  Map<String, Object?> toPublicMap() {
    return {
      'itemId': itemId,
      'kind': kind.stableId,
      'primaryText': primaryText,
      'secondaryText': secondaryText,
      'thumbnailRef': thumbnailRef,
      'playable': playable,
      'rank': rank,
      'hasContentRef': contentRef != null,
    };
  }

  @override
  List<Object?> get props => [
    itemId,
    kind,
    primaryText,
    secondaryText,
    thumbnailRef,
    playable,
    rank,
    contentRef,
  ];
}

class AiroRemoteView extends Equatable {
  AiroRemoteView({
    required this.viewId,
    required this.type,
    required this.profile,
    required this.renderTier,
    required this.cachePolicy,
    required this.generatedAt,
    required this.expiresAt,
    required List<AiroRemoteViewItem> items,
    this.schemaVersion = kAiroRemoteViewSchemaVersion,
  }) : items = List.unmodifiable(items);

  final String schemaVersion;
  final String viewId;
  final AiroRemoteViewType type;
  final AiroRemoteViewProfile profile;
  final AiroRemoteViewRenderTier renderTier;
  final AiroRemoteViewCachePolicy cachePolicy;
  final DateTime generatedAt;
  final DateTime expiresAt;
  final List<AiroRemoteViewItem> items;

  bool isExpired(DateTime now) => !expiresAt.isAfter(now);

  List<AiroRemoteViewValidationCode> validate(DateTime now) {
    final codes = <AiroRemoteViewValidationCode>[];
    final policy = AiroRemoteViewProfilePolicy.forProfile(profile);

    if (viewId.trim().isEmpty) {
      codes.add(AiroRemoteViewValidationCode.viewIdMissing);
    }
    if (isExpired(now)) {
      codes.add(AiroRemoteViewValidationCode.expired);
    }
    if (!expiresAt.isAfter(generatedAt)) {
      codes.add(AiroRemoteViewValidationCode.cacheWindowInvalid);
    }
    if (items.length > policy.maxItemsFor(type)) {
      codes.add(AiroRemoteViewValidationCode.itemLimitExceeded);
    }
    if (!policy.allowedRenderTiers.contains(renderTier)) {
      codes.add(AiroRemoteViewValidationCode.profileRenderTierUnsupported);
    }
    if (items.any((item) => !item.hasDisplayText)) {
      codes.add(AiroRemoteViewValidationCode.itemTextMissing);
    }
    if (_isUnsafeReference(viewId) ||
        items.any((item) => item.hasUnsafeReference)) {
      codes.add(AiroRemoteViewValidationCode.unsafeReference);
    }
    if (items.any((item) => item.rank < 0)) {
      codes.add(AiroRemoteViewValidationCode.rankInvalid);
    }

    return codes.isEmpty
        ? const [AiroRemoteViewValidationCode.accepted]
        : codes;
  }

  Map<String, Object?> toPublicMap() {
    return {
      'schemaVersion': schemaVersion,
      'viewId': viewId,
      'type': type.stableId,
      'profile': profile.stableId,
      'renderTier': renderTier.stableId,
      'cachePolicy': cachePolicy.stableId,
      'generatedAt': generatedAt.toUtc().toIso8601String(),
      'expiresAt': expiresAt.toUtc().toIso8601String(),
      'itemCount': items.length,
      'items': items.map((item) => item.toPublicMap()).toList(growable: false),
    };
  }

  @override
  List<Object?> get props => [
    schemaVersion,
    viewId,
    type,
    profile,
    renderTier,
    cachePolicy,
    generatedAt,
    expiresAt,
    items,
  ];
}

class AiroRemoteViewProfilePolicy extends Equatable {
  AiroRemoteViewProfilePolicy({
    required this.profile,
    required this.maxSearchItems,
    required this.maxEpgItems,
    required this.maxFavoritesItems,
    required this.maxCardItems,
    required this.maxRankedStreamItems,
    required Set<AiroRemoteViewRenderTier> allowedRenderTiers,
  }) : allowedRenderTiers = Set.unmodifiable(allowedRenderTiers);

  factory AiroRemoteViewProfilePolicy.forProfile(
    AiroRemoteViewProfile profile,
  ) {
    return switch (profile) {
      AiroRemoteViewProfile.fullTv => AiroRemoteViewProfilePolicy(
        profile: AiroRemoteViewProfile.fullTv,
        maxSearchItems: 60,
        maxEpgItems: 24,
        maxFavoritesItems: 80,
        maxCardItems: 60,
        maxRankedStreamItems: 20,
        allowedRenderTiers: {
          AiroRemoteViewRenderTier.rich,
          AiroRemoteViewRenderTier.standard,
          AiroRemoteViewRenderTier.lightweight,
        },
      ),
      AiroRemoteViewProfile.standardTv => AiroRemoteViewProfilePolicy(
        profile: AiroRemoteViewProfile.standardTv,
        maxSearchItems: 40,
        maxEpgItems: 12,
        maxFavoritesItems: 40,
        maxCardItems: 40,
        maxRankedStreamItems: 12,
        allowedRenderTiers: {
          AiroRemoteViewRenderTier.standard,
          AiroRemoteViewRenderTier.lightweight,
        },
      ),
      AiroRemoteViewProfile.liteReceiver => AiroRemoteViewProfilePolicy(
        profile: AiroRemoteViewProfile.liteReceiver,
        maxSearchItems: 20,
        maxEpgItems: 2,
        maxFavoritesItems: 20,
        maxCardItems: 20,
        maxRankedStreamItems: 5,
        allowedRenderTiers: {AiroRemoteViewRenderTier.lightweight},
      ),
      AiroRemoteViewProfile.embeddedReceiver => AiroRemoteViewProfilePolicy(
        profile: AiroRemoteViewProfile.embeddedReceiver,
        maxSearchItems: 10,
        maxEpgItems: 2,
        maxFavoritesItems: 10,
        maxCardItems: 10,
        maxRankedStreamItems: 3,
        allowedRenderTiers: {AiroRemoteViewRenderTier.lightweight},
      ),
    };
  }

  final AiroRemoteViewProfile profile;
  final int maxSearchItems;
  final int maxEpgItems;
  final int maxFavoritesItems;
  final int maxCardItems;
  final int maxRankedStreamItems;
  final Set<AiroRemoteViewRenderTier> allowedRenderTiers;

  int maxItemsFor(AiroRemoteViewType type) {
    return switch (type) {
      AiroRemoteViewType.searchResults => maxSearchItems,
      AiroRemoteViewType.currentNextEpg => maxEpgItems,
      AiroRemoteViewType.favorites => maxFavoritesItems,
      AiroRemoteViewType.compactCards => maxCardItems,
      AiroRemoteViewType.rankedBackupStreams => maxRankedStreamItems,
    };
  }

  @override
  List<Object?> get props => [
    profile,
    maxSearchItems,
    maxEpgItems,
    maxFavoritesItems,
    maxCardItems,
    maxRankedStreamItems,
    allowedRenderTiers,
  ];
}

abstract class AiroRemoteViewProvider {
  Future<AiroRemoteView> load(AiroRemoteViewType type);
}

class AiroFakeRemoteViewProvider implements AiroRemoteViewProvider {
  AiroFakeRemoteViewProvider({
    required Map<AiroRemoteViewType, AiroRemoteView> views,
  }) : views = Map.unmodifiable(views);

  final Map<AiroRemoteViewType, AiroRemoteView> views;

  @override
  Future<AiroRemoteView> load(AiroRemoteViewType type) async {
    final view = views[type];
    if (view == null) {
      throw StateError('remote_view_unavailable:${type.stableId}');
    }
    return view;
  }
}

bool _isUnsafeReference(String? value) {
  if (value == null) return false;
  final lower = value.toLowerCase();
  return lower.startsWith('/') ||
      lower.startsWith('file://') ||
      lower.contains('providerpayload') ||
      lower.contains('storeconsoleaccount') ||
      lower.contains('rawcredential') ||
      RegExp(
        r'\b(?:10|127|172\.(?:1[6-9]|2\d|3[0-1])|192\.168)\.',
      ).hasMatch(lower);
}
