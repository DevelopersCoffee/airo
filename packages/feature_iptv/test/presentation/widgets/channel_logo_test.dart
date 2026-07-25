import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:feature_iptv/presentation/widgets/channel_logo.dart';

void main() {
  testWidgets('defaults to a square box for back-compat', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: ChannelLogo(logoUrl: null, channelName: 'Airo', size: 40),
        ),
      ),
    );

    final box = tester.getSize(find.byType(ChannelLogo));
    expect(box.width, 40);
    expect(box.height, 40);
  });

  testWidgets('width widens the box for rectangular channel logos', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: ChannelLogo(
            logoUrl: null,
            channelName: 'Airo',
            size: 40,
            width: 68,
          ),
        ),
      ),
    );

    final box = tester.getSize(find.byType(ChannelLogo));
    expect(box.width, 68, reason: 'most TV channel logos are wide, not square');
    expect(box.height, 40);
  });
}
