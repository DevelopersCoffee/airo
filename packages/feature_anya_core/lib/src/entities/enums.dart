/// Diet and grocery enumerations for Anya core.
library;

enum DietType { none, vegetarian, vegan, pescatarian }

enum FoodMood {
  speedy,
  lowCalorie,
  familyFavorites,
  healthyComfort,
  budgetFriendly,
  proteinPacked,
}

enum Weekday { monday, tuesday, wednesday, thursday, friday, saturday, sunday }

enum MealType { earlyMorning, breakfast, snack, lunch, evening, dinner }

enum GroceryAisle { vegetables, dairy, grains, protein, other }

enum PageClass {
  profile,
  phase,
  mealPlan,
  foodsToInclude,
  foodsToAvoid,
  guidelines,
  lockedContent,
  unknown,
}

enum ProgramSource { generated, imported }

extension DietTypeLabel on DietType {
  String get label => switch (this) {
    DietType.none => 'No restriction',
    DietType.vegetarian => 'Vegetarian',
    DietType.vegan => 'Vegan',
    DietType.pescatarian => 'Pescatarian',
  };
}

extension FoodMoodLabel on FoodMood {
  String get label => switch (this) {
    FoodMood.speedy => 'Speedy meals',
    FoodMood.lowCalorie => 'Low calorie',
    FoodMood.familyFavorites => 'Family favorites',
    FoodMood.healthyComfort => 'Healthy comfort',
    FoodMood.budgetFriendly => 'Budget friendly',
    FoodMood.proteinPacked => 'Protein packed',
  };
}

extension WeekdayLabel on Weekday {
  String get shortLabel => name.substring(0, 3).toUpperCase();
}

extension MealTypeLabel on MealType {
  String get label => switch (this) {
    MealType.earlyMorning => 'Early morning',
    MealType.breakfast => 'Breakfast',
    MealType.snack => 'Snack',
    MealType.lunch => 'Lunch',
    MealType.evening => 'Evening',
    MealType.dinner => 'Dinner',
  };
}

extension GroceryAisleLabel on GroceryAisle {
  String get label => switch (this) {
    GroceryAisle.vegetables => 'Vegetables',
    GroceryAisle.dairy => 'Dairy',
    GroceryAisle.grains => 'Grains',
    GroceryAisle.protein => 'Protein',
    GroceryAisle.other => 'Other',
  };
}
