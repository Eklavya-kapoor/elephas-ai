// lib/models/scam_detection_models.dart

import 'package:elephas_ai/models/alert_level.dart';

/// Represents the result of a scam detection analysis
class ScamDetectionResult {
  final bool isScam;
  final double confidence;
  final String reason;
  final AlertLevel alertLevel;
  final List<String> scamTypes;

  ScamDetectionResult({
    required this.isScam,
    required this.confidence,
    required this.reason,
    required this.alertLevel,
    this.scamTypes = const [],
  });
}

/// Result from quick keyword-based pre-scanning
class QuickCheckResult {
  final bool isPotentialScam;
  final String reason;

  QuickCheckResult({
    required this.isPotentialScam,
    required this.reason,
  });
}

/// Result from BERT API analysis
class BertApiResult {
  final double confidence;
  final String reason;
  final List<String> scamTypes;

  BertApiResult({
    required this.confidence,
    required this.reason,
    required this.scamTypes,
  });
}
