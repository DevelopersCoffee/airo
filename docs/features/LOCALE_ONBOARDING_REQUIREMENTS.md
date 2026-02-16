# Locale Onboarding Requirements

This document outlines the requirements for adding currency/locale selection during user onboarding to complete the global locale support initiative.

---

## User Story

**As a new user, I want to select my preferred currency during onboarding so the app displays amounts in my local currency.**

---

## Acceptance Criteria

### Required
- [ ] During onboarding, user is presented with a currency/region selection screen
- [ ] Screen displays all supported currencies with their symbols and country names
- [ ] User can search/filter the currency list
- [ ] Selected currency is persisted to user preferences
- [ ] App immediately reflects the selected currency across all money-related screens
- [ ] User can skip selection (defaults to device locale or INR as fallback)

### Optional Enhancements
- [ ] Auto-detect currency based on device locale/region
- [ ] Show "Recommended" badge for detected currency
- [ ] Allow changing currency later from Settings screen
- [ ] Support multiple currencies for users who travel/work internationally

---

## Technical Implementation Notes

### 1. Onboarding Screen Integration

Add a new step to the onboarding flow after account creation:

```dart
// In onboarding_screen.dart or similar
class CurrencySelectionStep extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final localeSettings = ref.watch(localeSettingsProvider);
    
    return CurrencyPicker(
      selectedCurrency: localeSettings.currency,
      onCurrencySelected: (currency) {
        ref.read(localeSettingsProvider.notifier).setCurrency(currency);
      },
    );
  }
}
```

### 2. Persistence Layer

Store user's locale preference in local database:

```dart
// Add to user_preferences table or similar
class UserPreferences {
  final String currencyCode;  // e.g., 'INR', 'USD', 'EUR', 'GBP'
  final String localeCode;    // e.g., 'en_IN', 'en_US', 'de_DE'
}
```

### 3. Provider Initialization

Update `LocaleSettingsNotifier` to load from persistence on app startup:

```dart
class LocaleSettingsNotifier extends StateNotifier<LocaleSettings> {
  final UserPreferencesRepository _prefsRepo;
  
  LocaleSettingsNotifier(this._prefsRepo) : super(LocaleSettings.india) {
    _loadSavedSettings();
  }
  
  Future<void> _loadSavedSettings() async {
    final prefs = await _prefsRepo.getLocalePreferences();
    if (prefs != null) {
      state = LocaleSettings.fromCurrencyCode(prefs.currencyCode);
    }
  }
  
  Future<void> setCurrency(String currencyCode) async {
    state = LocaleSettings.fromCurrencyCode(currencyCode);
    await _prefsRepo.saveLocalePreferences(currencyCode);
  }
}
```

### 4. Supported Currencies

| Code | Symbol | Locale | Country/Region |
|------|--------|--------|----------------|
| INR | ₹ | en_IN | India |
| USD | $ | en_US | United States |
| EUR | € | de_DE | European Union |
| GBP | £ | en_GB | United Kingdom |

---

## Priority and Effort

| Attribute | Value |
|-----------|-------|
| **Priority** | Medium |
| **Effort** | 3-5 story points |
| **Sprint** | Phase 2 or later |
| **Dependencies** | Locale infrastructure (completed) |

### Effort Breakdown
- Onboarding UI screen: 1-2 points
- Persistence layer: 1 point
- Provider updates: 0.5 points
- Settings screen integration: 0.5-1 point
- Testing: 1 point

---

## Dependencies

### Completed Prerequisites ✅
1. `LocaleSettings` class with multi-locale support
2. `CurrencyFormatter` with INR, USD, EUR, GBP support
3. `localeSettingsProvider` and `currencyFormatterProvider` 
4. All UI components updated to use locale-aware formatting
5. Domain models support `CurrencyFormatter` parameter

### Required Before Implementation
1. Onboarding flow architecture (if not already present)
2. User preferences persistence mechanism
3. Settings screen navigation structure

---

## Related Files

| File | Purpose |
|------|---------|
| `app/lib/core/utils/locale_settings.dart` | Locale settings provider |
| `app/lib/core/utils/currency_formatter.dart` | Currency formatting utilities |
| `docs/features/LOCALE_MIGRATION_TASKS.md` | Migration tracking (100% complete) |

---

## Testing Considerations

- Unit tests for persistence and provider initialization
- Widget tests for currency selection UI
- Integration tests for full onboarding flow with currency selection
- Verify currency displays correctly across all screens after selection

---

Last Updated: 2026-02-16

