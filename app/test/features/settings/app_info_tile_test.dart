import 'package:airo_app/features/settings/presentation/widgets/app_info_tile.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:package_info_plus/package_info_plus.dart';

PackageInfo _fakeInfo() => PackageInfo(
  appName: 'Airo',
  packageName: 'com.airo.app',
  version: '2.4.1',
  buildNumber: '318',
);

void main() {
  testWidgets('renders version and build number from injected PackageInfo', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: AppInfoTile(loadPackageInfo: () async => _fakeInfo()),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('2.4.1 (318)'), findsOneWidget);
  });

  testWidgets('tapping expands to show the package name', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: AppInfoTile(loadPackageInfo: () async => _fakeInfo()),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byType(ListTile));
    await tester.pumpAndSettle();

    expect(find.text('2.4.1 (318) · com.airo.app'), findsOneWidget);
  });
}
