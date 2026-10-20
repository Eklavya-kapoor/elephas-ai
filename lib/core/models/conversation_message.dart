/// Represents a message in conversation history
class ConversationMessage {
  final String content;
  final DateTime timestamp;
  final bool isFromContact;
  final String? metadata;

  ConversationMessage({
    required this.content,
    required this.timestamp,
    required this.isFromContact,
    this.metadata,
  });

  factory ConversationMessage.fromJson(Map<String, dynamic> json) {
    return ConversationMessage(
      content: json['content'] as String,
      timestamp: DateTime.parse(json['timestamp'] as String),
      isFromContact: json['isFromContact'] as bool? ?? true,
      metadata: json['metadata'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'content': content,
      'timestamp': timestamp.toIso8601String(),
      'isFromContact': isFromContact,
      'metadata': metadata,
    };
  }
}
