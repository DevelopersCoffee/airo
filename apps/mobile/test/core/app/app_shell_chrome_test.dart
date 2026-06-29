import 'package:airo_app/core/app/app_shell_chrome.dart';
import 'package:airo_app/core/auth/auth_service.dart';
import 'package:airo_app/core/providers/navigation_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const config = AppNavigationChromeConfig(
    enabledActions: [AppShellAction.notifications, AppShellAction.profileMenu],
  );

  final user = User(
    id: 'user-1',
    username: 'Uday Chauhan',
    isAdmin: false,
    createdAt: DateTime(2024),
  );

  Future<void> pumpChrome(
    WidgetTester tester, {
    required double width,
    required VoidCallback onNotificationsTap,
    required VoidCallback onProfileTap,
    required VoidCallback onLogoutTap,
  }) async {
    await tester.pumpWidget(
      MaterialApp(
        home: MediaQuery(
          data: MediaQueryData(size: Size(width, 800)),
          child: Scaffold(
            appBar: AppShellChrome(
              title: const Text('Mind'),
              user: user,
              config: config,
              onHomeTap: () {},
              onNotificationsTap: onNotificationsTap,
              onProfileTap: onProfileTap,
              onLogoutTap: onLogoutTap,
            ),
          ),
        ),
      ),
    );
  }

  testWidgets('uses overflow menu on compact widths', (tester) async {
    var notificationsTapped = 0;
    var profileTapped = 0;
    var logoutTapped = 0;

    await pumpChrome(
      tester,
      width: 420,
      onNotificationsTap: () => notificationsTapped++,
      onProfileTap: () => profileTapped++,
      onLogoutTap: () => logoutTapped++,
    );

    expect(
      find.byKey(const ValueKey('app_shell_notifications_button')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('app_shell_overflow_button')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('app_shell_profile_menu_button')),
      findsNothing,
    );

    await tester.tap(
      find.byKey(const ValueKey('app_shell_notifications_button')),
    );
    await tester.pump();
    expect(notificationsTapped, 1);

    await tester.tap(find.byKey(const ValueKey('app_shell_overflow_button')));
    await tester.pumpAndSettle();
    expect(find.text('Profile'), findsOneWidget);
    expect(find.text('Logout'), findsOneWidget);

    await tester.tap(find.text('Profile'));
    await tester.pumpAndSettle();
    expect(profileTapped, 1);

    await tester.tap(find.byKey(const ValueKey('app_shell_overflow_button')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Logout'));
    await tester.pumpAndSettle();
    expect(logoutTapped, 1);
  });

  testWidgets('keeps profile menu visible on wider widths', (tester) async {
    var profileTapped = 0;
    var logoutTapped = 0;

    await pumpChrome(
      tester,
      width: 900,
      onNotificationsTap: () {},
      onProfileTap: () => profileTapped++,
      onLogoutTap: () => logoutTapped++,
    );

    expect(
      find.byKey(const ValueKey('app_shell_notifications_button')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('app_shell_profile_menu_button')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('app_shell_overflow_button')),
      findsNothing,
    );

    await tester.tap(
      find.byKey(const ValueKey('app_shell_profile_menu_button')),
    );
    await tester.pumpAndSettle();
    expect(find.text('Uday Chauhan'), findsOneWidget);
    expect(find.text('Logout'), findsOneWidget);

    await tester.tap(find.text('Uday Chauhan'));
    await tester.pumpAndSettle();
    expect(profileTapped, 1);

    await tester.tap(
      find.byKey(const ValueKey('app_shell_profile_menu_button')),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Logout'));
    await tester.pumpAndSettle();
    expect(logoutTapped, 1);
  });
}
