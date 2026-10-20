/// Alert levels for user notifications and UI
enum AlertLevel {
  info('ℹ️', 'Information'),
  low('🟢', 'Low'),
  medium('🟡', 'Medium'),
  high('🟠', 'High'),
  critical('🚨', 'Critical');

  final String icon;
  final String label;
  const AlertLevel(this.icon, this.label);

  bool get requiresImmediate => this == AlertLevel.critical;
  bool get requiresAttention => index >= AlertLevel.high.index;
}

/// Risk levels for threat assessment
enum RiskLevel {
  minimal('✅', 'Minimal Risk', 0.0),
  low('🟢', 'Low Risk', 0.3),
  medium('🟡', 'Medium Risk', 0.5),
  high('🟠', 'High Risk', 0.7),
  critical('🚨', 'Critical Risk', 0.85);

  final String icon;
  final String description;
  final double threshold;
  const RiskLevel(this.icon, this.description, this.threshold);

  static RiskLevel fromScore(double score) {
    if (score >= RiskLevel.critical.threshold) return RiskLevel.critical;
    if (score >= RiskLevel.high.threshold) return RiskLevel.high;
    if (score >= RiskLevel.medium.threshold) return RiskLevel.medium;
    if (score >= RiskLevel.low.threshold) return RiskLevel.low;
    return RiskLevel.minimal;
  }

  AlertLevel toAlertLevel() {
    switch (this) {
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

/// Conversation context risk analysis result
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
      anomalies: const [],
      isPatternAnomaly: false,
      timeSinceLastMessage: Duration.zero,
    );
  }
}
