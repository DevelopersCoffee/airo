# Anya MVP — standalone nutrition planner

**Date:** 2026-09-10
**Status:** Approved for implementation
**Product:** Anya — "Your Personal Nutrition Planner"
**Surfaces:** Anya Diet, Anya Meals, Anya Grocery (Anya AI deferred)

## Objective

Ship Anya as a focused Airo product shell, the same way Aika Stream and Airo
Coins are focused shells — not as a Mind chat plugin. A user can onboard a
household profile, get a deterministic weekly meal plan from a local catalog,
import a text-layer diet PDF into an editable program, and generate a grocery
list. Calories, allergens, quantities, and restrictions come from structured
data, not a model.

## Non-goals (this slice)

- OCR / scanned-PDF understanding (empty extract + “OCR coming” state)
- LLM, `core_ai`, or Mind `draft-diet-plan`
- Rust/Go backend, Postgres, object storage
- Medical calorie/BMI prescription from onboarding
- Takeout/restaurant, PDF export, notifications, subscriptions
- Super-app tab in `app/lib/main.dart`
- Automatic merge of multiple PDFs into one multi-phase program

## Wellness, not medical

Onboarding stores optional age/height/weight but does not compute calorie
targets. Home always shows: “Anya is a general nutrition planner, not medical
advice.” Health-adjacent persistence is local JSON via `shared_preferences`.

## Architecture

```
packages/feature_anya_core   pure Dart entities + engines
packages/feature_anya        Flutter UI + AppModule + PDF extract adapter
app/lib/main_anya.dart      ShellId.anya bootstrap
app/pubspec_anya.yaml       lean flavor
```

LLM is not a dependency. Syncfusion PDF text extract lives only in
`feature_anya` behind `AnyaPdfTextExtractor`. Parsing over PDF bytes runs
through `runOffMain()` from `core_workers`.

## Domain entities

`DietProfile`, `CatalogMeal`, `WeeklyPlan`, `DietProgram` / `DietPhase` /
`DietDay` / `MealSlot` / `FoodItem` (`quantityRaw` preserved), `DietRule`,
`GroceryList`, `UploadedDocument` / `DocumentPage`, `ExtractionValidation`.

PDF page classes: `PROFILE`, `PHASE`, `MEAL_PLAN`, `FOODS_TO_INCLUDE`,
`FOODS_TO_AVOID`, `GUIDELINES`, `LOCKED_CONTENT`, `UNKNOWN`.

Do not rewrite unclear quantities (`1k` stays `1k`).

## PDF contract

1. Extract per-page text (empty page = no text layer).
2. Classify pages with heuristics.
3. Normalize meals/rules.
4. Show a validation summary.
5. User reviews, edits, then confirms a `DietProgram`.

Multiple PDFs become separate programs the user can switch.

## Success criteria

- `ShellId.anya` boots a standalone app titled Anya.
- Catalog planner produces a weekly plan + grouped grocery list.
- Day-7 poha fixture parses to JSON with `quantityRaw: "1k"`.
- Scanned/empty PDF does not crash; UI explains OCR is not in this slice.
- `feature_anya` / `feature_anya_core` do not depend on `app`, `core_ai`, or
  `feature_mind`.
