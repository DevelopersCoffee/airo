import 'package:core_product_shell/core_product_shell.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:go_router/go_router.dart';

import 'anya_route_names.dart';
import 'screens/anya_home_screen.dart';
import 'screens/import_pdf_screen.dart';
import 'screens/import_review_screen.dart';
import 'screens/meal_detail_screen.dart';
import 'screens/onboarding_screen.dart';
import 'screens/programs_screen.dart';

export 'anya_route_names.dart';

class AnyaModule extends AppModule {
  @override
  String get id => 'anya';

  @override
  Set<ShellId> get supportedShells => {ShellId.anya};

  @override
  List<Override> providerOverridesFor(ShellId shell) => const [];

  @override
  List<RouteBase> routesFor(ShellId shell) => [
    GoRoute(
      path: '/',
      name: AnyaRouteNames.home,
      builder: (context, state) => const AnyaHomeScreen(),
      routes: [
        GoRoute(
          path: 'grocery',
          name: AnyaRouteNames.grocery,
          builder: (context, state) => const AnyaHomeScreen(initialTab: 3),
        ),
        GoRoute(
          path: 'onboarding',
          name: AnyaRouteNames.onboarding,
          builder: (context, state) => const OnboardingScreen(),
        ),
        GoRoute(
          path: 'meals/:id',
          name: AnyaRouteNames.mealDetail,
          builder: (context, state) =>
              MealDetailScreen(mealId: state.pathParameters['id']!),
        ),
        GoRoute(
          path: 'import',
          name: AnyaRouteNames.importPdf,
          builder: (context, state) => const ImportPdfScreen(),
          routes: [
            GoRoute(
              path: 'review',
              name: AnyaRouteNames.importReview,
              builder: (context, state) => const ImportReviewScreen(),
            ),
          ],
        ),
        GoRoute(
          path: 'programs',
          name: AnyaRouteNames.programs,
          builder: (context, state) => const ProgramsScreen(),
        ),
      ],
    ),
  ];
}
