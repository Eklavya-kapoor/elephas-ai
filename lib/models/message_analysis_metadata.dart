/// Metadata for message analysis
class MessageAnalysisMetadata {
  final String? messageType;
  final double contactTrust;
  final int contactHistory;
  final String conversationContext;
  
  MessageAnalysisMetadata({
    this.messageType,
    required this.contactTrust,
    required this.contactHistory,
    required this.conversationContext,
  });
  
  Map<String, dynamic> toMap() => {
    'messageType': messageType,
    'contactTrust': contactTrust,
    'contactHistory': contactHistory,
    'conversationContext': conversationContext,
  };
}
