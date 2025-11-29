import 'package:flutter/foundation.dart';
import 'package:flutter_contacts/flutter_contacts.dart';
import 'package:permission_handler/permission_handler.dart';
import '../models/bill_split_models.dart';

/// Service for accessing device contacts
abstract class ContactService {
  /// Check if contact permission is granted
  Future<bool> hasPermission();

  /// Request contact permission
  Future<bool> requestPermission();

  /// Get all contacts
  Future<List<Participant>> getContacts();

  /// Search contacts by name
  Future<List<Participant>> searchContacts(String query);

  /// Get recent contacts (frequently used)
  Future<List<Participant>> getRecentContacts();
}

/// Real implementation using device contacts
class DeviceContactService implements ContactService {
  List<Participant>? _cachedContacts;

  @override
  Future<bool> hasPermission() async {
    if (kIsWeb) return true; // Web uses fake contacts
    return await Permission.contacts.isGranted;
  }

  @override
  Future<bool> requestPermission() async {
    if (kIsWeb) return true;
    final status = await Permission.contacts.request();
    return status.isGranted;
  }

  @override
  Future<List<Participant>> getContacts() async {
    if (kIsWeb) return _getFakeContacts();

    // Check permission first
    if (!await hasPermission()) {
      final granted = await requestPermission();
      if (!granted) return _getFakeContacts();
    }

    // Try to fetch real contacts
    try {
      final contacts = await FlutterContacts.getContacts(
        withProperties: true,
        withPhoto: false,
      );

      _cachedContacts = contacts
          .where((c) => c.displayName.isNotEmpty)
          .map(
            (c) => Participant(
              id: c.id,
              name: c.displayName,
              phone: c.phones.isNotEmpty ? c.phones.first.number : null,
              email: c.emails.isNotEmpty ? c.emails.first.address : null,
            ),
          )
          .toList();

      // Sort alphabetically
      _cachedContacts!.sort((a, b) => a.name.compareTo(b.name));

      return _cachedContacts!;
    } catch (e) {
      debugPrint('Error fetching contacts: $e');
      return _getFakeContacts();
    }
  }

  @override
  Future<List<Participant>> searchContacts(String query) async {
    final contacts = _cachedContacts ?? await getContacts();
    if (query.isEmpty) return contacts;

    final lowerQuery = query.toLowerCase();
    return contacts.where((contact) {
      return contact.name.toLowerCase().contains(lowerQuery) ||
          (contact.phone?.contains(query) ?? false) ||
          (contact.email?.toLowerCase().contains(lowerQuery) ?? false);
    }).toList();
  }

  @override
  Future<List<Participant>> getRecentContacts() async {
    final contacts = await getContacts();
    // Return first 5 as "recent" (could be enhanced with usage tracking)
    return contacts.take(5).toList();
  }

  /// Fallback fake contacts for web or when permission denied
  List<Participant> _getFakeContacts() {
    return const [
      Participant(
        id: 'contact_1',
        name: 'Rahul Sharma',
        phone: '+91 98765 43210',
        email: 'rahul.sharma@email.com',
      ),
      Participant(
        id: 'contact_2',
        name: 'Priya Patel',
        phone: '+91 87654 32109',
        email: 'priya.patel@email.com',
      ),
      Participant(
        id: 'contact_3',
        name: 'Amit Kumar',
        phone: '+91 76543 21098',
        email: 'amit.kumar@email.com',
      ),
      Participant(
        id: 'contact_4',
        name: 'Sneha Gupta',
        phone: '+91 65432 10987',
        email: 'sneha.gupta@email.com',
      ),
      Participant(
        id: 'contact_5',
        name: 'Vikram Singh',
        phone: '+91 54321 09876',
        email: 'vikram.singh@email.com',
      ),
      Participant(
        id: 'contact_6',
        name: 'Neha Verma',
        phone: '+91 43210 98765',
        email: 'neha.verma@email.com',
      ),
      Participant(
        id: 'contact_7',
        name: 'Arjun Reddy',
        phone: '+91 32109 87654',
        email: 'arjun.reddy@email.com',
      ),
      Participant(
        id: 'contact_8',
        name: 'Kavita Nair',
        phone: '+91 21098 76543',
        email: 'kavita.nair@email.com',
      ),
    ];
  }
}

/// Alias for backward compatibility
typedef FakeContactService = DeviceContactService;
