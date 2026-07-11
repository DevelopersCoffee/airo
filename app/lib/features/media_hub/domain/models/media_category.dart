import "package:platform_channels/platform_channels.dart";

enum MediaCategory {
  all,
  music,
  news,
  entertainment,
  sports,
  movies,
  kids,
  documentary,
  regional,
  international,
  lifestyle,
  devotional,
  business,
  general,
}

extension MediaCategoryX on MediaCategory {
  String get label => switch (this) {
    MediaCategory.all => 'All',
    MediaCategory.music => 'Music',
    MediaCategory.news => 'News',
    MediaCategory.entertainment => 'Entertainment',
    MediaCategory.sports => 'Sports',
    MediaCategory.movies => 'Movies',
    MediaCategory.kids => 'Kids',
    MediaCategory.documentary => 'Documentary',
    MediaCategory.regional => 'Regional',
    MediaCategory.international => 'International',
    MediaCategory.lifestyle => 'Lifestyle',
    MediaCategory.devotional => 'Devotional',
    MediaCategory.business => 'Business',
    MediaCategory.general => 'General',
  };

  static MediaCategory fromChannelCategory(ChannelCategory category) {
    return switch (category) {
      ChannelCategory.all => MediaCategory.all,
      ChannelCategory.news => MediaCategory.news,
      ChannelCategory.entertainment => MediaCategory.entertainment,
      ChannelCategory.sports => MediaCategory.sports,
      ChannelCategory.music => MediaCategory.music,
      ChannelCategory.movies => MediaCategory.movies,
      ChannelCategory.kids => MediaCategory.kids,
      ChannelCategory.documentary => MediaCategory.documentary,
      ChannelCategory.regional => MediaCategory.regional,
      ChannelCategory.international => MediaCategory.international,
      ChannelCategory.lifestyle => MediaCategory.lifestyle,
      ChannelCategory.devotional => MediaCategory.devotional,
      ChannelCategory.business => MediaCategory.business,
      ChannelCategory.general => MediaCategory.general,
    };
  }
}
