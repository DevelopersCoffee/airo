import 'package:feature_coins_core/src/models/merchant_category.dart';

/// One golden example: a merchant/transaction description and the category
/// a human labeler would assign it.
class MerchantGoldenExample {
  final String text;
  final MerchantCategory expected;

  const MerchantGoldenExample(this.text, this.expected);
}

/// Golden set v1 for COINS-AI-5 (auto-categorization) and COINS-AI-7 (this
/// harness). 30 examples, English + Hinglish -- a seed set to extend toward
/// #1650's target of 50, not the final corpus (real user-language coverage
/// needs a broader collection pass this session didn't have data for).
///
/// Versioned: never edit examples in place. Add `labeledMerchantsV2` and
/// keep this list frozen, so a scorecard from six months ago is still
/// reproducible against the fixture it was scored on.
const labeledMerchantsV1 = <MerchantGoldenExample>[
  // -- transport --
  MerchantGoldenExample('Uber', MerchantCategory('transport', 'Travel')),
  MerchantGoldenExample('Ola Cabs', MerchantCategory('transport', 'Travel')),
  MerchantGoldenExample(
    'Delhi Metro Card Recharge',
    MerchantCategory('transport', 'Travel'),
  ),
  MerchantGoldenExample(
    'IndiGo Flight Booking',
    MerchantCategory('transport', 'Travel'),
  ),
  MerchantGoldenExample(
    'auto wale ko cab fare diya',
    MerchantCategory('transport', 'Travel'),
  ),
  MerchantGoldenExample(
    'Ola se ghar gaya',
    MerchantCategory('transport', 'Travel'),
  ),

  // -- food --
  MerchantGoldenExample('Swiggy', MerchantCategory('food', 'Food')),
  MerchantGoldenExample('Zomato', MerchantCategory('food', 'Food')),
  MerchantGoldenExample(
    'Starbucks Coffee',
    MerchantCategory('food', 'Food'),
  ),
  MerchantGoldenExample(
    'Domino\'s Pizza',
    MerchantCategory('food', 'Food'),
  ),
  MerchantGoldenExample(
    'swiggy se khana mangaya',
    MerchantCategory('food', 'Food'),
  ),
  MerchantGoldenExample(
    'dinner ke liye restaurant gaye',
    MerchantCategory('food', 'Food'),
  ),
  MerchantGoldenExample(
    'chai coffee lunch ka bill',
    MerchantCategory('food', 'Food'),
  ),

  // -- entertainment (shipped under the "shopping" category id today) --
  MerchantGoldenExample(
    'Netflix Subscription',
    MerchantCategory('shopping', 'Entertainment'),
  ),
  MerchantGoldenExample(
    'Spotify Premium',
    MerchantCategory('shopping', 'Entertainment'),
  ),
  MerchantGoldenExample(
    'PVR Cinema Tickets',
    MerchantCategory('shopping', 'Entertainment'),
  ),
  MerchantGoldenExample(
    'Steam Game Purchase',
    MerchantCategory('shopping', 'Entertainment'),
  ),
  MerchantGoldenExample(
    'movie dekhne gaye',
    MerchantCategory('shopping', 'Entertainment'),
  ),

  // -- income --
  MerchantGoldenExample(
    'Monthly Salary Credit',
    MerchantCategory('salary', 'Income'),
  ),
  MerchantGoldenExample(
    'Diwali Bonus',
    MerchantCategory('salary', 'Income'),
  ),
  MerchantGoldenExample(
    'salary aaya is mahine ka',
    MerchantCategory('salary', 'Income'),
  ),

  // -- shopping (default bucket) --
  MerchantGoldenExample(
    'Big Bazaar Grocery',
    MerchantCategory('shopping', 'Shopping'),
  ),
  MerchantGoldenExample(
    'Reliance Trends',
    MerchantCategory('shopping', 'Shopping'),
  ),
  MerchantGoldenExample(
    'IKEA Furniture',
    MerchantCategory('shopping', 'Shopping'),
  ),
  MerchantGoldenExample(
    'bazaar se saman liya',
    MerchantCategory('shopping', 'Shopping'),
  ),

  // -- abbreviated / no keyword overlap: the cases the regex baseline is
  // expected to get wrong, and the ones the eval accuracy comparison
  // exists to measure --
  MerchantGoldenExample('AMZN Mktp IN', MerchantCategory('shopping', 'Shopping')),
  MerchantGoldenExample(
    'Uber Eats',
    MerchantCategory('food', 'Food'),
  ),
  MerchantGoldenExample(
    'Uber Eats Koramangala',
    MerchantCategory('food', 'Food'),
  ),
  MerchantGoldenExample('Zepto', MerchantCategory('shopping', 'Shopping')),
  MerchantGoldenExample(
    'BluSmart EV Cab',
    MerchantCategory('transport', 'Travel'),
  ),
  MerchantGoldenExample(
    'Rapido Bike Taxi',
    MerchantCategory('transport', 'Travel'),
  ),
];
