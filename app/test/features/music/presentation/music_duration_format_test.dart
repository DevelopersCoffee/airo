import 'package:airo_app/features/music/presentation/music_duration_format.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('formatMusicTrackDuration renders m:ss', () {
    expect(formatMusicTrackDuration(Duration.zero), '0:00');
    expect(
      formatMusicTrackDuration(const Duration(minutes: 3, seconds: 7)),
      '3:07',
    );
    expect(
      formatMusicTrackDuration(const Duration(minutes: 12, seconds: 45)),
      '12:45',
    );
  });
}
