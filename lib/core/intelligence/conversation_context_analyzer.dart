import 'dart:async';
import 'dart:convert';
import 'dart:developer' as developer;
import 'dart:math' as math;
import '../models/alert_types.dart';
import '../models/conversation_message.dart';

/// Enterprise-grade conversation context analyzer
/// Detects behavioral anomalies and conversation pattern changes
class ConversationContextAnalyzer {
  static const String _logTag = 'ContextAnalyzer';

  /// Analyze a single message for risk indicators
  Future<ContextRisk> analyzeMessage({
    required String message,
    required String contactId,
  }) async {
    return analyzeConversationContext(
      message: message,
      contactId: contactId,
    );
  }

  // Context analysis thresholds
  static const double _normalConversationFlowThreshold = 0.3;
  static const double _suspiciousTopicShiftThreshold = 0.7;
  static const double _urgencyEscalationThreshold = 0.8;
  static const int _maxHistoryMessages = 20;

  // Conversation pattern recognition
  final Map<String, double> _topicShiftIndicators = {
    // Sudden shift to financial topics
    r'(money|payment|bank|account|transfer)': 0.8,
    r'(urgent.*money|need.*cash|financial.*help)': 0.9,
    r'(otp|pin|password|cvv)': 0.95,

    // Investment/opportunity shifts
    r'(investment|business|opportunity|profit)': 0.7,
    r'(bitcoin|crypto|trading|forex)': 0.8,
    r'(guaranteed.*return|risk.*free)': 0.9,

    // Emergency/help shifts
    r'(emergency|help.*me|stuck|problem)': 0.6,
    r'(hospital|accident|police)': 0.8,
    r'(customs|airport|immigration)': 0.9,
  };

  final Map<String, double> _urgencyIndicators = {
    r'(urgent|immediately|asap|quickly|hurry)': 0.5,
    r'(expire|deadline|last.*chance|limited.*time)': 0.7,
    r'(right.*now|today.*only|few.*minutes)': 0.8,
    r'(before.*it.*too.*late|only.*way|must.*act)': 0.9,
  };

  /// Analyze conversation context for behavioral anomalies
  Future<ContextRisk> analyzeConversationContext({
    required String message,
    required String contactId,
    String? history,
  }) async {
    try {
      developer.log(
          'Analyzing conversation context for contact: ${contactId.substring(0, 8)}...',
          name: _logTag);

      // Parse conversation history
      final conversationMessages = _parseConversationHistory(history);

      // Analyze various context dimensions
      final topicShiftRisk = _analyzeTopicShift(message, conversationMessages);
      final urgencyEscalationRisk =
          _analyzeUrgencyEscalation(message, conversationMessages);
      final conversationFlowRisk =
          _analyzeConversationFlow(message, conversationMessages);
      final behavioralAnomalyRisk =
          _analyzeBehavioralAnomalies(message, conversationMessages);

      // Combine risk factors
      final compositeRisk = _calculateCompositeContextRisk(
        topicShiftRisk: topicShiftRisk,
        urgencyRisk: urgencyEscalationRisk,
        flowRisk: conversationFlowRisk,
        behavioralRisk: behavioralAnomalyRisk,
      );

      // Build anomaly list
      final anomalies = _collectAnomalies(
        topicShiftRisk,
        urgencyEscalationRisk,
        conversationFlowRisk,
        behavioralAnomalyRisk,
      );

      final riskLevel = _scoreToRiskLevel(compositeRisk);
      final reasoning = _buildContextReasoning(
        compositeRisk,
        anomalies,
        conversationMessages.length,
      );

      developer.log('Context analysis complete - Risk: $riskLevel',
          name: _logTag);

      return ContextRisk(
        riskScore: compositeRisk,
        riskLevel: riskLevel,
        reasoning: reasoning,
        anomalies: anomalies,
        isPatternAnomaly: anomalies.isNotEmpty,
        timeSinceLastMessage:
            _calculateTimeSinceLastMessage(conversationMessages),
        conversationMetrics: {
          'topic_shift_risk': topicShiftRisk,
          'urgency_escalation_risk': urgencyEscalationRisk,
          'conversation_flow_risk': conversationFlowRisk,
          'behavioral_anomaly_risk': behavioralAnomalyRisk,
          'message_count': conversationMessages.length,
        },
      );
    } catch (e, stackTrace) {
      developer.log('Error in context analysis: $e',
          name: _logTag, error: e, stackTrace: stackTrace);
      return ContextRisk.normal();
    }
  }

  /// Parse conversation history into structured messages
  List<ConversationMessage> _parseConversationHistory(String? history) {
    if (history == null || history.isEmpty) {
      return [];
    }

    try {
      // Expected format: JSON array of message objects
      final List<dynamic> historyData = jsonDecode(history);
      return historyData
          .take(_maxHistoryMessages)
          .map((data) =>
              ConversationMessage.fromJson(data as Map<String, dynamic>))
          .toList();
    } catch (e) {
      // Fallback: treat as simple text with line breaks
      final lines = history
          .split('\n')
          .where((line) => line.trim().isNotEmpty)
          .take(_maxHistoryMessages)
          .toList();

      return lines.asMap().entries.map((entry) {
        return ConversationMessage(
          content: entry.value,
          timestamp: DateTime.now().subtract(Duration(minutes: entry.key * 5)),
          isFromContact: entry.key % 2 == 0, // Alternate sender
        );
      }).toList();
    }
  }

  /// Analyze sudden topic shifts (major scam indicator)
  double _analyzeTopicShift(
      String currentMessage, List<ConversationMessage> history) {
    if (history.isEmpty) return 0.1; // No history = minimal risk

    final currentTopics = _extractTopics(currentMessage);
    final recentTopics = history
        .take(5)
        .map((msg) => _extractTopics(msg.content))
        .expand((topics) => topics)
        .toSet();

    // Check for sudden financial topic introduction
    double topicShiftRisk = 0.0;

    for (final topic in currentTopics) {
      // High-risk topic shift indicators
      for (final entry in _topicShiftIndicators.entries) {
        final pattern = RegExp(entry.key, caseSensitive: false);
        if (pattern.hasMatch(topic)) {
          // Higher risk if this topic wasn't in recent conversation
          if (!recentTopics
              .any((recentTopic) => pattern.hasMatch(recentTopic))) {
            topicShiftRisk = math.max(topicShiftRisk, entry.value);
          } else {
            // Lower risk if topic was already being discussed
            topicShiftRisk = math.max(topicShiftRisk, entry.value * 0.3);
          }
        }
      }
    }

    return topicShiftRisk;
  }

  /// Analyze urgency escalation patterns
  double _analyzeUrgencyEscalation(
      String currentMessage, List<ConversationMessage> history) {
    final currentUrgency = _measureUrgencyLevel(currentMessage);

    if (history.isEmpty) {
      return currentUrgency > 0.5 ? currentUrgency * 0.8 : 0.1;
    }

    // Calculate urgency trend
    final recentUrgencyLevels = history
        .take(3)
        .map((msg) => _measureUrgencyLevel(msg.content))
        .toList();

    if (recentUrgencyLevels.isEmpty) return currentUrgency * 0.8;

    final avgRecentUrgency = recentUrgencyLevels.reduce((a, b) => a + b) /
        recentUrgencyLevels.length;

    // Escalation detected if current urgency significantly higher
    final escalation = currentUrgency - avgRecentUrgency;

    if (escalation > 0.3 && currentUrgency > 0.6) {
      return math.min(1.0, currentUrgency + escalation);
    }

    return currentUrgency * 0.7; // Regular urgency, less concerning
  }

  /// Analyze conversation flow naturalness
  double _analyzeConversationFlow(
      String currentMessage, List<ConversationMessage> history) {
    if (history.isEmpty) return 0.1;

    double flowRisk = 0.0;

    // Check for unnatural conversation gaps
    final lastMessage = history.first;
    final timeSinceLastMessage =
        DateTime.now().difference(lastMessage.timestamp);

    if (timeSinceLastMessage.inDays > 30) {
      flowRisk += 0.4; // Long gap, then sudden contact
    } else if (timeSinceLastMessage.inHours > 24) {
      flowRisk += 0.2; // Medium gap
    }

    // Check for response relevance
    final relevanceScore =
        _calculateResponseRelevance(currentMessage, lastMessage.content);
    if (relevanceScore < 0.3) {
      flowRisk += 0.5; // Highly irrelevant response
    }

    // Check for conversation length vs urgency mismatch
    if (history.length < 5 && _measureUrgencyLevel(currentMessage) > 0.7) {
      flowRisk += 0.6; // Very urgent request from brief conversation
    }

    return math.min(1.0, flowRisk);
  }

  /// Analyze behavioral anomalies
  double _analyzeBehavioralAnomalies(
      String currentMessage, List<ConversationMessage> history) {
    if (history.length < 3) return 0.1; // Need history for behavioral analysis

    double anomalyRisk = 0.0;

    // Analyze language pattern changes
    final currentLanguageStyle = _analyzeLanguageStyle(currentMessage);
    final historicalLanguageStyles = history
        .take(5)
        .map((msg) => _analyzeLanguageStyle(msg.content))
        .toList();

    // Check for sudden formality changes
    final avgHistoricalFormality = historicalLanguageStyles
            .map((style) => style['formality'] as double)
            .reduce((a, b) => a + b) /
        historicalLanguageStyles.length;

    final formalityChange =
        (currentLanguageStyle['formality'] as double) - avgHistoricalFormality;

    if (formalityChange.abs() > 0.5) {
      anomalyRisk += 0.4; // Significant style change
    }

    // Check for grammar/spelling pattern changes
    final currentGrammarScore = currentLanguageStyle['grammar_score'] as double;
    final avgHistoricalGrammar = historicalLanguageStyles
            .map((style) => style['grammar_score'] as double)
            .reduce((a, b) => a + b) /
        historicalLanguageStyles.length;

    final grammarChange = (currentGrammarScore - avgHistoricalGrammar).abs();
    if (grammarChange > 0.3) {
      anomalyRisk += 0.3; // Grammar pattern change
    }

    return math.min(1.0, anomalyRisk);
  }

  /// Extract topics from message content
  List<String> _extractTopics(String message) {
    final normalized = message.toLowerCase();
    final topics = <String>[];

    // Financial topics
    if (RegExp(r'\b(money|payment|bank|account|transfer|upi|pay)\b')
        .hasMatch(normalized)) {
      topics.add('financial');
    }

    // Investment topics
    if (RegExp(r'\b(investment|business|profit|return|trading)\b')
        .hasMatch(normalized)) {
      topics.add('investment');
    }

    // Emergency topics
    if (RegExp(r'\b(emergency|help|problem|stuck|urgent)\b')
        .hasMatch(normalized)) {
      topics.add('emergency');
    }

    // Personal topics
    if (RegExp(r'\b(family|friend|personal|love|relationship)\b')
        .hasMatch(normalized)) {
      topics.add('personal');
    }

    // Work topics
    if (RegExp(r'\b(work|office|job|meeting|project)\b').hasMatch(normalized)) {
      topics.add('work');
    }

    return topics.isEmpty ? ['general'] : topics;
  }

  /// Measure urgency level in message
  double _measureUrgencyLevel(String message) {
    final normalized = message.toLowerCase();
    double urgencyScore = 0.0;

    for (final entry in _urgencyIndicators.entries) {
      final pattern = RegExp(entry.key, caseSensitive: false);
      if (pattern.hasMatch(normalized)) {
        urgencyScore = math.max(urgencyScore, entry.value);
      }
    }

    // Additional urgency indicators
    final urgentWordCount =
        RegExp(r'\b(urgent|emergency|asap|quickly|immediately|now)\b')
            .allMatches(normalized)
            .length;
    urgencyScore += urgentWordCount * 0.1;

    // Punctuation-based urgency (excessive exclamation marks)
    final exclamationCount = '!'.allMatches(message).length;
    if (exclamationCount > 2) {
      urgencyScore += 0.2;
    }

    return math.min(1.0, urgencyScore);
  }

  /// Calculate response relevance to previous message
  double _calculateResponseRelevance(
      String currentMessage, String previousMessage) {
    final currentWords = currentMessage.toLowerCase().split(RegExp(r'\s+'));
    final previousWords = previousMessage.toLowerCase().split(RegExp(r'\s+'));

    // Simple word overlap calculation
    final commonWords =
        currentWords.toSet().intersection(previousWords.toSet());

    if (currentWords.isEmpty || previousWords.isEmpty) return 0.5;

    final relevanceScore = commonWords.length /
        math.max(currentWords.length, previousWords.length);

    return relevanceScore.clamp(0.0, 1.0);
  }

  /// Analyze language style characteristics
  Map<String, double> _analyzeLanguageStyle(String message) {
    final normalized = message.toLowerCase();

    // Formality score (0 = very informal, 1 = very formal)
    double formalityScore = 0.5; // Base score

    // Formal indicators
    if (RegExp(r'\b(please|thank you|regards|sincerely)\b')
        .hasMatch(normalized)) {
      formalityScore += 0.2;
    }
    if (RegExp(r'\b(sir|madam|dear|mr|mrs)\b').hasMatch(normalized)) {
      formalityScore += 0.3;
    }

    // Informal indicators
    if (RegExp(r'\b(hey|yo|sup|lol|omg)\b').hasMatch(normalized)) {
      formalityScore -= 0.2;
    }
    if (RegExp(r'[\u{1F600}-\u{1F64F}]', unicode: true).hasMatch(message)) {
      // Emojis
      formalityScore -= 0.1;
    }

    // Grammar score (simple heuristic)
    double grammarScore = 0.8; // Base score

    // Poor grammar indicators
    final sentenceCount = message.split(RegExp(r'[.!?]')).length - 1;
    final capitalizedSentences =
        RegExp(r'[.!?]\s*[A-Z]').allMatches(message).length;

    if (sentenceCount > 0) {
      grammarScore = capitalizedSentences / sentenceCount;
    }

    return {
      'formality': formalityScore.clamp(0.0, 1.0),
      'grammar_score': grammarScore.clamp(0.0, 1.0),
    };
  }

  /// Calculate composite context risk
  double _calculateCompositeContextRisk({
    required double topicShiftRisk,
    required double urgencyRisk,
    required double flowRisk,
    required double behavioralRisk,
  }) {
    // Weighted combination of risk factors
    const topicWeight = 0.4; // Topic shifts are highly indicative
    const urgencyWeight = 0.3; // Urgency escalation is important
    const flowWeight = 0.2; // Flow disruption matters
    const behavioralWeight = 0.1; // Behavioral changes are subtle

    return (topicShiftRisk * topicWeight) +
        (urgencyRisk * urgencyWeight) +
        (flowRisk * flowWeight) +
        (behavioralRisk * behavioralWeight);
  }

  /// Collect detected anomalies
  List<String> _collectAnomalies(
    double topicShiftRisk,
    double urgencyRisk,
    double flowRisk,
    double behavioralRisk,
  ) {
    final anomalies = <String>[];

    if (topicShiftRisk > _suspiciousTopicShiftThreshold) {
      anomalies.add('Sudden topic shift to high-risk subject');
    }

    if (urgencyRisk > _urgencyEscalationThreshold) {
      anomalies.add('Urgency escalation detected');
    }

    if (flowRisk > _normalConversationFlowThreshold) {
      anomalies.add('Unnatural conversation flow');
    }

    if (behavioralRisk > 0.5) {
      anomalies.add('Behavioral pattern change');
    }

    return anomalies;
  }

  /// Calculate time since last message
  Duration _calculateTimeSinceLastMessage(List<ConversationMessage> history) {
    if (history.isEmpty) return Duration.zero;

    return DateTime.now().difference(history.first.timestamp);
  }

  /// Convert risk score to risk level
  RiskLevel _scoreToRiskLevel(double score) {
    if (score >= 0.8) return RiskLevel.critical;
    if (score >= 0.6) return RiskLevel.high;
    if (score >= 0.4) return RiskLevel.medium;
    if (score >= 0.2) return RiskLevel.low;
    return RiskLevel.minimal;
  }

  /// Build context reasoning
  String _buildContextReasoning(
      double riskScore, List<String> anomalies, int historyLength) {
    if (anomalies.isEmpty) {
      return 'Normal conversation pattern';
    }

    if (riskScore >= 0.8) {
      return 'Multiple conversation anomalies detected: ${anomalies.join(', ')}';
    } else if (riskScore >= 0.5) {
      return 'Suspicious conversation pattern: ${anomalies.first}';
    } else {
      return 'Minor conversation irregularities observed';
    }
  }
}
