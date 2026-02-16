# Locale Migration Tasks

This document tracks remaining hardcoded locale assumptions in the codebase that need to be updated for global scalability.

## ✅ Completed Tasks

### High Priority - Currency Formatting in Domain Models
- [x] **money_models.dart** - Budget, MoneyAccount, Transaction classes
  - Commit: `3b33d33` - refactor(money): use locale-aware currency formatting in domain models
  - Changed: Added `formatLimit()`, `formatBalance()`, `formatAmount()` methods that accept `CurrencyFormatter`
  - Deprecated old getters for backward compatibility

### Medium Priority - Bill Split Screens
- [x] **bill_split_screen.dart** - Currency symbol display
  - Commit: `b441515` - refactor(bill-split): use currencyFormatterProvider for locale-aware currency display
  - Changed: `_buildInputView()` and `_buildSplitOptionSection()` use `currencyFormatterProvider`

- [x] **itemized_split_screen.dart** - Currency symbol display
  - Commit: `b441515` - refactor(bill-split): use currencyFormatterProvider for locale-aware currency display
  - Changed: `generateWhatsAppMessage()` accepts `currencySymbol` parameter
  - Changed: `_confirmSplit()`, `_buildSummaryFooter()`, `_SummaryCard` updated

---

## 🔄 Remaining Tasks

### Low Priority - Receipt Domain Models

- [ ] **app/lib/features/bill_split/domain/models/receipt_item.dart**
  - Line 85: `formattedPrice => '₹${(totalPricePaise / 100).toStringAsFixed(2)}'`
  - Line 89: `formattedUnitPrice => '₹${(unitPricePaise / 100).toStringAsFixed(2)}'`
  - **Current Value**: Hardcoded `₹` symbol
  - **Recommended Change**: Add `formatPrice(CurrencyFormatter)` method, deprecate getter
  - **Estimated Effort**: Low (1-2 hours)
  - **Impact**: Limited - used for Indian receipt parsing only
  - **Dependencies**: None

### Low Priority - AI Service Prompts

- [ ] **app/lib/core/services/gemini_api_service.dart**
  - Line 72: AI prompt mentions "Indian currency (₹/Rs) values"
  - **Current Value**: India-specific prompt
  - **Recommended Change**: Make prompt locale-aware or use generic currency terms
  - **Estimated Effort**: Low (1-2 hours)
  - **Impact**: Affects AI receipt parsing accuracy for non-INR receipts
  - **Dependencies**: May need regional prompt variants

### Low Priority - Database Defaults

- [ ] **app/lib/core/database/app_database.dart**
  - Lines 123, 158, 196: `withDefault(const Constant('INR'))`
  - **Current Value**: Default currency = 'INR'
  - **Recommended Change**: Keep as fallback, ensure user settings override
  - **Estimated Effort**: Very Low (configuration only)
  - **Impact**: Only affects new users without explicit currency selection
  - **Dependencies**: User onboarding flow should collect currency preference

### Low Priority - Bill Split Models

- [ ] **app/lib/features/bill_split/domain/models/bill_split_models.dart**
  - Line 5: `Currency` enum includes INR as default
  - Lines 106, 147: Default `currency = Currency.inr`
  - **Current Value**: INR as default currency enum value
  - **Recommended Change**: Get default from user's locale settings
  - **Estimated Effort**: Low (2-3 hours)
  - **Impact**: Affects default currency in new splits
  - **Dependencies**: Should integrate with locale settings

---

## Not Requiring Changes

The following files contain locale references that are **intentional configuration**:

| File | Location | Reason |
|------|----------|--------|
| `currency_formatter.dart` | Lines 5, 44, 91 | Locale config definitions - correct |
| `locale_settings.dart` | Lines 16-17, 70-71 | Default/fallback config - correct |
| `app_database.g.dart` | Generated | Auto-generated from schema |

---

## Migration Guidelines

### When Adding New Currency Display

1. **Use `currencyFormatterProvider`** in Riverpod widgets:
   ```dart
   final currencySymbol = ref.watch(currencyFormatterProvider).currency.symbol;
   ```

2. **Accept `CurrencyFormatter` parameter** in domain models:
   ```dart
   String formatAmount(CurrencyFormatter formatter) {
     return formatter.formatCents(amountCents);
   }
   ```

3. **Use optional parameter with default** for backward compatibility:
   ```dart
   String generateMessage({String currencySymbol = '₹'}) { ... }
   ```

### Supported Locales

| Locale | Currency | Symbol | Date Format |
|--------|----------|--------|-------------|
| en_IN (India) | INR | ₹ | dd/MM/yyyy |
| en_US (United States) | USD | $ | MM/dd/yyyy |
| de_DE (Germany/EU) | EUR | € | dd.MM.yyyy |
| en_GB (United Kingdom) | GBP | £ | dd/MM/yyyy |

---

## Progress Tracking

- **Total Tasks**: 8
- **Completed**: 4 ✅
- **Remaining**: 4 🔄
- **Completion**: 50%

Last Updated: 2026-02-16

