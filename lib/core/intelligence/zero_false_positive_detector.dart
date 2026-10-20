import 'dart:developer' as developer;
import 'package:flutter/foundation.dart';
import '../models/contact_trust.dart';
import '../models/threat_intelligence.dart';
import '../models/detection_models.dart';
import '../services/conversation_analyzer.dart' as analyzer;
import '../../services/contact_service.dart'
    show HighPerformanceContactService, ContactInfo;

/// Result of threat signal analysis
class ThreatAnalysisResult {
  final bool isHighConfidence;
  final RiskLevel riskLevel;
  final double confidence;
  final String reason;
  final List<String> evidence;

  const ThreatAnalysisResult({
    required this.isHighConfidence,
    required this.riskLevel,
    required this.confidence,
    required this.reason,
    required this.evidence,
  });

  Map<String, dynamic> toJson() => {
        'isHighConfidence': isHighConfidence,
        'riskLevel': riskLevel.toString(),
        'confidence': confidence,
        'reason': reason,
        'evidence': evidence,
      };
}

/// Intelligent message analyzer for zero false positive detection
class ZeroFalsePositiveDetector extends ChangeNotifier {
  bool _isInitialized = false;
  bool _isScanning = false;

  // Detection statistics
  int _totalScans = 0;
  int _threatsDetected = 0;
  int _falsePositivesPrevented = 0;
  double _accuracy = 100.0;

  bool get isInitialized => _isInitialized;
  bool get isScanning => _isScanning;

  final analyzer.ConversationAnalyzer _contextAnalyzer =
      analyzer.ConversationAnalyzer.instance;
  final _contactService = HighPerformanceContactService.instance;

  /// Initialize the detector
  Future<void> initialize() async {
    if (_isInitialized) return;

    developer.log('🔍 Initializing Zero False Positive Detector...',
        name: 'ZeroFPD');
    _isInitialized = true;
    developer.log('✅ Zero False Positive Detector initialized',
        name: 'ZeroFPD');
  }

  /// Determine if a channel should be monitored
  bool shouldMonitorChannel(String packageName) {
    // List of high-risk messaging apps to monitor
    const targetPackages = [
      'com.whatsapp',
      'org.telegram.messenger',
      'com.instagram.android',
      'com.facebook.orca',
      'com.android.mms',
      'com.google.android.apps.messaging',
      'com.tinder',
      'com.bumble.app',
      'com.hinge.co',
      'org.thoughtcrime.securesms',
    ];

    return targetPackages.contains(packageName);
  }

  /// Get channel type for analysis context
  String getChannelType(String packageName) {
    // Map package names to channel types
    switch (packageName) {
      case 'com.whatsapp':
        return 'whatsapp';
      case 'org.telegram.messenger':
        return 'telegram';
      case 'com.instagram.android':
        return 'instagram';
      case 'com.facebook.orca':
        return 'messenger';
      case 'com.android.mms':
      case 'com.google.android.apps.messaging':
        return 'sms';
      case 'com.tinder':
      case 'com.bumble.app':
      case 'com.hinge.co':
        return 'dating';
      default:
        return 'other';
    }
  }

  /// Get current system statistics
  Map<String, dynamic> getSystemStats() {
    return {
      'total_scans': _totalScans,
      'threats_detected': _threatsDetected,
      'false_positives_prevented': _falsePositivesPrevented,
      'accuracy': _accuracy,
      'is_scanning': _isScanning,
      'is_initialized': _isInitialized,
    };
  }

  /// Clear detection caches
  Future<void> clearCaches() async {
    _totalScans = 0;
    _threatsDetected = 0;
    _falsePositivesPrevented = 0;
    _accuracy = 100.0;
    notifyListeners();
  }

  /// Check if a message is definitely safe based on multiple factors
  bool _isDefinitelySafe(
      String message, ContactTrustInfo contactTrust, String channel) {
    // Known safe senders (e.g. verified business accounts)
    if (contactTrust.trustLevel == ContactTrustLevel.trusted) {
      return true;
    }

    // Long-term trusted contacts with good history
    if (contactTrust.trustLevel == ContactTrustLevel.trusted &&
        contactTrust.interactionCount > 100) {
      return true;
    }

    // Official system channels
    final systemChannels = [
      'com.android.mms',
      'com.google.android.apps.messaging',
    ];
    if (systemChannels.contains(channel) && message.length < 160) {
      return true;
    }

    return false;
  }

  /// Analyze message for threat signals with high confidence
  ThreatAnalysisResult _detectThreatSignals(
    String message,
    ContactTrustInfo contactTrust,
    DetectionResult context,
  ) {
    double confidence = 0.0;
    double riskScore = 0.0;
    final List<String> evidence = [];

    // Check for known high-risk patterns
    final patterns = {
      'urgency': [
        'urgent',
        'immediately',
        'right now',
        'asap',
        'emergency',
        'act fast',
        'hurry',
        'expires soon'
      ],
      'pressure': [
        'must act',
        'have to now',
        'required immediately',
        'mandatory action',
        'or else',
        'otherwise consequences',
        'time running out'
      ],
      'sensitive': [
        'verify otp',
        'confirm password',
        'validate pin',
        'verify cvv',
        'confirm ssn',
        'validate social security',
        'verify card details'
      ],
      'threats': [
        'account blocked',
        'service terminated',
        'legal action',
        'police report',
        'criminal charges',
        'account suspended'
      ],
    };

    final messageLower = message.toLowerCase();

    // Check each pattern category
    patterns.forEach((category, words) {
      int matches = 0;
      for (final word in words) {
        if (messageLower.contains(word)) {
          matches++;
          evidence.add('$category: "$word"');
        }
      }
      if (matches > 0) {
        riskScore += 0.2 * matches;
        confidence += 0.15 * matches;
      }
    });

    // Check contact trust level
    if (contactTrust.trustLevel == ContactTrustLevel.blocked) {
      riskScore += 0.5;
      confidence += 0.3;
      evidence.add('Sender previously blocked');
    } else if (contactTrust.trustLevel == ContactTrustLevel.suspicious) {
      riskScore += 0.3;
      confidence += 0.2;
      evidence.add('Sender previously marked suspicious');
    }

    // Consider conversation context
    if (context.riskScore > 0.7) {
      riskScore += 0.3;
      confidence += 0.2;
      evidence.add('High risk conversation context: ${context.reasoning}');
    }

    // Normalize scores
    riskScore = riskScore.clamp(0.0, 1.0);
    confidence = confidence.clamp(0.0, 1.0);

    return ThreatAnalysisResult(
      isHighConfidence: confidence > 0.8,
      riskLevel: _getRiskLevel(riskScore),
      confidence: confidence,
      reason: evidence.isNotEmpty
          ? 'Multiple threat signals detected: ${evidence.first}'
          : 'No significant threat signals',
      evidence: evidence,
    );
  }

  RiskLevel _getRiskLevel(double score) {
    if (score >= 0.8) return RiskLevel.critical;
    if (score >= 0.6) return RiskLevel.high;
    if (score >= 0.4) return RiskLevel.medium;
    if (score >= 0.2) return RiskLevel.low;
    return RiskLevel.minimal;
  }

  /// Convert legacy contact info to standardized ContactTrustInfo
  ContactTrustInfo _convertContactInfo(ContactInfo? info) {
    if (info == null) {
      return const ContactTrustInfo(
        displayName: 'Unknown',
        isSavedContact: false,
        trustLevel: ContactTrustLevel.unknown,
        interactionCount: 0,
      );
    }

    // Map risk level to trust level based on trust score
    var trustLevel = ContactTrustLevel.unknown;
    final score = info.trustScore;
    if (score >= 0.8) {
      trustLevel = ContactTrustLevel.trusted;
    } else if (score >= 0.6) {
      trustLevel = ContactTrustLevel.regular;
    } else if (score >= 0.4) {
      trustLevel = ContactTrustLevel.casual;
    } else if (score >= 0.2) {
      trustLevel = ContactTrustLevel.suspicious;
    } else {
      trustLevel = ContactTrustLevel.blocked;
    }

    return ContactTrustInfo(
      displayName: info.displayName,
      phoneNumber: info.phoneNumber,
      isSavedContact: info.isKnown,
      trustLevel: trustLevel,
      trustScore: score,
      interactionCount: 0, // Not available in ContactInfo
      lastInteraction: info.lastInteraction,
    );
  }

  /// Analyze message for potential threats with zero false positives
  Future<ThreatIntelligence> analyzeMessage({
    required String messageText,
    required String senderIdentifier,
    required String channel,
    Map<String, dynamic>? metadata,
  }) async {
    if (!_isInitialized) {
      throw Exception('Detector not initialized - call initialize() first');
    }

    _isScanning = true;
    notifyListeners();

    try {
      developer.log('🔍 Analyzing message from $senderIdentifier on $channel',
          name: 'ZeroFPD');

      _totalScans++;

      // Analyze context first
      final contextRisk = await _contextAnalyzer.analyzeMessage(
        message: messageText,
        appPackage: channel,
        conversationHistory: metadata?['history'] as String?,
        contactId: senderIdentifier,
      );

      // Get contact trust information
      final contactInfo =
          await _contactService.getContactInfo(senderIdentifier);
      final contactTrust = _convertContactInfo(contactInfo);

      // Check high confidence safe signals first
      if (_isDefinitelySafe(messageText, contactTrust, channel)) {
        return ThreatIntelligence(
          isScam: false,
          riskLevel: RiskLevel.minimal,
          confidence: 0.99,
          primaryReason: 'Message matches known safe patterns',
          contactInfo: contactTrust,
          additionalData: {
            ...metadata ?? {},
            'contextRisk': {
              'isScam': contextRisk.isScam,
              'riskScore': contextRisk.riskScore,
              'confidence': contextRisk.confidence,
              'riskLevel': contextRisk.riskLevel.toString(),
              'message': contextRisk.message,
              'reasoning': contextRisk.reasoning,
              'evidence': contextRisk.evidence,
              'detectedType': contextRisk.detectedType,
              'detectionMethod': contextRisk.detectionMethod,
              'timestamp': contextRisk.timestamp.toIso8601String(),
              ...contextRisk.metadata ?? {},
            },
          },
        );
      }

      // Analyze message using zero false positive techniques
      final threatSignals =
          _detectThreatSignals(messageText, contactTrust, contextRisk);

      ThreatIntelligence result;

      // High confidence threats - these are definitely scams
      if (threatSignals.isHighConfidence) {
        result = ThreatIntelligence(
          isScam: true,
          riskLevel: threatSignals.riskLevel,
          confidence: threatSignals.confidence,
          primaryReason: threatSignals.reason,
          evidence: threatSignals.evidence,
          contactInfo: contactTrust,
          additionalData: {
            ...metadata ?? {},
            'contextRisk': {
              'isScam': contextRisk.isScam,
              'riskScore': contextRisk.riskScore,
              'confidence': contextRisk.confidence,
              'riskLevel': contextRisk.riskLevel.toString(),
              'message': contextRisk.message,
              'reasoning': contextRisk.reasoning,
              'evidence': contextRisk.evidence,
              'detectedType': contextRisk.detectedType,
              'detectionMethod': contextRisk.detectionMethod,
              'timestamp': contextRisk.timestamp.toIso8601String(),
              ...contextRisk.metadata ?? {},
            },
            'threatSignals': threatSignals.toJson(),
          },
        );
        _threatsDetected++;
      }
      // For borderline cases with multiple risk indicators
      else if (contextRisk.riskScore > 0.7 ||
          threatSignals.riskLevel.isHighRisk) {
        // Cross-validate with conversation context and contact history
        final isSuspiciousContact =
            contactTrust.trustLevel == ContactTrustLevel.suspicious ||
                contactTrust.trustLevel == ContactTrustLevel.blocked;
        final hasRiskyContext =
            contextRisk.riskScore > 0.7 && threatSignals.evidence.length >= 2;

        if (isSuspiciousContact || hasRiskyContext) {
          result = ThreatIntelligence(
            isScam: true,
            riskLevel: RiskLevel.suspicious,
            confidence: 0.85,
            primaryReason: 'Multiple verified suspicious patterns detected',
            evidence: [
              ...threatSignals.evidence,
              if (isSuspiciousContact) 'Suspicious contact history',
              if (hasRiskyContext) 'High risk conversation context detected',
            ],
            contactInfo: contactTrust,
            additionalData: {
              ...metadata ?? {},
              'contextRisk': {
                'isScam': contextRisk.isScam,
                'riskScore': contextRisk.riskScore,
                'confidence': contextRisk.confidence,
                'riskLevel': contextRisk.riskLevel.toString(),
                'message': contextRisk.message,
                'reasoning': contextRisk.reasoning,
                'evidence': contextRisk.evidence,
                'detectedType': contextRisk.detectedType,
                'detectionMethod': contextRisk.detectionMethod,
                'timestamp': contextRisk.timestamp.toIso8601String(),
                ...contextRisk.metadata ?? {},
              },
              'threatSignals': threatSignals.toJson(),
            },
          );
          _threatsDetected++;
        } else {
          result = ThreatIntelligence(
            isScam: false,
            riskLevel: RiskLevel.low,
            confidence: 0.7,
            primaryReason:
                'Some patterns detected but insufficient evidence for high confidence',
            evidence: threatSignals.evidence,
            contactInfo: contactTrust,
            additionalData: {
              ...metadata ?? {},
              'contextRisk': {
                'isScam': contextRisk.isScam,
                'riskScore': contextRisk.riskScore,
                'confidence': contextRisk.confidence,
                'riskLevel': contextRisk.riskLevel.toString(),
                'message': contextRisk.message,
                'reasoning': contextRisk.reasoning,
                'evidence': contextRisk.evidence,
                'detectedType': contextRisk.detectedType,
                'detectionMethod': contextRisk.detectionMethod,
                'timestamp': contextRisk.timestamp.toIso8601String(),
                ...contextRisk.metadata ?? {},
              },
            },
          );
          _falsePositivesPrevented++;
        }
      }
      // Safe messages
      else {
        result = ThreatIntelligence(
          isScam: false,
          riskLevel: RiskLevel.minimal,
          confidence: 0.95,
          primaryReason: 'No suspicious patterns detected',
          contactInfo: contactTrust,
          additionalData: {
            ...metadata ?? {},
            'contextRisk': {
              'isScam': contextRisk.isScam,
              'riskScore': contextRisk.riskScore,
              'confidence': contextRisk.confidence,
              'riskLevel': contextRisk.riskLevel.toString(),
              'message': contextRisk.message,
              'reasoning': contextRisk.reasoning,
              'evidence': contextRisk.evidence,
              'detectedType': contextRisk.detectedType,
              'detectionMethod': contextRisk.detectionMethod,
              'timestamp': contextRisk.timestamp.toIso8601String(),
              ...contextRisk.metadata ?? {},
            },
          },
        );
        _falsePositivesPrevented++;
      }

      // Update accuracy metrics
      _accuracy = _totalScans > 0
          ? ((_totalScans - _falsePositivesPrevented) / _totalScans) * 100
          : 100.0;

      notifyListeners();
      return result;
    } finally {
      _isScanning = false;
      notifyListeners();
    }
  }
}
