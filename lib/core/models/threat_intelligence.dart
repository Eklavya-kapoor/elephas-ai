import 'contact_trust.dart';

/// Risk level of a detected threat
enum RiskLevel {
  minimal('✅', 'Minimal Risk'),
  low('🟢', 'Low Risk'),
  medium('🟡', 'Medium Risk'),
  suspicious('⚠️', 'Suspicious'),
  high('🟠', 'High Risk'),
  critical('🚨', 'Critical Risk');

  bool get isHighRisk => this == high || this == critical;

  final String icon;
  final String description;
  const RiskLevel(this.icon, this.description);
}

/// Threat intelligence information
class ThreatIntelligence {
  final bool isScam;
  bool get isThreat => isScam;
  final RiskLevel riskLevel;
  final double confidence;
  final String primaryReason;
  final ContactTrustInfo contactInfo;
  final DateTime timestamp;
  final Map<String, dynamic>? additionalData;
  final double adjustedRisk;
  final List<String> scamTypes;
  final dynamic evidence;

  ThreatIntelligence({
    required this.isScam,
    required this.riskLevel,
    required this.confidence,
    required this.primaryReason,
    required this.contactInfo,
    DateTime? timestamp,
    this.additionalData,
    this.adjustedRisk = 0.0,
    this.scamTypes = const [],
    this.evidence,
  }) : timestamp = timestamp ?? DateTime.now();

  bool get requiresImmediate =>
      riskLevel == RiskLevel.critical && confidence > 0.85;
}
