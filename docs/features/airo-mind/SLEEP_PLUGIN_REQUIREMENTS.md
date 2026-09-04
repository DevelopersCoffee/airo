# Airo Mind sleep/Yoga Nidra plugin — requirements

Goal: agent chat plugin generating guided sleep-relaxation scripts (Yoga Nidra /
body scan / breathing) on request, plus daily practice reminder. Extends the
existing feature_mind agent-plugin system — no new subsystem.

## 1. Prompt plugin
Mirror `DietPlanPluginPrompt` pattern
(packages/feature_mind/lib/src/agent_chat/data/services/diet_plan_plugin_prompt.dart):
- `SleepPluginPrompt.applies()` — detect intent (sleep, insomnia, "can't
  sleep," yoga nidra, relaxation, meditation-for-sleep, NSDR/power nap).
- `modelUserPrompt()` — calm/slow tone, no emoji, phases (settle → intention/
  sankalpa → body scan → breath+opposites → reawaken), duration-aware
  (5/10/20/30 min).
- Two output modes: full script (10-min default), and a short intake question
  first ("racing thoughts or physical tension?") before generating.

## 2. Safety guardrails (required)
- No medical diagnosis. Clinical chronic insomnia / sleep apnea mention →
  append disclaimer, still give general script.
- Panic/anxiety-attack language → short-circuit to 4-7-8 breathing only, skip
  full script.
- Reuse `looksLikeModelRefusal` retry pattern from diet plugin.

## 3. Addon adapter (real wiring, not optional)
Diet plugin ships as `DraftDietPlanAdapter`
(packages/feature_mind/lib/src/addons/draft_diet_plan/draft_diet_plan_adapter.dart),
registered in `built_in_addon_registry.dart`. Sleep plugin needs the matching
`SleepPluginAdapter` + registry entry — prompt class alone does not wire it
into the agent chat pipeline.

## 4. Catalog entry
Add to agent_plugin_catalog — `id: sleep_yoga_nidra`, family: wellness/calm
(closest existing `AgentPersonaFamily`), `safety_class: health` (matches diet
plugin precedent — sleep/insomnia is medical-adjacent, not general).

## 5. Extra safety guardrails beyond diet-plugin precedent
- **Crisis language** (self-harm, hopelessness) → hard stop, no script, show
  helpline message. Not covered by the panic→4-7-8 path; needs its own check,
  diet plugin has no equivalent to copy.
- **Sedative/substance interaction** — sleep medication, alcohol, melatonin
  dosing questions → refuse dosing advice, defer to doctor/pharmacist. Mirrors
  diet's pregnancy/kidney/insulin pattern but is a new check, not reused.

## 6. Daily reminder — reuse existing ReminderRequestParser, no new engine
(packages/feature_mind/lib/src/agent_chat/domain/services/reminder_request_parser.dart)
- `ReminderRequestCategory.habit` + `ReminderScheduleType.dailyTime` +
  `repeatDaily: true` already cover "remind me every day to practice."
- Gap: parser must recognize sleep-practice phrasing ("remind me to do yoga
  nidra every night," "daily sleep practice reminder") and route to habit
  category.
- **Time: ask the user's actual wind-down time, never hardcode a default.**
  Research: self-tuning reminder time beats arbitrary fixed time ~3x on
  follow-through.
- **Copy: habit-stack framing, not a streak counter** ("after you plug your
  phone in tonight...") — streak mechanics drive shame-churn when broken;
  commitment framing outperforms for effortful habits.
- **Backoff on ignored reminders** — days of no engagement should reduce
  frequency or prompt to cancel, not keep firing (spam kills retention).
- Reminder message links back into the sleep plugin so tapping it reopens
  chat pre-loaded with the sleep intent.

## 7. Text-only pacing scaffolding (compensates for no audio)
Research finding: silently *reading* a relaxation script is measurably less
effective than being guided — reading keeps the mind in active/analytical
processing exactly when the goal is to disengage it. Since TTS is out of
scope, the script text itself must carry pacing cues: short lines, one
instruction per beat, explicit "pause for 3 breaths here" markers, ellipses
as pacing signals. This is a real requirement on `modelUserPrompt()` output
formatting, not a nice-to-have.

## 8. Not building
No TTS/voice synthesis (deferred — revisit only if usage data shows text
pacing is the actual bottleneck), no script personalization/variety yet (no
usage data to justify it), no streak visuals or commitment-contract UI, no
new architecture doc, no microservice.
