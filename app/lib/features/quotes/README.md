# Daily Quotes Feature

A personalized daily quote system that makes every user feel unique by showing different quotes to different users on the same day.

## Features

- **Personalized Daily Quotes**: Each user gets a unique quote based on their user ID + current date
- **ZenQuotes API Integration**: Fetches inspirational quotes from https://zenquotes.io/
- **Offline Support**: Caches quotes locally for 7 days
- **Beautiful UI**: Two widget variants (full card and compact)
- **Time-based Greetings**: Shows "Good morning/afternoon/evening" with username

## How It Works

### Personalization Algorithm

The quote selection uses a deterministic algorithm:
```dart
final seed = '${userId}_${dateString}'.hashCode.abs();
final index = seed % quotes.length;
```

This ensures:
- Same user sees the same quote all day
- Different users see different quotes on the same day
- Quotes rotate daily for each user
- No server-side state needed

### Caching Strategy

- Quotes are cached locally using SharedPreferences
- Cache duration: 7 days
- Automatic refresh when cache expires
- Fallback quotes if API fails

## Usage

### Full Quote Card

```dart
import 'package:airo_app/features/quotes/quotes.dart';

// In your widget
const DailyQuoteCard(
  showGreeting: true,  // Show personalized greeting
  padding: EdgeInsets.all(16),
  elevation: 2,
)
```

### Compact Quote Card

```dart
import 'package:airo_app/features/quotes/quotes.dart';

// In your widget
const CompactQuoteCard()
```

## Integration Points

Currently integrated in:
- **Agent Chat Screen** (`/agent`) - Full card at top
- **Money Overview Screen** (`/money`) - Full card at top
- **Reader Screen** (`/reader`) - Compact card at top

## API Service

### ZenQuotes API

- **Endpoint**: `https://zenquotes.io/api/quotes`
- **Rate Limits**: Free tier has rate limits
- **Response Format**: JSON array of quote objects

### Switching to Real API

To enable the real ZenQuotes API, update `quote_provider.dart`:

```dart
final quoteServiceProvider = Provider<QuoteService>((ref) async {
  final dio = ref.watch(dioProvider);
  final prefs = await SharedPreferences.getInstance();
  return ZenQuotesService(dio: dio, prefs: prefs);
});
```

Currently using `FakeQuoteService` for development.

## File Structure

```
lib/features/quotes/
├── domain/
│   ├── models/
│   │   └── quote_model.dart          # Quote data model
│   └── services/
│       └── quote_service.dart        # Service interface & implementations
├── application/
│   └── providers/
│       └── quote_provider.dart       # Riverpod providers
├── presentation/
│   └── widgets/
│       └── daily_quote_card.dart     # UI widgets
├── quotes.dart                       # Public exports
└── README.md                         # This file
```

## Customization

### Adding More Quotes

Edit `FakeQuoteService._quotes` in `quote_service.dart` to add more fallback quotes.

### Changing Cache Duration

Edit `_cacheDuration` in `ZenQuotesService`:

```dart
static const Duration _cacheDuration = Duration(days: 7);
```

### Styling

The widgets use Material 3 theming and adapt to:
- `colorScheme.primaryContainer`
- `colorScheme.secondaryContainer`
- `colorScheme.primary`
- `colorScheme.onSurface`

## Future Enhancements

- [ ] User preference to hide/show quotes
- [ ] Favorite quotes feature
- [ ] Share quote functionality
- [ ] Multiple quote sources
- [ ] Category-based quotes (motivational, wisdom, humor, etc.)
- [ ] Quote of the week/month
- [ ] User-submitted quotes

