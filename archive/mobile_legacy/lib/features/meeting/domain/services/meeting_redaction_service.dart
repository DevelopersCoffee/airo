class MeetingRedactionService {
  static final RegExp _cardNumberPattern = RegExp(r'\b(?:\d[ -]?){13,19}\b');
  static final RegExp _phonePattern = RegExp(
    r'(?:\+?\d{1,3}[\s-]?)?(?:\d[\s-]?){9,12}\d',
  );

  String redact(String input) {
    return input
        .replaceAllMapped(_cardNumberPattern, (_) => '[REDACTED_CARD]')
        .replaceAllMapped(_phonePattern, (_) => '[REDACTED_PHONE]');
  }
}
