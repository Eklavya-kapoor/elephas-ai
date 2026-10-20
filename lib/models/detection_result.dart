/// Result of a scam detection analysis
class DetectionResult {
  final String message;
  final bool isScam;
  final double confidence;
  final String reason;
  final String? detectedType;
  final Map<String, dynamic>? additionalData;
  final DateTime timestamp;

  DetectionResult({
    required this.message,
    required this.isScam,
    required this.confidence,
    required this.reason,
    this.detectedType,
    this.additionalData,
    DateTime? timestamp,
  }) : timestamp = timestamp ?? DateTime.now();

  factory DetectionResult.fromJson(Map<String, dynamic> json) {
    return DetectionResult(
      message: json['message'] as String,
      isScam: json['is_scam'] as bool,
      confidence: (json['confidence'] as num).toDouble(),
      reason: json['reason'] as String,
      detectedType: json['detected_type'] as String?,
      additionalData: json['additional_data'] as Map<String, dynamic>?,
      timestamp: DateTime.parse(json['timestamp'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'message': message,
      'is_scam': isScam,
      'confidence': confidence,
      'reason': reason,
      'detected_type': detectedType,
      'additional_data': additionalData,
      'timestamp': timestamp.toIso8601String(),
    };
  }

  @override
  String toString() {
    return 'DetectionResult(isScam: $isScam, confidence: $confidence, reason: $reason)';
  }
}
