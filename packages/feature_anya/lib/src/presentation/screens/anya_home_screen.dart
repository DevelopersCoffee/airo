import 'package:core_ui/core_ui.dart';
import 'package:feature_anya_core/feature_anya_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../anya_route_names.dart';
import '../providers/anya_providers.dart';
import '../widgets/wellness_banner.dart';

class AnyaHomeScreen extends ConsumerStatefulWidget {
  const AnyaHomeScreen({super.key, this.initialTab = 0});

  final int initialTab;

  @override
  ConsumerState<AnyaHomeScreen> createState() => _AnyaHomeScreenState();
}

class _AnyaHomeScreenState extends ConsumerState<AnyaHomeScreen> {
  late int _tab = widget.initialTab;

  @override
  void initState() {
    super.initState();
    Future<void>.microtask(
      () => ref.read(anyaSessionProvider.notifier).hydrate(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final session = ref.watch(anyaSessionProvider);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Anya'),
        actions: [
          IconButton(
            tooltip: 'Programs',
            onPressed: () => context.pushNamed(AnyaRouteNames.programs),
            icon: const Icon(Icons.folder_outlined),
          ),
          IconButton(
            tooltip: 'Import plan',
            onPressed: () => context.pushNamed(AnyaRouteNames.importPdf),
            icon: const Icon(Icons.upload_file_outlined),
          ),
        ],
      ),
      body: Column(
        children: [
          const WellnessBanner(),
          Padding(
            padding: AiroSpacing.paddingHorizontalMd,
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'Your Personal Nutrition Planner',
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ),
          ),
          Expanded(
            child: IndexedStack(
              index: _tab,
              children: [
                _TodayTab(session: session),
                _DietTab(session: session),
                _MealsTab(session: session),
                _GroceryTab(session: session),
              ],
            ),
          ),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _tab,
        onDestinationSelected: (index) => setState(() => _tab = index),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.today_outlined),
            selectedIcon: Icon(Icons.today),
            label: 'Today',
          ),
          NavigationDestination(
            icon: Icon(Icons.person_outline),
            selectedIcon: Icon(Icons.person),
            label: 'Diet',
          ),
          NavigationDestination(
            icon: Icon(Icons.restaurant_outlined),
            selectedIcon: Icon(Icons.restaurant),
            label: 'Meals',
          ),
          NavigationDestination(
            icon: Icon(Icons.shopping_basket_outlined),
            selectedIcon: Icon(Icons.shopping_basket),
            label: 'Grocery',
          ),
        ],
      ),
    );
  }
}

class _DietTab extends ConsumerWidget {
  const _DietTab({required this.session});

  final AnyaSessionState session;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = session.profile;
    final program = session.activeProgram;
    if (profile == null && program == null) {
      return EmptyStateWidget(
        icon: Icons.restaurant_menu,
        title: 'Set up Anya Diet',
        message:
            'Import a clinic PDF, or tell Anya who you cook for to generate a household catalog week.',
        action: AppButton(
          label: 'Start onboarding',
          onPressed: () => context.pushNamed(AnyaRouteNames.onboarding),
        ),
      );
    }
    final plan = session.weeklyPlan;
    return SingleChildScrollView(
      padding: AiroSpacing.paddingMd,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (profile != null)
            AppCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Household',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: AiroSpacing.sm),
                  Text(
                    '${profile.householdSize} people · ${profile.dietType.label}',
                  ),
                  Text(
                    'Weekly budget ${profile.weeklyBudget.toStringAsFixed(0)}',
                  ),
                  if (plan != null)
                    Text(
                      plan.overBudget
                          ? 'This week ${plan.estimatedCost.toStringAsFixed(0)} — over budget'
                          : 'This week ${plan.estimatedCost.toStringAsFixed(0)} estimated',
                    ),
                  Text(
                    'Cooking: ${profile.cookingDays.map((d) => d.shortLabel).join(', ')}',
                  ),
                  if (profile.moods.isNotEmpty)
                    Text(
                      'Moods: ${profile.moods.map((mood) => mood.label).join(', ')}',
                    ),
                  if (profile.allergies.trim().isNotEmpty)
                    Text('Allergies: ${profile.allergies}'),
                  if (profile.dislikes.trim().isNotEmpty)
                    Text('Dislikes: ${profile.dislikes}'),
                  if (profile.age != null ||
                      profile.heightCm != null ||
                      profile.weightKg != null)
                    Text(
                      [
                        if (profile.age != null) 'Age ${profile.age}',
                        if (profile.heightCm != null) '${profile.heightCm} cm',
                        if (profile.weightKg != null)
                          '${profile.weightKg!.toStringAsFixed(0)} kg',
                      ].join(' · '),
                    ),
                ],
              ),
            )
          else
            AppCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'No household profile yet',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: AiroSpacing.sm),
                  const Text(
                    'Imported programs work without onboarding. A household catalog week is only a fallback if you do not have a clinic PDF.',
                  ),
                  const SizedBox(height: AiroSpacing.md),
                  AppButton(
                    label: 'Start onboarding',
                    onPressed: () =>
                        context.pushNamed(AnyaRouteNames.onboarding),
                  ),
                ],
              ),
            ),
          if (program != null) ...[
            const SizedBox(height: AiroSpacing.md),
            AppCard(
              onTap: () => context.pushNamed(AnyaRouteNames.programs),
              child: ListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(program.title),
                subtitle: Text(
                  'Active imported program · ${program.allDays.length} days',
                ),
                trailing: const Icon(Icons.chevron_right),
              ),
            ),
            if (program.rules.allowedFoods.isNotEmpty) ...[
              const SizedBox(height: AiroSpacing.md),
              _StringListCard(
                title: 'Foods to include',
                items: program.rules.allowedFoods,
              ),
            ],
            if (program.rules.avoidFoods.isNotEmpty) ...[
              const SizedBox(height: AiroSpacing.md),
              _StringListCard(
                title: 'Foods to avoid',
                items: program.rules.avoidFoods,
              ),
            ],
            if (program.guidelines.isNotEmpty) ...[
              const SizedBox(height: AiroSpacing.md),
              _StringListCard(title: 'Guidelines', items: program.guidelines),
            ],
          ],
          if (profile != null) ...[
            const SizedBox(height: AiroSpacing.md),
            AppButton(
              label: 'Edit profile',
              variant: AppButtonVariant.secondary,
              onPressed: () => context.pushNamed(AnyaRouteNames.onboarding),
            ),
            const SizedBox(height: AiroSpacing.sm),
            AppButton(
              label: 'Regenerate week',
              onPressed: () =>
                  ref.read(anyaSessionProvider.notifier).regeneratePlan(),
            ),
          ],
        ],
      ),
    );
  }
}

class _StringListCard extends StatelessWidget {
  const _StringListCard({required this.title, required this.items});

  final String title;
  final List<String> items;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: AiroSpacing.sm),
          for (final item in items) Text('· $item'),
        ],
      ),
    );
  }
}

class _MealsTab extends StatelessWidget {
  const _MealsTab({required this.session});

  final AnyaSessionState session;

  @override
  Widget build(BuildContext context) {
    final plan = session.weeklyPlan;
    final program = session.activeProgram;
    final hasCatalog = plan != null && plan.meals.isNotEmpty;
    final hasImported = program != null && program.allDays.isNotEmpty;
    if (!hasCatalog && !hasImported) {
      return EmptyStateWidget(
        icon: Icons.calendar_month_outlined,
        title: 'No meals yet',
        message:
            'Import a clinic PDF, or finish onboarding for a household catalog week (fallback if you do not have a PDF).',
        action: AppButton(
          label: 'Start onboarding',
          onPressed: () => context.pushNamed(AnyaRouteNames.onboarding),
        ),
      );
    }
    return ListView(
      padding: AiroSpacing.paddingMd,
      children: [
        if (hasImported) ...[
          Text(program.title, style: Theme.of(context).textTheme.titleMedium),
          Text('${program.allDays.length} imported days'),
          const SizedBox(height: AiroSpacing.md),
          for (final day in program.allDays)
            for (final slot in day.meals)
              Padding(
                padding: const EdgeInsets.only(bottom: AiroSpacing.sm),
                child: AppCard(
                  child: ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(slot.items.map((item) => item.name).join(', ')),
                    subtitle: Text(
                      'Day ${day.dayNumber} · ${slot.type.label}'
                      '${slot.time == null ? '' : ' · ${slot.time}'}',
                    ),
                  ),
                ),
              ),
        ],
        if (hasCatalog) ...[
          if (hasImported) const SizedBox(height: AiroSpacing.md),
          Text(
            'Household catalog week',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          Text(
            'Week of ${plan.weekStartIso}. Fallback if you do not have a clinic PDF.',
          ),
          Text(
            plan.overBudget
                ? '${plan.totals.calories} kcal · ${plan.estimatedCost.toStringAsFixed(0)} estimated — over budget'
                : '${plan.totals.calories} kcal · ${plan.estimatedCost.toStringAsFixed(0)} estimated',
          ),
          const SizedBox(height: AiroSpacing.md),
          for (final meal in plan.meals)
            Padding(
              padding: const EdgeInsets.only(bottom: AiroSpacing.sm),
              child: AppCard(
                onTap: () => context.pushNamed(
                  AnyaRouteNames.mealDetail,
                  pathParameters: {'id': meal.id},
                ),
                child: ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(meal.meal.name),
                  subtitle: Text(
                    '${meal.weekday.shortLabel} · ${meal.mealType.label} · '
                    '${meal.nutrition.calories} kcal · ${meal.meal.cookTimeMinutes} min',
                  ),
                  trailing: const Icon(Icons.chevron_right),
                ),
              ),
            ),
        ],
      ],
    );
  }
}

class _GroceryTab extends ConsumerWidget {
  const _GroceryTab({required this.session});

  final AnyaSessionState session;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final grocery = session.groceryList;
    if (grocery.lines.isEmpty) {
      return const EmptyStateWidget(
        icon: Icons.shopping_basket_outlined,
        title: 'No grocery list',
        message: 'Generate a week of meals or confirm an imported plan.',
      );
    }
    final grouped = grocery.grouped;
    final checked = session.snapshot.checkedGroceryKeys;
    final imported = [
      for (final line in grocery.lines)
        if (line.fromUnmappedPdf) line,
    ];
    return ListView(
      padding: AiroSpacing.paddingMd,
      children: [
        if (session.weeklyPlan?.overBudget ?? false) ...[
          Text(
            'Catalog groceries are over this week’s budget.',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          const SizedBox(height: AiroSpacing.md),
        ],
        if (imported.isNotEmpty) ...[
          Text(
            'From imported plan',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: AiroSpacing.sm),
          for (final line in imported)
            CheckboxListTile(
              value: checked.contains(line.key),
              onChanged: (_) => ref
                  .read(anyaSessionProvider.notifier)
                  .toggleGroceryLine(line.key),
              title: Text(line.name),
              subtitle: Text(line.quantityLabel),
              controlAffinity: ListTileControlAffinity.leading,
            ),
          const SizedBox(height: AiroSpacing.md),
        ],
        for (final aisle in GroceryAisle.values)
          if (grouped[aisle]
                  ?.where((line) => !line.fromUnmappedPdf)
                  .isNotEmpty ??
              false) ...[
            Text(aisle.label, style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: AiroSpacing.sm),
            for (final line in grouped[aisle]!)
              if (!line.fromUnmappedPdf)
                CheckboxListTile(
                  value: checked.contains(line.key),
                  onChanged: (_) => ref
                      .read(anyaSessionProvider.notifier)
                      .toggleGroceryLine(line.key),
                  title: Text(line.name),
                  subtitle: Text(line.quantityLabel),
                  controlAffinity: ListTileControlAffinity.leading,
                ),
            const SizedBox(height: AiroSpacing.md),
          ],
      ],
    );
  }
}

class _TodayTab extends ConsumerWidget {
  const _TodayTab({required this.session});

  final AnyaSessionState session;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final now = ref.watch(anyaNowProvider);
    final program = session.activeProgram;
    final importedDay = program == null ? null : todayProgramDay(program, now);
    final catalogMeals = session.weeklyPlan == null
        ? const <PlannedMeal>[]
        : todaysCatalogMeals(session.weeklyPlan!, now);
    final hasImported = importedDay != null && importedDay.meals.isNotEmpty;
    final hasCatalog = catalogMeals.isNotEmpty;
    if (!hasImported && !hasCatalog) {
      final mappedEmpty = program != null && importedDay == null;
      return EmptyStateWidget(
        icon: Icons.today_outlined,
        title: mappedEmpty ? 'Nothing mapped to today' : 'Nothing for today',
        message: mappedEmpty
            ? 'This imported plan has no meals for today. Open Meals for the full plan, or paste another day.'
            : 'Import a clinic PDF or paste the plan text. A household catalog week is a fallback if you do not have a PDF.',
        action: AppButton(
          label: 'Import plan',
          onPressed: () => context.pushNamed(AnyaRouteNames.importPdf),
        ),
      );
    }
    final next = importedDay == null
        ? null
        : nextMealSlot(importedDay.meals, now);
    return ListView(
      padding: AiroSpacing.paddingMd,
      children: [
        if (importedDay != null && program != null) ...[
          Text(
            'From ${program.title}',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          Text('Day ${importedDay.dayNumber} · next up below'),
          const SizedBox(height: AiroSpacing.md),
          for (final slot in importedDay.meals)
            Padding(
              padding: const EdgeInsets.only(bottom: AiroSpacing.sm),
              child: AppCard(
                child: ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: Icon(
                    slot == next ? Icons.play_circle_fill : Icons.schedule,
                  ),
                  title: Text(slot.items.map((item) => item.name).join(', ')),
                  subtitle: Text(
                    '${slot.type.label}'
                    '${slot.time == null ? '' : ' · ${slot.time}'}'
                    '${slot == next ? ' · up next' : ''}',
                  ),
                ),
              ),
            ),
        ],
        if (hasCatalog) ...[
          if (hasImported) const SizedBox(height: AiroSpacing.md),
          Text(
            'Household catalog (fallback)',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const Text(
            'Use these meals when you do not have a clinic PDF for today.',
          ),
          const SizedBox(height: AiroSpacing.md),
          for (final meal in catalogMeals)
            Padding(
              padding: const EdgeInsets.only(bottom: AiroSpacing.sm),
              child: AppCard(
                onTap: () => context.pushNamed(
                  AnyaRouteNames.mealDetail,
                  pathParameters: {'id': meal.id},
                ),
                child: ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(meal.meal.name),
                  subtitle: Text(
                    '${meal.mealType.label} · ${meal.nutrition.calories} kcal',
                  ),
                  trailing: const Icon(Icons.chevron_right),
                ),
              ),
            ),
        ],
      ],
    );
  }
}
