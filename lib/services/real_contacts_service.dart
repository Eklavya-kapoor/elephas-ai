import 'dart:developer' as developer;
import 'package:flutter_contacts/flutter_contacts.dart';
import 'package:permission_handler/permission_handler.dart';

/// Real phone contacts sync - replaces the old screen-text name-guessing
/// heuristic. Reads the actual Android Contacts database so a message
/// showing a display name (e.g. a WhatsApp Business profile, a spoofed
/// name, or any sender that isn't a raw phone number) only gets treated
/// as a genuinely saved contact if that exact name is found in the
/// user's real contacts - not just because it "looks like a name".
class RealContactsService {
  static RealContactsService? _instance;
  static RealContactsService get instance =>
      _instance ??= RealContactsService._();
  RealContactsService._();

  bool _isSynced = false;
  DateTime? _lastSyncTime;

  // Normalized (lowercase, trimmed) display names from the phone's contacts
  final Set<String> _contactNames = {};

  // Normalized (digits only, no country-code prefix ambiguity handled via
  // suffix match) phone numbers from the phone's contacts
  final Set<String> _contactPhoneDigits = {};

  bool get isSynced => _isSynced;
  DateTime? get lastSyncTime => _lastSyncTime;
  int get contactCount => _contactNames.length;

  Future<bool> requestPermission() async {
    final status = await Permission.contacts.status;
    if (status.isGranted) return true;
    final result = await Permission.contacts.request();
    return result.isGranted;
  }

  /// Sync the real phone contacts into memory. Call once at startup and
  /// periodically (e.g. on app resume) since contacts can change.
  Future<void> syncContacts() async {
    try {
      final hasPermission = await requestPermission();
      if (!hasPermission) {
        developer.log('⚠️ Contacts permission denied - cannot sync real contacts',
            name: 'RealContactsService');
        return;
      }

      final contacts = await FlutterContacts.getContacts(
        withProperties: true,
        withPhoto: false,
      );

      _contactNames.clear();
      _contactPhoneDigits.clear();

      for (final contact in contacts) {
        final name = contact.displayName.trim().toLowerCase();
        if (name.isNotEmpty) {
          _contactNames.add(name);
        }
        for (final phone in contact.phones) {
          final digits = _normalizePhoneDigits(phone.number);
          if (digits.length >= 7) {
            _contactPhoneDigits.add(digits);
          }
        }
      }

      _isSynced = true;
      _lastSyncTime = DateTime.now();
      developer.log(
          '✅ Synced ${contacts.length} real contacts (${_contactNames.length} names, ${_contactPhoneDigits.length} numbers)',
          name: 'RealContactsService');
    } catch (e) {
      developer.log('❌ Contact sync failed: $e', name: 'RealContactsService');
    }
  }

  String _normalizePhoneDigits(String raw) {
    final digitsOnly = raw.replaceAll(RegExp(r'[^\d]'), '');
    // Keep last 10 digits so country-code prefixes (91, +91, 0091 etc) don't
    // cause a mismatch against numbers stored without the prefix.
    if (digitsOnly.length > 10) {
      return digitsOnly.substring(digitsOnly.length - 10);
    }
    return digitsOnly;
  }

  /// True only if this exact display name matches a real saved contact.
  /// Safe default: if contacts haven't synced yet or permission was denied,
  /// returns false (treat as NOT a known contact) rather than assuming trust.
  bool isKnownContactName(String displayName) {
    if (!_isSynced) return false;
    final normalized = displayName.trim().toLowerCase();
    if (normalized.isEmpty) return false;
    return _contactNames.contains(normalized);
  }

  /// True only if this phone number matches a real saved contact.
  bool isKnownPhoneNumber(String phoneNumber) {
    if (!_isSynced) return false;
    final digits = _normalizePhoneDigits(phoneNumber);
    if (digits.length < 7) return false;
    return _contactPhoneDigits.contains(digits);
  }
}
