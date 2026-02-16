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

### Low Priority - Receipt Domain Models
- [x] **receipt_item.dart** - ReceiptItem, ReceiptFee, ParsedReceipt classes
  - Commit: `fd2c623` - refactor(bill-split): use locale-aware currency formatting in receipt domain models
  - Changed: Added `formatPrice()`, `formatUnitPrice()`, `formatAmount()`, `formatGrandTotal()`, `formatItemTotal()` methods that accept `CurrencyFormatter`
  - Deprecated old getters for backward compatibility
  - Updated `_MultiParticipantItemTile`, `_buildVendorHeader()`, `_buildFeesSection()` in itemized_split_screen.dart

### Low Priority - AI Service Prompts
- [x] **gemini_api_service.dart** - AI prompt update
  - Commit: `58eba36` - refactor(ai): use locale-agnostic currency terms in AI prompts
  - Changed: Updated prompt from "Indian currency (₹/Rs) values" to "Extract currency values as decimal numbers without currency symbols"

### Low Priority - Database Defaults
- [x] **app_database.dart** - Currency default documentation
  - Commit: `0099ae6` - docs(database): document INR as fallback currency default
  - Changed: Added documentation comments to `defaultCurrency` and `currencyCode` columns in GroupEntries, SharedExpenseEntries, and SettlementEntries
  - Documents that INR is a fallback default and user locale settings should override

### Low Priority - Bill Split Models
- [x] **bill_split_models.dart** - Currency enum integration
  - Commit: `997f822` - refactor(bill-split): add locale integration for default currency in domain models
  - Changed: Added `Currency.fromSupportedCurrency()` conversion method
  - Changed: Added `Currency.fromCode()` factory method
  - Added documentation explaining INR defaults and how to use locale settings

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
- **Completed**: 8 ✅
- **Remaining**: 0 🔄
- **Completion**: 100% ✅

Last Updated: 2026-02-16

### Commits in Order
1. `3b33d33` - refactor(money): use locale-aware currency formatting in domain models
2. `b441515` - refactor(bill-split): use currencyFormatterProvider for locale-aware currency display
3. `0840bd3` - docs: add locale migration tracking document
4. `fd2c623` - refactor(bill-split): use locale-aware currency formatting in receipt domain models
5. `58eba36` - refactor(ai): use locale-agnostic currency terms in AI prompts
6. `0099ae6` - docs(database): document INR as fallback currency default
7. `997f822` - refactor(bill-split): add locale integration for default currency in domain models
8. `e29d6f5` - refactor(bill-split): use locale-aware currency in bill input card

---

## Follow-Up Work

See [LOCALE_ONBOARDING_REQUIREMENTS.md](./LOCALE_ONBOARDING_REQUIREMENTS.md) for user onboarding currency selection requirements.

