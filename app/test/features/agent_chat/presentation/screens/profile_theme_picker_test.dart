import 'package:airo_app/core/providers/app_theme_provider.dart';
import 'package:airo_app/features/agent_chat/presentation/screens/profile_screen.dart';
import 'package:core_ui/core_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  testWidgets('profile appearance picker saves selected theme', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final notifier = AppThemeNotifier.withPreferences(prefs);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [appThemeProvider.overrideWith((ref) => notifier)],
        child: const MaterialApp(home: ProfileScreen()),
      ),
    );

    expect(find.text('Appearance'), findsOneWidget);
    expect(find.text('Airo Cyber'), findsOneWidget);
    expect(find.text('Airo Classic'), findsOneWidget);

    await tester.tap(find.text('Airo Classic'));
    await tester.pump();

    expect(notifier.state, AppThemeId.classic);
    expect(prefs.getString(AppThemeNotifier.storageKey), 'classic');
  });
}
