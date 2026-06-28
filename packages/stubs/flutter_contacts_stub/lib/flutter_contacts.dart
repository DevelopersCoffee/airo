/// Stub implementation of flutter_contacts for TV builds
library;

/// Contact class
class Contact {
  Contact({
    this.id = '',
    this.displayName = '',
    Name? name,
    this.phones = const [],
    this.emails = const [],
  }) : name = name ?? Name();
  final String id;
  final String displayName;
  final Name name;
  final List<Phone> phones;
  final List<Email> emails;
}

/// Name class
class Name {
  Name({this.first = '', this.last = '', this.middle = ''});
  final String first;
  final String last;
  final String middle;
}

/// Phone class
class Phone {
  Phone(this.number, {this.label = PhoneLabel.mobile});
  final String number;
  final PhoneLabel label;
}

/// Phone label
enum PhoneLabel { mobile, home, work, other }

/// Email class
class Email {
  Email(this.address, {this.label = EmailLabel.home});
  final String address;
  final EmailLabel label;
}

/// Email label
enum EmailLabel { home, work, other }

/// Contact properties supported by the real plugin.
enum ContactProperty {
  name,
  phone,
  email,
  address,
  organization,
  website,
  socialMedia,
  event,
  relation,
  note,
  favorite,
  ringtone,
  sendToVoicemail,
  photoThumbnail,
  photoFullRes,
  timestamp,
  identifiers,
}

/// Common property sets supported by the real plugin.
class ContactProperties {
  ContactProperties._();

  static const Set<ContactProperty> none = <ContactProperty>{};
  static const Set<ContactProperty> allProperties = {
    ContactProperty.name,
    ContactProperty.phone,
    ContactProperty.email,
    ContactProperty.address,
    ContactProperty.organization,
    ContactProperty.website,
    ContactProperty.socialMedia,
    ContactProperty.event,
    ContactProperty.relation,
    ContactProperty.note,
    ContactProperty.favorite,
    ContactProperty.ringtone,
    ContactProperty.sendToVoicemail,
    ContactProperty.timestamp,
    ContactProperty.identifiers,
  };
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

  /// Get all contacts - returns empty list on TV
  static Future<List<Contact>> getAll({
    Set<ContactProperty>? properties,
    int? limit,
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
