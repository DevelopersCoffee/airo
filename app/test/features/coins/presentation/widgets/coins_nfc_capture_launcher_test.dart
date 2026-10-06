import 'package:airo_app/features/coins/presentation/widgets/coins_nfc_capture_launcher.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('renders child when no pending capture exists', (tester) async {
    final router = GoRouter(
      routes: [
        GoRoute(
          path: '/',
          builder: (_, __) => const CoinsNfcCaptureLauncher(
            captureRoute: '/quick-capture',
            child: Text('Home'),
          ),
        ),
        GoRoute(
          path: '/quick-capture',
          builder: (_, __) => const Scaffold(body: Text('Capture')),
        ),
      ],
    );

    await tester.pumpWidget(
      ProviderScope(child: MaterialApp.router(routerConfig: router)),
    );
    await tester.pumpAndSettle();

    expect(find.text('Home'), findsOneWidget);
    expect(find.text('Capture'), findsNothing);
  });
}
