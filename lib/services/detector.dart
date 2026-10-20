import 'contact_intelligence.dart';
import 'context_analyzer.dart';

/// Advanced detector that aims to minimize false positives
class ZeroFalsePositiveDetector {
  final ContactIntelligenceService _contactIntelligence;
  final ConversationContextAnalyzer _contextAnalyzer;

  ZeroFalsePositiveDetector(this._contactIntelligence, this._contextAnalyzer);

  Future<bool> shouldSuppressAlert(String contactId, String message) async {
    final insights = await _contactIntelligence.getRelationshipInsights(contactId);
    final context = await _contextAnalyzer.analyzeContext(message);

    // Implement logic to determine if alert should be suppressed
    return insights['relationshipScore'] > 0.9 && context['threatLevel']! < 0.5;
  }
}
