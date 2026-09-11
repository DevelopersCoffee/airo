import 'package:core_ui/core_ui.dart';
import 'package:feature_anya_core/feature_anya_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../providers/anya_providers.dart';

class OnboardingScreen extends ConsumerStatefulWidget {
  const OnboardingScreen({super.key});

  @override
  ConsumerState<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends ConsumerState<OnboardingScreen> {
  DietType _diet = DietType.vegetarian;
  int _people = 2;
  double _budget = 80;
  final _days = <Weekday>{Weekday.monday, Weekday.wednesday, Weekday.friday};
  final _moods = <FoodMood>{FoodMood.speedy, FoodMood.budgetFriendly};
  final _allergies = TextEditingController();
  final _dislikes = TextEditingController();
  final _store = TextEditingController();
  final _age = TextEditingController();
  final _height = TextEditingController();
  final _weight = TextEditingController();

  @override
  void initState() {
    super.initState();
    final profile = ref.read(anyaSessionProvider).profile;
    if (profile == null) return;
    _diet = profile.dietType;
    _people = profile.householdSize;
    _budget = profile.weeklyBudget;
    _days
      ..clear()
      ..addAll(profile.cookingDays);
    _moods
      ..clear()
      ..addAll(profile.moods);
    _allergies.text = profile.allergies;
    _dislikes.text = profile.dislikes;
    _store.text = profile.preferredStore;
    _age.text = profile.age?.toString() ?? '';
    _height.text = profile.heightCm?.toString() ?? '';
    _weight.text = profile.weightKg?.toString() ?? '';
  }

  @override
  void dispose() {
    _allergies.dispose();
    _dislikes.dispose();
    _store.dispose();
    _age.dispose();
    _height.dispose();
    _weight.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Anya Diet')),
      body: SingleChildScrollView(
        padding: AiroSpacing.paddingMd,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Who are you cooking for?',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: AiroSpacing.sm),
            Text(
              'This builds a household catalog week as a fallback. If you have a clinic PDF, import that — it stays the source of truth.',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: AiroSpacing.md),
            Wrap(
              spacing: AiroSpacing.sm,
              children: [
                for (final diet in DietType.values)
                  ChoiceChip(
                    label: Text(diet.label),
                    selected: _diet == diet,
                    onSelected: (_) => setState(() => _diet = diet),
                  ),
              ],
            ),
            const SizedBox(height: AiroSpacing.lg),
            Text('Household size: $_people'),
            Slider(
              min: 1,
              max: 8,
              divisions: 7,
              value: _people.toDouble(),
              label: '$_people',
              onChanged: (value) => setState(() => _people = value.round()),
            ),
            Text('Weekly budget: ${_budget.round()}'),
            Slider(
              min: 20,
              max: 200,
              divisions: 18,
              value: _budget,
              label: _budget.round().toString(),
              onChanged: (value) => setState(() => _budget = value),
            ),
            const SizedBox(height: AiroSpacing.md),
            Text(
              'Cooking days',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            Wrap(
              spacing: AiroSpacing.sm,
              children: [
                for (final day in Weekday.values)
                  FilterChip(
                    label: Text(day.shortLabel),
                    selected: _days.contains(day),
                    onSelected: (selected) => setState(() {
                      if (selected) {
                        _days.add(day);
                      } else {
                        _days.remove(day);
                      }
                    }),
                  ),
              ],
            ),
            const SizedBox(height: AiroSpacing.md),
            Text('Food moods', style: Theme.of(context).textTheme.titleMedium),
            Wrap(
              spacing: AiroSpacing.sm,
              children: [
                for (final mood in FoodMood.values)
                  FilterChip(
                    label: Text(mood.label),
                    selected: _moods.contains(mood),
                    onSelected: (selected) => setState(() {
                      if (selected) {
                        _moods.add(mood);
                      } else {
                        _moods.remove(mood);
                      }
                    }),
                  ),
              ],
            ),
            const SizedBox(height: AiroSpacing.md),
            TextField(
              controller: _allergies,
              decoration: const InputDecoration(
                labelText: 'Allergies',
                hintText: 'peanuts, shellfish',
              ),
            ),
            const SizedBox(height: AiroSpacing.sm),
            TextField(
              controller: _dislikes,
              decoration: const InputDecoration(labelText: 'Dislikes'),
            ),
            const SizedBox(height: AiroSpacing.sm),
            TextField(
              controller: _store,
              decoration: const InputDecoration(
                labelText: 'Preferred grocery store',
              ),
            ),
            const SizedBox(height: AiroSpacing.lg),
            Text(
              'Optional body stats',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: AiroSpacing.xs),
            Text(
              'Stored locally. Anya does not compute calorie or BMI targets.',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: AiroSpacing.sm),
            TextField(
              controller: _age,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'Age'),
            ),
            const SizedBox(height: AiroSpacing.sm),
            TextField(
              controller: _height,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'Height (cm)'),
            ),
            const SizedBox(height: AiroSpacing.sm),
            TextField(
              controller: _weight,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              decoration: const InputDecoration(labelText: 'Weight (kg)'),
            ),
            const SizedBox(height: AiroSpacing.lg),
            AppButton(
              label: 'Build this week',
              isExpanded: true,
              onPressed: _days.isEmpty ? null : _submit,
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _submit() async {
    final profile = DietProfile(
      dietType: _diet,
      householdSize: _people,
      weeklyBudget: _budget,
      cookingDays: Weekday.values.where(_days.contains).toList(),
      moods: _moods,
      allergies: _allergies.text,
      dislikes: _dislikes.text,
      preferredStore: _store.text,
      age: int.tryParse(_age.text.trim()),
      heightCm: int.tryParse(_height.text.trim()),
      weightKg: double.tryParse(_weight.text.trim()),
    );
    await ref.read(anyaSessionProvider.notifier).saveProfile(profile);
    if (mounted) context.go('/');
  }
}
