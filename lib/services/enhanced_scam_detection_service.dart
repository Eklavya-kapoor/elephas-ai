// Enhanced Scam Detection Service with Contact Awareness
// Integrates with ScamShield AI Backend

import 'dart:convert';
import 'dart:developer' as developer;
import 'package:http/http.dart' as http;
// import 'package:contacts_service/contacts_service.dart'; // Temporarily removed
import 'package:permission_handler/permission_handler.dart';
import '../config/app_config.dart';

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
  final bool containsUrl;
  final AlertType alertType;
  final double confidence;
  final double adjustedRisk;
  final String trustLevel;
  final String reason;
  final Map<String, dynamic>? detailedAnalysis;
  final String? contactContext;
  final List<String> scamTypes;
  final List<String> detectedUrls;
  final Map<String, dynamic>? metadata;
  final RiskLevel riskLevel;
  final DateTime timestamp;
  final String messageText;

  ScamDetectionResult({
    required this.isScam,
    required this.confidence,
    required this.adjustedRisk,
    required this.trustLevel,
    required this.reason,
    required this.messageText,
    this.detailedAnalysis,
    this.contactContext,
    this.scamTypes = const [],
    this.containsUrl = false,
    this.detectedUrls = const [],
    this.metadata,
    AlertType? alertType,
    RiskLevel? riskLevel,
    DateTime? timestamp,
  })  : alertType =
            alertType ?? _determineAlertType(isScam, containsUrl, messageText),
        riskLevel = riskLevel ?? _determineRiskLevel(adjustedRisk),
        timestamp = timestamp ?? DateTime.now();

  static AlertType _determineAlertType(
      bool isScam, bool hasUrl, String messageText) {
    if (!isScam) return AlertType.none; // Only show alerts for confirmed scams

    // Check if message is URL-only (no other meaningful text)
    final cleanText =
        messageText.trim().replaceAll(RegExp(r'https?://[^\s]+'), '').trim();
    final isUrlOnly = hasUrl && (cleanText.isEmpty || cleanText.length < 5);

    if (isUrlOnly) {
      return AlertType.scamUrl; // url_alert.png - URL-only scam
    } else {
      return AlertType
          .scamMessage; // overlay_image.png - Scam message with text
    }
  }

  static RiskLevel _determineRiskLevel(double risk) {
    if (risk >= 0.8) return RiskLevel.critical;
    if (risk >= 0.6) return RiskLevel.high;
    if (risk >= 0.4) return RiskLevel.medium;
    if (risk >= 0.2) return RiskLevel.low;
    return RiskLevel.minimal;
  }

  factory ScamDetectionResult.safe({String messageText = ''}) {
    return ScamDetectionResult(
      isScam: false,
      confidence: 0.0,
      adjustedRisk: 0.0,
      trustLevel: 'safe',
      reason: 'Message appears safe',
      messageText: messageText,
    );
  }
}

enum AlertType {
  none, // No alert needed
  scamMessage, // overlay_image.png - Scam message with text
  scamUrl // url_alert.png - Scam URL only (no text)
}

enum RiskLevel {
  minimal, // Very low risk
  low, // Low risk
  medium, // Medium risk
  high, // High risk
  critical, // Critical risk
}

class EnhancedScamDetectionService {
  // 🚀 Use AppConfig for API URL selection
  String get _baseUrl => AppConfig.apiUrl;

  // API key for authentication
  Map<String, String> get _authHeaders => {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer ${AppConfig.apiKey}',
      };
  // � Local development (uncomment for local testing)
  // static const String _baseUrl = 'http://192.168.1.13:8000';

  // Contact information cache
  final Map<String, ContactInfo> _contactCache = {};

  /// Regular expressions for URL detection
  static final _urlRegex = RegExp(
    r'(?:(?:https?|ftp):\/\/)?' // Protocol (optional)
    r'(?:(?:[a-z0-9](?:[a-z0-9-]*[a-z0-9])?\.)+[a-z0-9](?:[a-z0-9-]*[a-z0-9])?|\d{1,3}\.\d{1,3}\.\d{1,3}\.\d{1,3})' // Domain
    r'(?::\d+)?' // Port (optional)
    r'(?:\/[^\s]*)?', // Path (optional)
    caseSensitive: false,
  );

  /// Detects URLs in text
  List<String> _detectUrls(String text) {
    return _urlRegex
        .allMatches(text)
        .map((match) => match.group(0)!)
        .where((url) => url.isNotEmpty)
        .toList();
  }

  /// Main method: Scan message with full contact context
  Future<ScamDetectionResult> scanMessageWithContext({
    required String text,
    String? sender,
    String? contactName,
    String? phoneNumber,
    bool? isSavedContact,
    int? messageHistory,
    String source = 'unknown',
    String? packageName,
  }) async {
    try {
      // Detect URLs in the message
      final detectedUrls = _detectUrls(text);
      final containsUrl = detectedUrls.isNotEmpty;

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

      // Make API call with contact context and URL information
      final response = await http.post(
        Uri.parse('$_baseUrl/scan'),
        headers: _authHeaders,
        body: json.encode({
          'text': text,
          'sender': sender ?? '',
          'contact_name': contactInfo.name,
          'phone_number': contactInfo.phoneNumber,
          'is_saved_contact': contactInfo.isSaved,
          'message_history_count': contactInfo.messageCount,
          'metadata': {
            'source': source,
            'timestamp': DateTime.now().toIso8601String(),
            'trust_level': contactInfo.trustLevel.toString().split('.').last,
            'contains_url': containsUrl,
            'urls': detectedUrls,
            'package_name': packageName ?? 'unknown',
          }
        }),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        developer.log('API Response: $data', name: 'ScamDetection');

        // Extract score and determine if it's a scam
        final score = (data['score'] as num).toDouble();
        final isScam = data['result'] == 'scam' || score > 0.7;

        // Calculate adjusted risk based on contact context
        final adjustedScore = score * (contactInfo.isSaved ? 0.8 : 1.2);

        return ScamDetectionResult(
          isScam: isScam,
          containsUrl: containsUrl,
          detectedUrls: detectedUrls,
          confidence: score,
          adjustedRisk: adjustedScore,
          trustLevel: contactInfo.trustLevel.toString().split('.').last,
          reason: _buildReason(data['explanation'], containsUrl, isScam),
          detailedAnalysis: {
            'raw_score': score,
            'adjusted_score': adjustedScore
          },
          contactContext:
              contactInfo.isSaved ? 'Known contact' : 'Unknown sender',
          scamTypes: isScam ? ['potential_scam'] : [],
          messageText: text,
        );
      } else {
        developer.log(
          'API Error: ${response.statusCode} - ${response.body}',
          name: 'ScamDetection',
          error: 'HTTP ${response.statusCode}',
        );
        // Instead of silently failing, return a result indicating the error
        return ScamDetectionResult(
          isScam: false,
          confidence: 0.0,
          adjustedRisk: 0.0,
          trustLevel: 'error',
          reason:
              'Error: Could not analyze message (HTTP ${response.statusCode})',
          messageText: text,
          metadata: {'error': 'API_ERROR', 'status': response.statusCode},
        );
      }
    } catch (e, stackTrace) {
      developer.log(
        'Scan failed: $e\n$stackTrace',
        name: 'ScamDetection',
        error: e,
        stackTrace: stackTrace,
      );
      // Return result with error information instead of default "safe"
      return ScamDetectionResult(
        isScam: false,
        confidence: 0.0,
        adjustedRisk: 0.0,
        trustLevel: 'error',
        reason: 'Error: Could not analyze message (${e.toString()})',
        messageText: text,
        metadata: {'error': 'PROCESSING_ERROR', 'details': e.toString()},
      );
    }
  }

  String _buildReason(String? backendReason, bool hasUrl, bool isScam) {
    if (isScam) {
      return backendReason ?? 'Message detected as potential scam';
    } else if (hasUrl) {
      return 'This message contains a URL. Be cautious before clicking any links. ${backendReason ?? ''}';
    }
    return backendReason ?? 'Message appears safe';
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

  Future<void> scanWhatsAppMessage(String message, String contactName,
      {String? packageName}) async {
    developer.log('💬 Scanning WhatsApp message from $contactName',
        name: 'ScamDetection');

    final result = await _scanner.scanMessageWithContext(
      text: message,
      contactName: contactName,
      source: 'whatsapp',
      packageName: packageName ?? 'com.whatsapp',
    );

    // Log the scan result for debugging
    developer.log(
        'WhatsApp Scan Result - Risk Score: ${result.adjustedRisk}, Confidence: ${result.confidence}',
        name: 'ScamDetection');

    // Show alert if risk score is high enough, regardless of previous alerts
    if (result.adjustedRisk >= 0.6) {
      // Match the backend threshold
      developer.log('🚨 High risk message detected in WhatsApp',
          name: 'ScamDetection');
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
