import "package:feature_iptv/feature_iptv.dart";
import "package:platform_channels/platform_channels.dart";
import 'package:airo_app/features/media_hub/domain/models/media_category.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('MediaCategory', () {
    test('maps IPTV categories into shared media categories', () {
      expect(
        MediaCategoryX.fromChannelCategory(ChannelCategory.news),
        MediaCategory.news,
      );
      expect(
        MediaCategoryX.fromChannelCategory(ChannelCategory.movies),
        MediaCategory.movies,
      );
      expect(
        MediaCategoryX.fromChannelCategory(ChannelCategory.business),
        MediaCategory.business,
      );
    });

    test('exposes user-facing labels', () {
      expect(MediaCategory.music.label, 'Music');
      expect(MediaCategory.documentary.label, 'Documentary');
      expect(MediaCategory.international.label, 'International');
    });
  });
}
