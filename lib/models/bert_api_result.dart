// lib/models/bert_api_result.dart
class BertApiResult {
  final bool isScam;
  final double confidence;
  final String reason;
  final List<String> scamTypes;

  BertApiResult({
    required this.isScam,
    required this.confidence,
    required this.reason,
    required this.scamTypes,
  });

  factory BertApiResult.fromJson(Map<String, dynamic> json) {
    // Parse the new API response format
    double riskScore = (json['risk_score'] as num?)?.toDouble() ?? 0.0;
    String riskLevel = json['risk_level'] ?? 'MINIMAL RISK';
    String explanation = json['explanation'] ?? 'Unknown reason';

    // Convert risk score to confidence (inverse for display)
    double confidence =
        (json['confidence'] as num?)?.toDouble() ?? (1.0 - riskScore);

    // Determine if it's a scam based on risk level
    bool isScam = riskLevel.contains('HIGH') ||
        riskLevel.contains('CRITICAL') ||
        riskScore > 0.5;

    return BertApiResult(
      isScam: isScam,
      confidence: confidence,
      reason: explanation,
      scamTypes: _extractScamTypes(json),
    );
  }

  static List<String> _extractScamTypes(Map<String, dynamic> json) {
    List<String> types = [];

    // Extract scam types from risk factors or details
    if (json['details'] != null) {
      var details = json['details'];
      if (details['top_risk_factors'] != null) {
        types.addAll(List<String>.from(details['top_risk_factors']));
      }
    }

    // Add risk level as a type
    String riskLevel = json['risk_level'] ?? 'MINIMAL RISK';
    if (riskLevel != 'MINIMAL RISK') {
      types.add(riskLevel);
    }

    return types;
  }
}
