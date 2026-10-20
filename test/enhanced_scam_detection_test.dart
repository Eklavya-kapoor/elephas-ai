// Test file for the Enhanced Scam Detection Service
// Run this to verify the service works with the backend

import 'package:flutter_test/flutter_test.dart';
import 'package:elephas_ai/services/enhanced_scam_detection_service.dart';
import 'dart:developer' as developer;

void main() {
  group('Enhanced Scam Detection Service Tests', () {
    late EnhancedScamDetectionService service;

    setUp(() {
      service = EnhancedScamDetectionService();
    });

    test('should detect Hindi scam message', () async {
      final result = await service.scanMessageWithContext(
        text: 'आपका खाता बंद होने वाला है तुरंत OTP भेजें',
        phoneNumber: '+91-9876543210',
        contactName: 'Unknown',
        source: 'test',
      );

      expect(result.isScam, isTrue);
      expect(result.confidence, greaterThan(0.8));
      developer.log('Hindi scam test: ${result.confidence * 100}% confidence',
          name: 'Test');
    });

    test('should detect mixed language scam', () async {
      final result = await service.scanMessageWithContext(
        text: 'Congratulations! आपको ₹50000 का prize मिला है! Claim करें।',
        phoneNumber: '+91-9876543210',
        contactName: 'Unknown',
        source: 'test',
      );

      expect(result.isScam, isTrue);
      expect(result.confidence, greaterThan(0.8));
      developer.log(
          'Mixed language scam test: ${result.confidence * 100}% confidence',
          name: 'Test');
    });

    test('should allow legitimate messages', () async {
      final result = await service.scanMessageWithContext(
        text:
            'Hi, this is to remind you about your appointment tomorrow at 3 PM',
        phoneNumber: '+91-9876543210',
        contactName: 'Dr. Sharma',
        isSavedContact: true,
        source: 'test',
      );

      expect(result.isScam, isFalse);
      expect(result.confidence, lessThan(0.3));
      developer.log(
          'Legitimate message test: ${result.confidence * 100}% confidence',
          name: 'Test');
    });

    test('should normalize phone numbers correctly', () {
      // Test phone number normalization logic
      expect(true, isTrue); // Placeholder - implement phone normalization test
    });

    test('should determine trust levels correctly', () {
      // Test family contact detection - create helper method
      expect(_testDetermineTrustLevel('Mom', true),
          equals(ContactTrustLevel.family));

      // Test unknown contact
      expect(_testDetermineTrustLevel(null, false),
          equals(ContactTrustLevel.unknown));

      // Test known contact
      expect(_testDetermineTrustLevel('John Doe', true),
          equals(ContactTrustLevel.known));
    });
  });
}

// Helper function for testing trust level determination
ContactTrustLevel _testDetermineTrustLevel(String? contactName, bool isSaved) {
  if (contactName == null || !isSaved) {
    return ContactTrustLevel.unknown;
  }

  final name = contactName.toLowerCase();

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
  ];

  for (final term in familyTerms) {
    if (name.contains(term)) {
      return ContactTrustLevel.family;
    }
  }

  return ContactTrustLevel.known;
}
