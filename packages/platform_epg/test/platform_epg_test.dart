import 'package:flutter_test/flutter_test.dart';
import 'package:platform_epg/platform_epg.dart';

void main() {
  test('platform_epg shim re-exports airo_epg contracts correctly', () {
    const xmltv = '''
<tv>
  <channel id="news1">
    <display-name>News 1</display-name>
  </channel>
  <programme channel="news1" start="20260727180000 +0000" stop="20260727200000 +0000">
    <title>Evening News</title>
  </programme>
</tv>
''';

    final result = parseXmltvProgrammes(xmltv);
    expect(result.programmes.length, 1);
    expect(result.programmes.single.title, 'Evening News');
  });
}
