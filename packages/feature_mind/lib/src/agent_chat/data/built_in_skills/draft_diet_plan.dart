import '../../../runtime/models/capability_models.dart';
import '../../domain/models/agent_skill.dart';

/// Generative plugin: no device tools. Chat injects [instructions] into the
/// system prompt and the selected local/cloud model writes the plan.
final draftDietPlanSkill = AgentSkill(
  id: 'draft-diet-plan',
  name: 'Diet Plan',
  description:
      'Draft or refine a meal plan from the user\'s stated constraints.',
  mode: AgentSkillMode.persona,
  family: AgentPersonaFamily.health,
  safetyClass: CapabilitySafetyClass.health,
  starterPrompts: const [
    'Make me a 7 day vegetarian diet plan',
    'Make me a 7 day diet plan veg only give me 3 days only',
  ],
  instructions:
      'When the user asks for a diet, meal plan, or a refinement of one, '
      'write a new plan from their stated constraints in this thread '
      '(days, veg/vegan/non-veg, allergies, cuisine, calories, budget, '
      'workout). Do not invent a fixed menu from the app. '
      'On a refinement, rewrite meals that no longer fit — do not keep the '
      'old meals and garnish them. Vegetarian/veg means no meat, fish, or '
      'eggs (dairy is OK unless they said vegan). If they named a cuisine, '
      'every meal must be from that cuisine. Each day must use different '
      'dishes. Later day counts override earlier ones. Write every requested '
      'day. Airo is not a clinician: refuse extreme restriction, eating-'
      'disorder crisis, pregnancy keto/fasting, or high-protein plans that '
      'conflict with kidney disease, and redirect to a doctor. '
      'If they mention a setback, stay non-judgmental. Do not call tools.',
  tools: const [],
);
