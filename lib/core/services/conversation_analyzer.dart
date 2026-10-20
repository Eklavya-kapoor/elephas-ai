import 'dart:async';
import 'dart:developer' as developer;
import '../models/detection_models.dart';
import '../../services/backend_api_service.dart';
import './contact_intelligence.dart' as intelligence;
import '../models/contact_info.dart';
import '../models/alert_types.dart';

/// Service responsible for analyzing conversations and messages for scams
class ConversationAnalyzer {
  static const String _logTag = 'ConversationAnalyzer';

  final intelligence.ContactIntelligenceService _contactService;
  final BackendApiService _backendService;
  bool _isInitialized = false;

  ConversationAnalyzer._()
      : _contactService = intelligence.ContactIntelligenceService(),
        _backendService = BackendApiService.instance;

  static final ConversationAnalyzer instance = ConversationAnalyzer._();

  /// Initialize the analyzer
  Future<void> initialize() async {
    if (_isInitialized) return;
    try {
      await _contactService.initialize();
      _isInitialized = true;
      developer.log('🚀 Conversation analyzer initialized', name: _logTag);
    } catch (e) {
      developer.log('❌ Failed to initialize: $e', name: _logTag, error: e);
      rethrow;
    }
  }

  /// Clean message based on app source
  String _cleanMessage(String message, String? appPackage) {
    if (message.isEmpty) return message;

    if (appPackage == 'com.whatsapp') {
      // Extract core message content
      return message
          .replaceAll(RegExp(r'Video call Voice call More options\s*'), '')
          .replaceAll(RegExp(r'\[[\d:]+\]\s*'), '')
          .replaceAll(RegExp(r'[\u{1F300}-\u{1F9FF}]', unicode: true), '')
          .replaceAll(RegExp(r'\<[^>]*\>'), '')
          .replaceAll(RegExp(r'Navigation menu\s*'), '')
          .replaceAll(RegExp(r'New chat\s*'), '')
          .replaceAll(RegExp(r'End-to-end encrypted\s*'), '')
          .replaceAll(
              RegExp(r'Messages and calls are end-to-end encrypted\s*'), '')
          .trim();
    }

    return message.trim();
  }

  /// Analyze message for potential scams
  Future<DetectionResult> analyzeMessage({
    required String message,
    String? appPackage,
    ContactInfo? contactInfo,
    String? contactId,
    String? conversationHistory,
  }) async {
    if (!_isInitialized) {
      return DetectionResult(
        isThreat: false,
        riskScore: 0.0,
        confidence: 1.0,
        reasoning: "Service initialization required",
        message: "Analyzer not initialized",
        evidence: {'error': 'not_initialized'},
        riskLevel: RiskLevel.minimal,
        contactId: contactId,
      );
    }

    // Check for empty message
    if (message.isEmpty) {
      return DetectionResult(
        isThreat: false,
        riskScore: 0.0,
        confidence: 1.0,
        reasoning: "Empty message content",
        message: message,
        riskLevel: RiskLevel.minimal,
      );
    }

    // Clean message based on app source
    final cleanedMessage = _cleanMessage(message, appPackage);

    // Check contact trust level before analysis if contact info is available
    if (contactInfo != null) {
      final info = await _contactService.getContactInfo(contactInfo.id);
      if (info != null && info.trustScore >= 0.8) {
        developer.log('Trusted contact - skipping analysis', name: _logTag);
        return DetectionResult(
          isThreat: false,
          riskScore: 0.0,
          confidence: 1.0,
          reasoning: "Trusted contact",
          message: cleanedMessage,
          contactId: contactId,
          riskLevel: RiskLevel.minimal,
        );
      }
    }

    // Analyze with backend API
    return _backendService.analyzeContent(
      cleanedMessage,
      appPackage: appPackage,
      contactId: contactId,
      conversationHistory: conversationHistory,
    );
  }
}
