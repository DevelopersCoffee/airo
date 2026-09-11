import 'dart:convert';

import 'package:core_product_shell/core_product_shell.dart';
import 'package:feature_anya/feature_anya.dart';
import 'package:feature_anya_core/feature_anya_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _splitGreenTeaPaste = '''
DAY 1
17:30 Evening
Green
T
ea 1 cup
Dinner
''';

void main() {
  test('Anya module ships only to ShellId.anya', () {
    final module = AnyaModule();
    expect(module.id, 'anya');
    expect(module.isEnabledForShell(ShellId.anya), isTrue);
    expect(module.isEnabledForShell(ShellId.mobile), isFalse);
    expect(module.isEnabledForShell(ShellId.tv), isFalse);
    expect(module.isEnabledForShell(ShellId.mind), isFalse);
  });

  testWidgets('home asks for onboarding when no profile exists', (
    tester,
  ) async {
    await tester.pumpWidget(_anyaHarness());
    await tester.pump();
    await tester.pump();

    expect(find.text('Anya'), findsWidgets);
    expect(find.text('Your Personal Nutrition Planner'), findsOneWidget);
    expect(find.text('Nothing for today'), findsOneWidget);
    expect(find.text('AI'), findsNothing);
    expect(
      find.text('Anya is a general nutrition planner, not medical advice.'),
      findsOneWidget,
    );
    await tester.tap(find.text('Meals'));
    await tester.pump();
    expect(find.text('No meals yet'), findsOneWidget);
    await tester.tap(find.text('Diet'));
    await tester.pump();
    expect(find.text('Set up Anya Diet'), findsOneWidget);
  });

  testWidgets('meals tab lists generated catalog meals', (tester) async {
    final profile = DietProfile(
      dietType: DietType.vegan,
      householdSize: 2,
      weeklyBudget: 80,
      cookingDays: const [Weekday.monday],
      moods: const {FoodMood.speedy},
    );
    final plan = generateWeeklyPlan(
      profile: profile,
      catalog: seedMealCatalog(),
      weekStartIso: '2026-09-14',
    );
    await tester.pumpWidget(
      _anyaHarness(
        repository: MemoryAnyaRepository(
          AnyaSnapshot(profile: profile, weeklyPlan: plan),
        ),
      ),
    );
    await tester.pump();
    await tester.pump();

    await tester.tap(find.text('Meals'));
    await tester.pump();
    expect(find.text(plan.meals.first.meal.name), findsWidgets);
    await tester.tap(find.text('Grocery'));
    await tester.pump();
    expect(find.byType(CheckboxListTile), findsWidgets);
    await tester.tap(find.byType(CheckboxListTile).first);
    await tester.pump();
    expect(
      tester
          .widget<CheckboxListTile>(find.byType(CheckboxListTile).first)
          .value,
      isTrue,
    );
  });

  testWidgets('imported program appears on Diet, Meals, and Grocery', (
    tester,
  ) async {
    final profile = DietProfile(
      dietType: DietType.vegan,
      householdSize: 2,
      weeklyBudget: 80,
      cookingDays: const [Weekday.monday],
      moods: const {FoodMood.speedy},
    );
    final plan = generateWeeklyPlan(
      profile: profile,
      catalog: seedMealCatalog(),
      weekStartIso: '2026-09-14',
    );
    const program = DietProgram(
      id: 'imported',
      title: 'Clinic plan.pdf',
      source: ProgramSource.imported,
      phases: [
        DietPhase(
          id: 'p1',
          name: 'Phase',
          days: [
            DietDay(
              dayNumber: 7,
              meals: [
                MealSlot(
                  type: MealType.breakfast,
                  time: '10:00',
                  items: [FoodItem(name: 'veg poha', quantityRaw: '1k')],
                ),
              ],
            ),
          ],
        ),
      ],
      rules: DietRule(allowedFoods: ['millet'], avoidFoods: ['fried foods']),
      guidelines: ['Sip warm water through the day'],
    );
    await tester.pumpWidget(
      _anyaHarness(
        repository: MemoryAnyaRepository(
          AnyaSnapshot(
            profile: profile,
            weeklyPlan: plan,
            programs: const [program],
            activeProgramId: 'imported',
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pump();

    expect(find.text('Nothing mapped to today'), findsOneWidget);
    expect(find.text('AI'), findsNothing);

    await tester.tap(find.text('Diet'));
    await tester.pump();
    expect(find.text('Clinic plan.pdf'), findsOneWidget);
    expect(find.textContaining('Active imported program'), findsOneWidget);
    expect(find.text('Foods to include'), findsOneWidget);
    expect(find.text('Foods to avoid'), findsOneWidget);
    expect(find.textContaining('fried foods'), findsOneWidget);
    expect(
      find.textContaining('Sip warm water through the day'),
      findsOneWidget,
    );

    await tester.tap(find.text('Meals'));
    await tester.pump();
    expect(find.text('veg poha'), findsOneWidget);
    expect(find.textContaining('Day 7'), findsOneWidget);

    await tester.tap(find.text('Grocery'));
    await tester.pump();
    expect(find.text('From imported plan'), findsOneWidget);
    expect(find.text('veg poha'), findsOneWidget);
  });

  testWidgets('onboarding shows labels and optional body stats', (
    tester,
  ) async {
    await tester.pumpWidget(_anyaHarness());
    await tester.pump();
    await tester.pump();
    await tester.tap(find.text('Diet'));
    await tester.pump();
    await tester.tap(find.text('Start onboarding'));
    await tester.pumpAndSettle();
    expect(find.text('Vegetarian'), findsOneWidget);
    expect(find.text('Speedy meals'), findsOneWidget);
    expect(find.text('Age'), findsOneWidget);
    expect(find.text('Height (cm)'), findsOneWidget);
    expect(find.text('Weight (kg)'), findsOneWidget);
  });

  testWidgets('Today shows the imported day that maps onto the clock', (
    tester,
  ) async {
    const program = DietProgram(
      id: 'imported',
      title: 'Clinic plan.pdf',
      source: ProgramSource.imported,
      phases: [
        DietPhase(
          id: 'p1',
          name: 'Phase',
          days: [
            DietDay(
              dayNumber: 7,
              meals: [
                MealSlot(
                  type: MealType.breakfast,
                  time: '10:00',
                  items: [FoodItem(name: 'veg poha', quantityRaw: '1k')],
                ),
              ],
            ),
          ],
        ),
      ],
    );
    await tester.pumpWidget(
      _anyaHarness(
        now: DateTime(2026, 9, 13, 11, 0),
        repository: MemoryAnyaRepository(
          const AnyaSnapshot(programs: [program], activeProgramId: 'imported'),
        ),
      ),
    );
    await tester.pump();
    await tester.pump();
    expect(find.text('veg poha'), findsOneWidget);
    expect(find.textContaining('up next'), findsOneWidget);
    expect(find.textContaining('From Clinic plan.pdf'), findsOneWidget);
  });

  test('empty PDF bytes mark the extract as having no text layer', () async {
    final container = ProviderContainer(
      overrides: [
        anyaRepositoryProvider.overrideWithValue(MemoryAnyaRepository()),
        anyaPdfExtractorProvider.overrideWithValue(const _EmptyExtractor()),
      ],
    );
    addTearDown(container.dispose);
    await container.read(anyaSessionProvider.notifier).hydrate();
    await container
        .read(anyaSessionProvider.notifier)
        .importPdf(fileName: 'scan.pdf', bytes: const []);
    expect(container.read(anyaSessionProvider).emptyExtract, isTrue);
    expect(container.read(anyaSessionProvider).pendingProgram, isNull);
  });

  test('importPastedText normalizes a clinic day without a PDF', () async {
    final container = ProviderContainer(
      overrides: [
        anyaRepositoryProvider.overrideWithValue(MemoryAnyaRepository()),
      ],
    );
    addTearDown(container.dispose);
    await container.read(anyaSessionProvider.notifier).hydrate();
    await container
        .read(anyaSessionProvider.notifier)
        .importPastedText(
          title: 'Pasted plan',
          text: 'DAY 7\n10:00 AM\nveg poha 1k\n',
        );
    final session = container.read(anyaSessionProvider);
    final program = session.pendingProgram;
    expect(program, isNotNull);
    expect(program!.allDays.single.dayNumber, 7);
    expect(program.allDays.single.meals.single.items.single.quantityRaw, '1k');
    expect(session.repairStatus, RepairStatus.idle);
  });

  test('noop repair joins Green tea and stays idle', () async {
    final container = ProviderContainer(
      overrides: [
        anyaRepositoryProvider.overrideWithValue(MemoryAnyaRepository()),
      ],
    );
    addTearDown(container.dispose);
    await container.read(anyaSessionProvider.notifier).hydrate();
    await container
        .read(anyaSessionProvider.notifier)
        .importPastedText(title: 'Clinic', text: _splitGreenTeaPaste);
    final session = container.read(anyaSessionProvider);
    expect(session.repairStatus, RepairStatus.idle);
    final items = session.pendingProgram!.allDays.single.meals.single.items;
    expect(items, [const FoodItem(name: 'Green tea', quantityRaw: '1 cup')]);
  });

  test('invalid JSON port fails and keeps the heuristic program', () async {
    final container = ProviderContainer(
      overrides: [
        anyaRepositoryProvider.overrideWithValue(MemoryAnyaRepository()),
        planRepairPortProvider.overrideWithValue(
          const _ScriptedPlanRepairPort(['not-json']),
        ),
      ],
    );
    addTearDown(container.dispose);
    await container.read(anyaSessionProvider.notifier).hydrate();
    await container
        .read(anyaSessionProvider.notifier)
        .importPastedText(title: 'Clinic', text: _splitGreenTeaPaste);
    final session = container.read(anyaSessionProvider);
    expect(session.repairStatus, RepairStatus.failed);
    expect(session.pendingProgram!.id, startsWith('import_'));
    expect(session.pendingProgram!.allDays.single.meals.single.items, [
      const FoodItem(name: 'Green tea', quantityRaw: '1 cup'),
    ]);
  });

  test(
    'valid JSON port completes and keeps id, source, and quantityRaw',
    () async {
      final container = ProviderContainer(
        overrides: [
          anyaRepositoryProvider.overrideWithValue(MemoryAnyaRepository()),
          planRepairPortProvider.overrideWithValue(
            const _ClearingPlanRepairPort(),
          ),
        ],
      );
      addTearDown(container.dispose);
      await container.read(anyaSessionProvider.notifier).hydrate();
      await container
          .read(anyaSessionProvider.notifier)
          .importPastedText(title: 'Clinic', text: _splitGreenTeaPaste);
      final session = container.read(anyaSessionProvider);
      expect(session.repairStatus, RepairStatus.complete);
      final program = session.pendingProgram!;
      expect(program.id, startsWith('import_'));
      expect(program.source, ProgramSource.imported);
      expect(
        program.allDays.single.meals.single.items.single,
        const FoodItem(name: 'Green tea', quantityRaw: '1 cup'),
      );
    },
  );

  test('toggles grocery checks on the snapshot', () async {
    final container = ProviderContainer(
      overrides: [
        anyaRepositoryProvider.overrideWithValue(MemoryAnyaRepository()),
      ],
    );
    addTearDown(container.dispose);
    await container.read(anyaSessionProvider.notifier).hydrate();
    await container.read(anyaSessionProvider.notifier).toggleGroceryLine('k1');
    expect(container.read(anyaSessionProvider).snapshot.checkedGroceryKeys, {
      'k1',
    });
    await container.read(anyaSessionProvider.notifier).toggleGroceryLine('k1');
    expect(
      container.read(anyaSessionProvider).snapshot.checkedGroceryKeys,
      isEmpty,
    );
  });

  test('deleteProgram removes the active import', () async {
    const program = DietProgram(
      id: 'imported',
      title: 'Clinic plan.pdf',
      source: ProgramSource.imported,
      phases: [],
    );
    final container = ProviderContainer(
      overrides: [
        anyaRepositoryProvider.overrideWithValue(
          MemoryAnyaRepository(
            const AnyaSnapshot(
              programs: [program],
              activeProgramId: 'imported',
            ),
          ),
        ),
      ],
    );
    addTearDown(container.dispose);
    await container.read(anyaSessionProvider.notifier).hydrate();
    await container
        .read(anyaSessionProvider.notifier)
        .deleteProgram('imported');
    expect(container.read(anyaSessionProvider).programs, isEmpty);
    expect(container.read(anyaSessionProvider).activeProgram, isNull);
  });

  test('swapPlannedMeal replaces one catalog slot', () async {
    final profile = DietProfile(
      dietType: DietType.vegan,
      householdSize: 2,
      weeklyBudget: 80,
      cookingDays: const [Weekday.monday],
      moods: const {FoodMood.speedy},
    );
    final plan = generateWeeklyPlan(
      profile: profile,
      catalog: seedMealCatalog(),
      weekStartIso: '2026-09-14',
    );
    final original = plan.meals.first;
    final replacement = eligibleCatalogMeals(
      profile: profile,
      catalog: seedMealCatalog(),
    ).firstWhere((meal) => meal.id != original.meal.id);
    final container = ProviderContainer(
      overrides: [
        anyaRepositoryProvider.overrideWithValue(
          MemoryAnyaRepository(
            AnyaSnapshot(profile: profile, weeklyPlan: plan),
          ),
        ),
      ],
    );
    addTearDown(container.dispose);
    await container.read(anyaSessionProvider.notifier).hydrate();
    await container
        .read(anyaSessionProvider.notifier)
        .swapPlannedMeal(plannedMealId: original.id, replacement: replacement);
    expect(
      container.read(anyaSessionProvider).weeklyPlan!.meals.first.meal.id,
      replacement.id,
    );
  });

  test(
    'confirming an import regenerates the week without avoided foods',
    () async {
      final profile = DietProfile(
        dietType: DietType.vegetarian,
        householdSize: 2,
        weeklyBudget: 200,
        cookingDays: const [
          Weekday.monday,
          Weekday.tuesday,
          Weekday.wednesday,
          Weekday.thursday,
        ],
        moods: const {FoodMood.proteinPacked},
      );
      final plan = generateWeeklyPlan(
        profile: profile,
        catalog: seedMealCatalog(),
        weekStartIso: '2026-09-14',
      );
      const pending = DietProgram(
        id: 'imported',
        title: 'Clinic plan.pdf',
        source: ProgramSource.imported,
        phases: [],
        rules: DietRule(avoidFoods: ['paneer']),
      );
      final container = ProviderContainer(
        overrides: [
          anyaRepositoryProvider.overrideWithValue(
            MemoryAnyaRepository(
              AnyaSnapshot(profile: profile, weeklyPlan: plan),
            ),
          ),
        ],
      );
      addTearDown(container.dispose);
      await container.read(anyaSessionProvider.notifier).hydrate();
      container
          .read(anyaSessionProvider.notifier)
          .updatePendingProgram(pending);
      await container
          .read(anyaSessionProvider.notifier)
          .confirmPendingProgram();
      final meals = container.read(anyaSessionProvider).weeklyPlan!.meals;
      expect(
        meals.any(
          (meal) => meal.meal.ingredients.any(
            (ingredient) => ingredient.name.toLowerCase().contains('paneer'),
          ),
        ),
        isFalse,
      );
    },
  );

  testWidgets('import review can edit, replace, and remove a food', (
    tester,
  ) async {
    const program = DietProgram(
      id: 'pending',
      title: 'Clinic plan.pdf',
      source: ProgramSource.imported,
      phases: [
        DietPhase(
          id: 'p1',
          name: 'Phase',
          days: [
            DietDay(
              dayNumber: 7,
              meals: [
                MealSlot(
                  type: MealType.breakfast,
                  time: '10:00',
                  items: [FoodItem(name: 'veg poha', quantityRaw: '1k')],
                ),
              ],
            ),
          ],
        ),
      ],
      rules: DietRule(allowedFoods: ['millet'], avoidFoods: ['fried foods']),
      guidelines: ['Sip warm water through the day'],
    );
    await tester.pumpWidget(_anyaHarness(location: '/import/review'));
    await tester.pump();
    final context = tester.element(find.byType(MaterialApp));
    ProviderScope.containerOf(
      context,
    ).read(anyaSessionProvider.notifier).updatePendingProgram(program);
    await tester.pump();

    expect(find.text('Foods to include'), findsOneWidget);
    expect(find.textContaining('millet'), findsWidgets);
    expect(find.text('Foods to avoid'), findsOneWidget);

    expect(find.text('veg poha'), findsOneWidget);
    expect(find.text('1k'), findsOneWidget);

    await tester.tap(find.byTooltip('Edit food'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Edit'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).first, 'vegetable poha');
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();
    expect(find.text('vegetable poha'), findsOneWidget);
    expect(find.text('1k'), findsOneWidget);

    await tester.tap(find.byTooltip('Edit food'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Replace'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Veg Poha'));
    await tester.pumpAndSettle();
    expect(find.text('Veg Poha'), findsOneWidget);

    await tester.tap(find.byTooltip('Edit food'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Remove'));
    await tester.pumpAndSettle();
    expect(find.text('Veg Poha'), findsNothing);
  });

  testWidgets('import screen offers paste for scanned PDFs', (tester) async {
    await tester.pumpWidget(_anyaHarness(location: '/import'));
    await tester.pump();
    expect(find.text('Or paste plan text'), findsOneWidget);
    expect(find.text('Import pasted text'), findsOneWidget);
  });

  testWidgets('review shows Green tea after heuristic repair', (tester) async {
    await tester.pumpWidget(_anyaHarness(location: '/import/review'));
    await tester.pump();
    final container = ProviderScope.containerOf(
      tester.element(find.byType(MaterialApp)),
    );
    await container
        .read(anyaSessionProvider.notifier)
        .importPastedText(title: 'Clinic', text: _splitGreenTeaPaste);
    await tester.pump();
    expect(find.text('Green tea'), findsOneWidget);
    expect(find.text('1 cup'), findsOneWidget);
    expect(find.text('Dinner'), findsNothing);
    expect(find.text('Cleaning with on-device model…'), findsNothing);
  });

  testWidgets('review shows cleaning then hides it when a port completes', (
    tester,
  ) async {
    await tester.pumpWidget(
      _anyaHarness(
        location: '/import/review',
        repairPort: const _DelayedPlanRepairPort(),
      ),
    );
    await tester.pump();
    final container = ProviderScope.containerOf(
      tester.element(find.byType(MaterialApp)),
    );
    final pending = container
        .read(anyaSessionProvider.notifier)
        .importPastedText(title: 'Clinic', text: _splitGreenTeaPaste);
    await tester.pump();
    expect(find.text('Cleaning with on-device model…'), findsOneWidget);
    await tester.pump(const Duration(milliseconds: 60));
    await pending;
    await tester.pump();
    expect(find.text('Cleaning with on-device model…'), findsNothing);
    expect(find.text('Green tea'), findsOneWidget);
  });

  testWidgets('review shows fallback copy when the port fails', (tester) async {
    await tester.pumpWidget(
      _anyaHarness(
        location: '/import/review',
        repairPort: const _ScriptedPlanRepairPort(['not-json']),
      ),
    );
    await tester.pump();
    final container = ProviderScope.containerOf(
      tester.element(find.byType(MaterialApp)),
    );
    await container
        .read(anyaSessionProvider.notifier)
        .importPastedText(title: 'Clinic', text: _splitGreenTeaPaste);
    await tester.pump();
    expect(find.text('Could not refine. Showing parsed plan.'), findsOneWidget);
    expect(find.text('Green tea'), findsOneWidget);
  });

  test(
    'SecureAnyaRepository migrates plaintext prefs then deletes them',
    () async {
      SharedPreferences.setMockInitialValues({
        anyaSnapshotPrefsKey: encodeAnyaSnapshot(
          const AnyaSnapshot(
            programs: [
              DietProgram(
                id: 'imported',
                title: 'Clinic',
                source: ProgramSource.imported,
                phases: [],
              ),
            ],
            activeProgramId: 'imported',
          ),
        ),
      });
      final prefs = await SharedPreferences.getInstance();
      final secrets = MemoryAnyaSecretStore();
      final repo = SecureAnyaRepository(
        secrets: secrets,
        plaintextFallback: prefs,
      );
      final loaded = await repo.load();
      expect(loaded.activeProgramId, 'imported');
      expect(prefs.getString(anyaSnapshotPrefsKey), isNull);
      expect(await secrets.read(anyaSnapshotSecretKey), isNotNull);
    },
  );
}

class _EmptyExtractor implements AnyaPdfTextExtractor {
  const _EmptyExtractor();

  @override
  Future<List<ExtractedPdfPage>> extractPages(List<int> pdfBytes) async {
    return const [ExtractedPdfPage(pageNumber: 1, text: '')];
  }
}

class _ScriptedPlanRepairPort implements PlanRepairPort {
  const _ScriptedPlanRepairPort(this.tokens);

  final List<String> tokens;

  @override
  bool get isAvailable => true;

  @override
  Stream<String> repair(DietProgram draft) => Stream.fromIterable(tokens);
}

class _ClearingPlanRepairPort implements PlanRepairPort {
  const _ClearingPlanRepairPort();

  @override
  bool get isAvailable => true;

  @override
  Stream<String> repair(DietProgram draft) {
    final cleared = draft.copyWith(
      id: 'llm',
      source: ProgramSource.generated,
      phases: [
        for (final phase in draft.phases)
          phase.copyWith(
            days: [
              for (final day in phase.days)
                day.copyWith(
                  meals: [
                    for (final slot in day.meals)
                      slot.copyWith(
                        items: [
                          for (final item in slot.items)
                            item.copyWith(quantityRaw: ''),
                        ],
                      ),
                  ],
                ),
            ],
          ),
      ],
    );
    return Stream.value('```json\n${jsonEncode(cleared.toJson())}\n```');
  }
}

class _DelayedPlanRepairPort implements PlanRepairPort {
  const _DelayedPlanRepairPort();

  @override
  bool get isAvailable => true;

  @override
  Stream<String> repair(DietProgram draft) async* {
    await Future<void>.delayed(const Duration(milliseconds: 50));
    yield jsonEncode(draft.toJson());
  }
}

Widget _anyaHarness({
  AnyaRepository? repository,
  String location = '/',
  DateTime? now,
  PlanRepairPort? repairPort,
}) {
  final module = AnyaModule();
  final router = GoRouter(
    initialLocation: location,
    routes: module.routesFor(ShellId.anya),
  );
  return ProviderScope(
    overrides: [
      anyaRepositoryProvider.overrideWithValue(
        repository ?? MemoryAnyaRepository(),
      ),
      anyaNowProvider.overrideWithValue(now ?? DateTime(2026, 9, 11, 11, 0)),
      planRepairPortProvider.overrideWithValue(
        repairPort ?? const NoopPlanRepairPort(),
      ),
    ],
    child: MaterialApp.router(routerConfig: router),
  );
}
