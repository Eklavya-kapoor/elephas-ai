import 'alert_types.dart';

/// Result of a scam detection analysis
class DetectionResult {
  /// Whether the analyzed content is likely a scam
  final bool isScam;

  /// Alias for isScam to maintain compatibility with legacy code
  bool get isThreat => isScam;

  /// Risk score from 0 to 1
  final double riskScore;

  /// Confidence level of the detection (0-1)
  final double confidence;

  /// Level of risk associated with the detection
  final RiskLevel riskLevel;

  /// Human-readable explanation of the detection
  final String message;

  /// Detailed reasoning for the detection
  final String reasoning;

  /// Evidence supporting the detection
  final Map<String, dynamic> evidence;

  /// Contact ID associated with this detection
  final String? contactId;

  /// Type of threat detected (e.g. "OTP Scam", "Investment Fraud", etc.)
  final String? detectedType;

  /// Method used for detection (e.g. "ML", "Pattern", "Heuristic", etc.)
  final String detectionMethod;

  /// When the detection occurred
  final DateTime timestamp;

  /// Additional metadata about the detection
  final Map<String, dynamic>? metadata;

  /// Type of threat, alias for detectedType to maintain compatibility
  String get threatType => detectedType ?? 'Unknown Threat';

  DetectionResult({
    required this.isScam,
    required this.riskScore,
    required this.confidence,
    required this.riskLevel,
    required this.reasoning,
    this.message = '',
    this.evidence = const {},
    this.contactId,
    this.detectedType,
    this.detectionMethod = 'Intelligent Analysis',
    DateTime? timestamp,
    this.metadata,
  }) : timestamp = timestamp ?? DateTime.now();

  /// Whether this result requires immediate user attention
  bool get requiresImmediate =>
      riskLevel == RiskLevel.critical ||
      (isScam && confidence >= 0.85); // Matches RiskLevel.critical threshold

  /// Whether this result should trigger an alert
  bool get shouldAlert =>
      riskLevel.index >= RiskLevel.high.index || // Anything high risk or above
      (isScam && confidence >= 0.7); // Matches RiskLevel.high threshold

  /// Create a detection result from backend API response
  factory DetectionResult.fromBackendResult(Map<String, dynamic> result) {
    return DetectionResult(
      isScam: result['isScam'] as bool? ?? false,
      riskScore: (result['riskScore'] as num?)?.toDouble() ?? 0.0,
      confidence: (result['confidence'] as num?)?.toDouble() ?? 0.0,
      riskLevel:
          RiskLevel.fromScore((result['riskScore'] as num?)?.toDouble() ?? 0.0),
      message: result['message'] as String? ?? 'Unknown risk',
      reasoning: result['reasoning'] as String? ?? '',
      evidence: result['evidence'] as Map<String, dynamic>? ?? {},
      contactId: result['contactId'] as String?,
    );
  }
}
