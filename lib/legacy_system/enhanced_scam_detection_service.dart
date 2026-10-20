// Enhanced Scam Detection Service with Contact Awareness
// Integrates with ScamShield AI Backend

import 'dart:convert';
import 'dart:developer' as developer;
import 'package:http/http.dart' as http;
// import 'package:contacts_service/contacts_service.dart'; // Temporarily removed
import 'package:permission_handler/permission_handler.dart';

class ContactInfo {
  final String? name;
  final String phoneNumber;
  final bool isSaved;
  final ContactTrustLevel trustLevel;
  final int messageCount;

  ContactInfo({
    this.name,
    required this.phoneNumber,
    required this.isSaved,
    required this.trustLevel,
    required this.messageCount,
  });

  factory ContactInfo.unknown() {
    return ContactInfo(
      phoneNumber: '',
      isSaved: false,
      trustLevel: ContactTrustLevel.unknown,
      messageCount: 0,
    );
  }
}

enum ContactTrustLevel {
  unknown,
  suspicious,
  neutral,
  known,
  trustedContact,
  family,
}

class ScamDetectionResult {
  final bool isScam;
  final double confidence;
  final double adjustedRisk;
  final String trustLevel;
  final String reason;
  final Map<String, dynamic>? detailedAnalysis;
  final String? contactContext;
  final List<String> scamTypes;

  ScamDetectionResult({
    required this.isScam,
    required this.confidence,
    required this.adjustedRisk,
    required this.trustLevel,
    required this.reason,
    this.detailedAnalysis,
    this.contactContext,
    this.scamTypes = const [],
  });

  factory ScamDetectionResult.safe() {
    return ScamDetectionResult(
      isScam: false,
      confidence: 0.0,
      adjustedRisk: 0.0,
      trustLevel: 'safe',
      reason: 'Message appears safe',
    );
  }
}

class EnhancedScamDetectionService {
  // 🚀 Cloud Run Production API
  static const String _baseUrl =
      'https://scamshield-ai-438975884318.asia-south1.run.app';
  // � Local development (uncomment for local testing)
  // static const String _baseUrl = 'http://172.20.10.7:8000';

  // Contact information cache
  final Map<String, ContactInfo> _contactCache = {};

  /// Main method: Scan message with full contact context
  Future<ScamDetectionResult> scanMessageWithContext({
    required String text,
    String? sender,
    String? contactName,
    String? phoneNumber,
    bool? isSavedContact,
    int? messageHistory,
    String source = 'unknown',
  }) async {
    try {
      // Get contact information if not provided
      ContactInfo contactInfo;
      if (phoneNumber != null &&
          (contactName == null || isSavedContact == null)) {
        contactInfo = await getContactInfo(phoneNumber);
      } else {
        contactInfo = ContactInfo(
          name: contactName,
          phoneNumber: phoneNumber ?? '',
          isSaved: isSavedContact ?? false,
          trustLevel:
              _determineTrustLevel(contactName, isSavedContact ?? false),
          messageCount: messageHistory ?? 0,
        );
      }

      // Make API call with contact context
      final response = await http.post(
        Uri.parse('$_baseUrl/scan'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'text': text, // Using 'text' field to match backend expectations
          'sender': sender ?? '',
          'contact_name': contactInfo.name,
          'phone_number': contactInfo.phoneNumber,
          'is_saved_contact': contactInfo.isSaved,
          'message_history_count': contactInfo.messageCount,
          'metadata': {
            'source': source,
            'timestamp': DateTime.now().toIso8601String(),
            'trust_level': contactInfo.trustLevel.toString().split('.').last,
          }
        }),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);

        return ScamDetectionResult(
          isScam: data['classification'] == 'scam' || data['risk_score'] > 0.7,
          confidence: (data['risk_score'] as num).toDouble(),
          adjustedRisk: (data['adjusted_risk_score'] as num?)?.toDouble() ??
              data['risk_score'],
          trustLevel: data['contact_analysis']?['trust_level'] ?? 'unknown',
          reason: data['explanation'] ?? 'No explanation provided',
          detailedAnalysis: data['detailed_analysis'],
          contactContext: data['contact_analysis']?['reasoning'],
          scamTypes: List<String>.from(data['scam_types'] ?? []),
        );
      } else {
        developer.log('API Error: ${response.statusCode} - ${response.body}',
            name: 'ScamDetection');
        return ScamDetectionResult.safe();
      }
    } catch (e) {
      developer.log('Scan failed: $e', name: 'ScamDetection');
      return ScamDetectionResult.safe();
    }
  }

  /// Get contact information from phone's contact list
  Future<ContactInfo> getContactInfo(String phoneNumber) async {
    // Check cache first
    if (_contactCache.containsKey(phoneNumber)) {
      return _contactCache[phoneNumber]!;
    }

    try {
      // Request contacts permission if needed
      if (await Permission.contacts.request().isGranted) {
        // Mock contacts since ContactsService is not available
        final contacts = <MockContact>[];

        for (final contact in contacts) {
          for (final phone in contact.phones ?? []) {
            final cleanPhone = _normalizePhoneNumber(phone.value ?? '');
            final cleanSearchPhone = _normalizePhoneNumber(phoneNumber);

            if (cleanPhone == cleanSearchPhone) {
              final contactInfo = ContactInfo(
                name: contact.displayName,
                phoneNumber: phoneNumber,
                isSaved: true,
                trustLevel: _determineTrustLevel(contact.displayName, true),
                messageCount: await _getMessageHistoryCount(phoneNumber),
              );

              // Cache the result
              _contactCache[phoneNumber] = contactInfo;
              return contactInfo;
            }
          }
        }
      }

      // Contact not found
      final contactInfo = ContactInfo(
        phoneNumber: phoneNumber,
        isSaved: false,
        trustLevel: ContactTrustLevel.unknown,
        messageCount: 0,
      );

      _contactCache[phoneNumber] = contactInfo;
      return contactInfo;
    } catch (e) {
      developer.log('Error getting contact info: $e', name: 'ScamDetection');
      return ContactInfo.unknown();
    }
  }

  /// Determine trust level based on contact name and saved status
  ContactTrustLevel _determineTrustLevel(String? contactName, bool isSaved) {
    if (contactName == null || !isSaved) {
      return ContactTrustLevel.unknown;
    }

    final name = contactName.toLowerCase();

    // Family indicators
    const familyTerms = [
      'dad',
      'father',
      'papa',
      'baba',
      'abbu',
      'mom',
      'mother',
      'mama',
      'mummy',
      'ammi',
      'brother',
      'bhai',
      'sister',
      'behan',
      'didi',
      'son',
      'beta',
      'daughter',
      'beti',
      'uncle',
      'chacha',
      'tau',
      'mama',
      'aunt',
      'chachi',
      'tai',
      'mami',
      'grandmother',
      'nani',
      'dadi',
      'grandfather',
      'nana',
      'dada',
      'cousin',
      'wife',
      'husband',
      'patni',
      'pati'
    ];

    for (final term in familyTerms) {
      if (name.contains(term)) {
        return ContactTrustLevel.family;
      }
    }

    // If saved contact but not family, consider it known
    return ContactTrustLevel.known;
  }

  /// Normalize phone number for comparison
  String _normalizePhoneNumber(String phone) {
    // Remove all non-digits
    final digits = phone.replaceAll(RegExp(r'[^\d]'), '');

    // Take last 10 digits for comparison (handles country codes)
    if (digits.length >= 10) {
      return digits.substring(digits.length - 10);
    }

    return digits;
  }

  /// Get message history count (mock implementation)
  Future<int> _getMessageHistoryCount(String phoneNumber) async {
    // In a real implementation, you would query the SMS database
    // For now, return a mock value
    return 0;
  }

  /// Clear contact cache (useful for testing)
  void clearContactCache() {
    _contactCache.clear();
  }
}

// Mock classes to replace missing contacts_service dependency
class MockContact {
  final String? displayName;
  final List<MockPhone>? phones;

  MockContact({this.displayName, this.phones});
}

class MockPhone {
  final String? value;

  MockPhone({this.value});
}

// Usage Example:
class MessageScanningExample {
  final EnhancedScamDetectionService _scanner = EnhancedScamDetectionService();

  Future<void> scanIncomingSms(String messageBody, String senderPhone) async {
    developer.log('📱 Scanning SMS from $senderPhone', name: 'ScamDetection');

    final result = await _scanner.scanMessageWithContext(
      text: messageBody,
      phoneNumber: senderPhone,
      source: 'sms',
    );

    developer.log('🔍 Scan Result:', name: 'ScamDetection');
    developer.log('  Is Scam: ${result.isScam}', name: 'ScamDetection');
    developer.log('  Confidence: ${(result.confidence * 100).toInt()}%',
        name: 'ScamDetection');
    developer.log('  Adjusted Risk: ${(result.adjustedRisk * 100).toInt()}%',
        name: 'ScamDetection');
    developer.log('  Trust Level: ${result.trustLevel}', name: 'ScamDetection');
    developer.log('  Reason: ${result.reason}', name: 'ScamDetection');

    if (result.contactContext != null) {
      developer.log('  Contact Context: ${result.contactContext}',
          name: 'ScamDetection');
    }

    if (result.isScam) {
      await showCustomAlert(result, senderPhone);
    }
  }

  Future<void> scanWhatsAppMessage(String message, String contactName) async {
    developer.log('💬 Scanning WhatsApp message from $contactName',
        name: 'ScamDetection');

    final result = await _scanner.scanMessageWithContext(
      text: message,
      contactName: contactName,
      source: 'whatsapp',
    );

    if (result.isScam) {
      await showCustomAlert(result, contactName);
    }
  }

  Future<void> showCustomAlert(
      ScamDetectionResult result, String sender) async {
    developer.log('🚨 SCAM ALERT!', name: 'ScamDetection');
    developer.log('From: $sender', name: 'ScamDetection');
    developer.log('Risk: ${(result.adjustedRisk * 100).toInt()}%',
        name: 'ScamDetection');
    developer.log('Reason: ${result.reason}', name: 'ScamDetection');

    // Here you would show your custom Flutter alert overlay
    // with your custom image and UI
  }
}
