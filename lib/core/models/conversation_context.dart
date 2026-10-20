/// Results of conversation context analysis
class ConversationContext {
  final double riskScore;
  final double confidence;
  final String summary;
  final Map<String, dynamic>? details;

  const ConversationContext({
    required this.riskScore,
    required this.confidence,
    required this.summary,
    this.details,
  });

  Map<String, dynamic> toJson() => {
    'riskScore': riskScore,
    'confidence': confidence,
    'summary': summary,
    if (details != null) 'details': details,
  };
}
