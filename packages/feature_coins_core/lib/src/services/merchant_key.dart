/// Normalizes a transaction description into a merchant grouping key.
/// Shared by [RecurrenceAnomalyDetector] and the categorization services so
/// "Netflix", "NETFLIX", and "  netflix  " are always the same merchant.
String normalizeMerchantKey(String description) =>
    description.trim().toLowerCase();
