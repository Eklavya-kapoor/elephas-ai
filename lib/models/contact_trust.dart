/// Represents trust information about a contact
class ContactTrustInfo {
  final String contactId;
  final double trustScore;
  final int interactionCount;
  final DateTime lastInteraction;
  final String riskLevel;
  final Map<String, dynamic>? additionalData;

  ContactTrustInfo({
    required this.contactId,
    required this.trustScore,
    required this.interactionCount,
    required this.lastInteraction,
    required this.riskLevel,
    this.additionalData,
  });

  Map<String, dynamic> toJson() => {
    'contactId': contactId,
    'trustScore': trustScore,
    'interactionCount': interactionCount,
    'lastInteraction': lastInteraction.toIso8601String(),
    'riskLevel': riskLevel,
    'additionalData': additionalData,
  };

  bool get isHighTrust => trustScore >= 0.8 && interactionCount > 50;
  bool get isSuspicious => trustScore < 0.3 || riskLevel == 'high';
}
