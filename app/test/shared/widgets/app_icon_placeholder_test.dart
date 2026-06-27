import 'package:airo_app/shared/widgets/app_icon_placeholder.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('renders the shared icon fallback when asset loading fails', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: AppIconPlaceholder(
            size: 32,
            errorBuilder: _failingErrorBuilder,
          ),
        ),
      ),
    );

    expect(find.byType(Image), findsOneWidget);

    final image = tester.widget<Image>(find.byType(Image));
    final errorWidget = image.errorBuilder?.call(
      tester.element(find.byType(Image)),
      FlutterError('boom'),
      StackTrace.empty,
    );

    expect(errorWidget, isA<Icon>());
  });
}

Widget _failingErrorBuilder(
  BuildContext context,
  Object error,
  StackTrace? stackTrace,
) {
  return const Icon(Icons.broken_image);
}
