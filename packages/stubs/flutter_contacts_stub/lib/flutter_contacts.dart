/// Stub implementation of flutter_contacts for TV builds
library;

/// Contact class
class Contact {
  final String id;
  final String displayName;
  final Name name;
  final List<Phone> phones;
  final List<Email> emails;
  
  Contact({
    this.id = '',
    this.displayName = '',
    Name? name,
    this.phones = const [],
    this.emails = const [],
  }) : name = name ?? Name();
}

/// Name class
class Name {
  final String first;
  final String last;
  final String middle;
  
  Name({
    this.first = '',
    this.last = '',
    this.middle = '',
  });
}

/// Phone class
class Phone {
  final String number;
  final PhoneLabel label;
  
  Phone(this.number, {this.label = PhoneLabel.mobile});
}

/// Phone label
enum PhoneLabel {
  mobile,
  home,
  work,
  other,
}

/// Email class
class Email {
  final String address;
  final EmailLabel label;
  
  Email(this.address, {this.label = EmailLabel.home});
}

/// Email label
enum EmailLabel {
  home,
  work,
  other,
}

/// Stub FlutterContacts - returns empty list on TV
class FlutterContacts {
  /// Request permission - returns false on TV
  static Future<bool> requestPermission() async => false;
  
  /// Get contacts - returns empty list on TV
  static Future<List<Contact>> getContacts({
    bool withProperties = false,
    bool withPhoto = false,
    bool withThumbnail = false,
    bool withAccounts = false,
    bool withGroups = false,
    bool sorted = true,
    bool deduplicateProperties = true,
  }) async => [];
  
  /// Get contact - returns null on TV
  static Future<Contact?> getContact(
    String id, {
    bool withProperties = true,
    bool withPhoto = false,
    bool withThumbnail = false,
    bool withAccounts = false,
    bool withGroups = false,
    bool deduplicateProperties = true,
  }) async => null;
  
  /// Open external pick - returns null on TV
  static Future<Contact?> openExternalPick() async => null;
  
  /// Open external view - does nothing on TV
  static Future<void> openExternalView(String id) async {}
  
  /// Open external edit - returns null on TV
  static Future<Contact?> openExternalEdit(String id) async => null;
  
  /// Open external insert - returns null on TV
  static Future<Contact?> openExternalInsert([Contact? contact]) async => null;
}

