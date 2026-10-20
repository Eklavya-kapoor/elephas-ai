/// Enterprise-grade data models for zero false positive scam detection
/// Built with billion-dollar software standards
library detection_models;

import 'alert_types.dart';

/// Trust levels for contact assessment
enum TrustLevel {
  unknown,
  low,
  medium,
  high,
  verified,
}

/// Detection result representing the final decision
class DetectionResult {
  final bool isThreat;
  final double riskScore;
  final double confidence;
  final String reasoning;
  final String? contactId;
  final String? message;
  final String? detectedType;
  final String? detectionMethod;
  final Map<String, dynamic>? evidence;
  final Map<String, dynamic>? metadata;
  final DateTime timestamp;
  final RiskLevel riskLevel;
  final bool containsUrl;

  DetectionResult({
    required this.isThreat,
    required this.riskScore,
    required this.confidence,
    required this.reasoning,
    required this.riskLevel,
    this.contactId,
    this.message,
    this.detectedType,
    this.detectionMethod,
    this.evidence,
    this.metadata,
    this.containsUrl = false,
    DateTime? timestamp,
  })  : timestamp = timestamp ?? DateTime.now();

  /// Create a safe (non-threat) result
  factory DetectionResult.safe(String reasoning, {Map<String, dynamic>? metadata}) {
    return DetectionResult(
      isThreat: false,
      riskScore: 0.0,
      confidence: 1.0,
      reasoning: reasoning,
      detectionMethod: 'safe',
      riskLevel: RiskLevel.minimal,
      metadata: metadata ?? {'source': 'safe_check'},
    );
  }

  /// Create a threat result
  factory DetectionResult.threat({
    required String message,
    required String contactId,
    required double riskScore,
    required double confidence,
    required String reasoning,
    String? detectionMethod,
    Map<String, dynamic>? evidence,
    Map<String, dynamic>? metadata,
  }) {
    return DetectionResult(
      isThreat: true,
      riskScore: riskScore,
      confidence: confidence,
      reasoning: reasoning,
      contactId: contactId,
      message: message,
      detectionMethod: detectionMethod ?? 'ai_model',
      evidence: evidence,
      metadata: metadata ?? {'source': 'threat_detection'},
      riskLevel: _scoreToRiskLevel(riskScore),
    );
  }

  /// Create an error result
  factory DetectionResult.error(String error) {
    return DetectionResult(
      isThreat: false,
      riskScore: 0.0,
      confidence: 0.0,
      reasoning: 'Error: $error',
      detectionMethod: 'error',
      riskLevel: RiskLevel.minimal,
      metadata: {'error': error},
    );
  }

  /// Convert risk score to risk level
  static RiskLevel _scoreToRiskLevel(double score) {
    // Ensure score is within valid range
    final validScore = score.clamp(0.0, 1.0);

    // Map score ranges to risk levels
    if (validScore >= 0.8) return RiskLevel.critical;
    if (validScore >= 0.6) return RiskLevel.high;
    if (validScore >= 0.4) return RiskLevel.medium;
    if (validScore >= 0.2) return RiskLevel.low;
    return RiskLevel.minimal;
  }

  Map<String, dynamic> toJson() {
    return {
      'isThreat': isThreat,
      'riskScore': riskScore,
      'confidence': confidence,
      'reasoning': reasoning,
      'contactId': contactId,
      'message': message,
      'detectedType': detectedType,
      'detectionMethod': detectionMethod,
      'evidence': evidence,
      'metadata': metadata,
      'timestamp': timestamp.toIso8601String(),
      'riskLevel': riskLevel.toString(),
    };
  }

  /// Legacy compatibility getters
  bool get isScam => isThreat;
  String get reason => reasoning;
  AlertLevel get alertLevel => _riskToAlertLevel(riskLevel);
  List<String> get scamTypes =>
      evidence?['scamTypes']?.cast<String>() ?? ['unknown'];

  /// Whether this result requires an immediate alert
  bool get shouldAlert =>
      riskLevel.index >= RiskLevel.high.index || // Anything high risk or above
      (isThreat && confidence >= 0.7); // High confidence threats

  /// The type of threat, alias for detectedType for compatibility
  String get threatType => detectedType ?? 'Unknown Threat';

  /// True when the backend answered from its fast keyword-based fallback
  /// path instead of the real AI model (e.g. while the model is still
  /// loading after a cold start) - this verdict is much less reliable
  /// and callers should tell the user rather than presenting it as final.
  bool get isFallbackResult => metadata?['is_fallback'] == true;

  static AlertLevel _riskToAlertLevel(RiskLevel risk) {
    switch (risk) {
      case RiskLevel.critical:
        return AlertLevel.critical;
      case RiskLevel.high:
        return AlertLevel.high;
      case RiskLevel.medium:
        return AlertLevel.medium;
      case RiskLevel.low:
        return AlertLevel.low;
      case RiskLevel.minimal:
        return AlertLevel.info;
    }
  }
}

/// Legacy ScamDetectionResult model for backward compatibility
class ScamDetectionResult {
  final bool isScam;
  final String reason;
  final double confidence;
  final List<String> scamTypes;
  final AlertLevel alertLevel;
  final DateTime timestamp;

  ScamDetectionResult({
    required this.isScam,
    required this.reason,
    required this.confidence,
    required this.scamTypes,
    required this.alertLevel,
    DateTime? timestamp,
  }) : timestamp = timestamp ?? DateTime.now();

  factory ScamDetectionResult.fromDetectionResult(DetectionResult result) {
    return ScamDetectionResult(
      isScam: result.isScam,
      reason: result.reason,
      confidence: result.confidence,
      scamTypes: result.scamTypes,
      alertLevel: result.alertLevel,
      timestamp: result.timestamp,
    );
  }
}

/// Channel risk assessment for communication platforms
class ChannelRisk {
  final String appPackage;
  final RiskLevel riskLevel;
  final double riskScore;
  final String reasoning;
  final Map<String, dynamic>? metadata;

  ChannelRisk({
    required this.appPackage,
    required this.riskLevel,
    required this.riskScore,
    required this.reasoning,
    this.metadata,
  });

  Map<String, dynamic> toJson() {
    return {
      'appPackage': appPackage,
      'riskLevel': riskLevel.toString(),
      'riskScore': riskScore,
      'reasoning': reasoning,
      'metadata': metadata,
    };
  }
}

/// Contact trust assessment
class ContactTrust {
  final String contactId;
  final TrustLevel trustLevel;
  final double trustScore;
  final int interactionCount;
  final Duration relationshipDuration;
  final List<String> communicationPatterns;
  final DateTime lastInteraction;
  final bool isInPhonebook;
  final String? displayName;

  ContactTrust({
    required this.contactId,
    required this.trustLevel,
    required this.trustScore,
    required this.interactionCount,
    required this.relationshipDuration,
    required this.communicationPatterns,
    required this.lastInteraction,
    required this.isInPhonebook,
    this.displayName,
  });

  /// Create for unknown contact
  factory ContactTrust.unknown(String contactId) {
    return ContactTrust(
      contactId: contactId,
      trustLevel: TrustLevel.unknown,
      trustScore: 0.0,
      interactionCount: 0,
      relationshipDuration: Duration.zero,
      communicationPatterns: [],
      lastInteraction: DateTime.now(),
      isInPhonebook: false,
    );
  }

  /// Get trust level - alias for trustLevel
  TrustLevel get level => trustLevel;

  Map<String, dynamic> toJson() {
    return {
      'contactId': contactId,
      'trustLevel': trustLevel.toString(),
      'trustScore': trustScore,
      'interactionCount': interactionCount,
      'relationshipDuration': relationshipDuration.inDays,
      'communicationPatterns': communicationPatterns,
      'lastInteraction': lastInteraction.toIso8601String(),
      'isInPhonebook': isInPhonebook,
      'displayName': displayName,
    };
  }
}

/// Content risk analysis result
class ContentRisk {
  final String message;
  final double riskScore;
  final RiskLevel riskLevel;
  final List<String> detectedPatterns;
  final String reasoning;
  final Map<String, double>? patternScores;
  final List<String>? suspiciousElements;

  ContentRisk({
    required this.message,
    required this.riskScore,
    required this.riskLevel,
    required this.detectedPatterns,
    required this.reasoning,
    this.patternScores,
    this.suspiciousElements,
  });

  Map<String, dynamic> toJson() {
    return {
      'message': message,
      'riskScore': riskScore,
      'riskLevel': riskLevel.toString(),
      'detectedPatterns': detectedPatterns,
      'reasoning': reasoning,
      'patternScores': patternScores,
      'suspiciousElements': suspiciousElements,
    };
  }
}

/// Conversation context risk analysis
class ContextRisk {
  final double riskScore;
  final RiskLevel riskLevel;
  final String reasoning;
  final List<String> anomalies;
  final Map<String, dynamic>? conversationMetrics;
  final bool isPatternAnomaly;
  final Duration timeSinceLastMessage;

  ContextRisk({
    required this.riskScore,
    required this.riskLevel,
    required this.reasoning,
    required this.anomalies,
    this.conversationMetrics,
    required this.isPatternAnomaly,
    required this.timeSinceLastMessage,
  });

  /// Create for normal conversation
  factory ContextRisk.normal() {
    return ContextRisk(
      riskScore: 0.1,
      riskLevel: RiskLevel.minimal,
      reasoning: 'Normal conversation pattern',
      anomalies: [],
      isPatternAnomaly: false,
      timeSinceLastMessage: Duration.zero,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'riskScore': riskScore,
      'riskLevel': riskLevel.toString(),
      'reasoning': reasoning,
      'anomalies': anomalies,
      'conversationMetrics': conversationMetrics,
      'isPatternAnomaly': isPatternAnomaly,
      'timeSinceLastMessage': timeSinceLastMessage.inMilliseconds,
    };
  }
}

/// App monitoring configuration
class AppMonitoringConfig {
  final String packageName;
  final String displayName;
  final RiskLevel baseRiskLevel;
  final bool isEnabled;
  final Map<String, dynamic> monitoringRules;

  AppMonitoringConfig({
    required this.packageName,
    required this.displayName,
    required this.baseRiskLevel,
    required this.isEnabled,
    required this.monitoringRules,
  });

  Map<String, dynamic> toJson() {
    return {
      'packageName': packageName,
      'displayName': displayName,
      'baseRiskLevel': baseRiskLevel.toString(),
      'isEnabled': isEnabled,
      'monitoringRules': monitoringRules,
    };
  }
}

/// Alert configuration and metadata
class AlertConfig {
  final RiskLevel minimumLevel;
  final bool enableNotifications;
  final bool enableSound;
  final bool enableVibration;
  final Duration quietPeriod;
  final int maxAlertsPerHour;

  AlertConfig({
    required this.minimumLevel,
    required this.enableNotifications,
    required this.enableSound,
    required this.enableVibration,
    required this.quietPeriod,
    required this.maxAlertsPerHour,
  });

  /// Default conservative alert configuration
  factory AlertConfig.conservative() {
    return AlertConfig(
      minimumLevel: RiskLevel.high,
      enableNotifications: true,
      enableSound: true,
      enableVibration: true,
      quietPeriod: const Duration(minutes: 5),
      maxAlertsPerHour: 3,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'minimumLevel': minimumLevel.toString(),
      'enableNotifications': enableNotifications,
      'enableSound': enableSound,
      'enableVibration': enableVibration,
      'quietPeriod': quietPeriod.inMilliseconds,
      'maxAlertsPerHour': maxAlertsPerHour,
    };
  }
}
