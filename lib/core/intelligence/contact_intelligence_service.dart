import 'dart:async';
import 'dart:convert';
import 'dart:developer' as developer;
import 'package:shared_preferences/shared_preferences.dart';
import '../models/detection_models.dart';

/// Enterprise-grade contact intelligence service
/// Builds deep relationship understanding for zero false positives
class ContactIntelligenceService {
  static const String _logTag = 'ContactIntelligence';
  static const String _storagePrefix = 'contact_intelligence_';
  
  // Intelligence thresholds
  static const int _trustedContactMinInteractions = 50;

  /// Get a trust score for a contact (0.0 to 1.0)
  Future<double> getTrustScore(String contactId) async {
    final trust = await evaluateContactTrust(contactId);
    return trust.trustScore;
  }
  static const int _verifiedContactMinInteractions = 200;
  static const Duration _longTermRelationshipThreshold = Duration(days: 90);
  static const Duration _activeRelationshipThreshold = Duration(days: 7);
  
  late SharedPreferences _prefs;
  final Map<String, ContactTrust> _contactCache = {};
  bool _initialized = false;

  /// Initialize the contact intelligence service
  Future<void> initialize() async {
    if (_initialized) return;

    try {
      _prefs = await SharedPreferences.getInstance();
      await _loadContactCache();
      _initialized = true;
      developer.log('Contact Intelligence Service initialized', name: _logTag);
    } catch (e) {
      developer.log('Failed to initialize Contact Intelligence: $e', 
                   name: _logTag, error: e);
      rethrow;
    }
  }

  /// Evaluate trust level for a contact with comprehensive analysis
  Future<ContactTrust> evaluateContactTrust(String contactId) async {
    await _ensureInitialized();

    try {
      // Check cache first
      if (_contactCache.containsKey(contactId)) {
        final cached = _contactCache[contactId]!;
        // Refresh if data is old
        if (DateTime.now().difference(cached.lastInteraction).inDays > 1) {
          return await _refreshContactTrust(contactId);
        }
        return cached;
      }

      // Load from storage or create new
      return await _loadOrCreateContactTrust(contactId);

    } catch (e) {
      developer.log('Error evaluating contact trust for $contactId: $e', 
                   name: _logTag, error: e);
      return ContactTrust.unknown(contactId);
    }
  }

  /// Record a new interaction with a contact
  Future<void> recordInteraction({
    required String contactId,
    required String message,
    required String appPackage,
    required DateTime timestamp,
    String? displayName,
  }) async {
    await _ensureInitialized();

    try {
      final existing = await evaluateContactTrust(contactId);
      
      // Update interaction metrics
      final updatedTrust = _updateContactMetrics(
        existing: existing,
        message: message,
        appPackage: appPackage,
        timestamp: timestamp,
        displayName: displayName,
      );

      // Cache and persist
      _contactCache[contactId] = updatedTrust;
      await _persistContactTrust(updatedTrust);

      developer.log('Recorded interaction for contact: ${contactId.substring(0, 8)}...', 
                   name: _logTag);

    } catch (e) {
      developer.log('Error recording interaction for $contactId: $e', 
                   name: _logTag, error: e);
    }
  }

  /// Get relationship insights for a contact
  Future<Map<String, dynamic>> getRelationshipInsights(String contactId) async {
    await _ensureInitialized();

    final trust = await evaluateContactTrust(contactId);
    
    return {
      'relationship_strength': _calculateRelationshipStrength(trust),
      'communication_frequency': _calculateCommunicationFrequency(trust),
      'consistency_score': _calculateConsistencyScore(trust),
      'trust_evolution': await _getTrustEvolution(contactId),
      'risk_factors': _identifyRiskFactors(trust),
      'protective_factors': _identifyProtectiveFactors(trust),
    };
  }

  /// Load contact cache from persistent storage
  Future<void> _loadContactCache() async {
    try {
      final keys = _prefs.getKeys()
          .where((key) => key.startsWith(_storagePrefix))
          .toList();

      for (final key in keys) {
        final jsonStr = _prefs.getString(key);
        if (jsonStr != null) {
          final data = jsonDecode(jsonStr) as Map<String, dynamic>;
          final contactId = key.substring(_storagePrefix.length);
          _contactCache[contactId] = _deserializeContactTrust(data, contactId);
        }
      }

      developer.log('Loaded ${_contactCache.length} contacts from cache', name: _logTag);
    } catch (e) {
      developer.log('Error loading contact cache: $e', name: _logTag, error: e);
    }
  }

  /// Load or create contact trust data
  Future<ContactTrust> _loadOrCreateContactTrust(String contactId) async {
    final key = '$_storagePrefix$contactId';
    final jsonStr = _prefs.getString(key);

    if (jsonStr != null) {
      try {
        final data = jsonDecode(jsonStr) as Map<String, dynamic>;
        final trust = _deserializeContactTrust(data, contactId);
        _contactCache[contactId] = trust;
        return trust;
      } catch (e) {
        developer.log('Error deserializing contact data for $contactId: $e', 
                     name: _logTag, error: e);
      }
    }

    // Create new contact trust record
    final newTrust = ContactTrust.unknown(contactId);
    _contactCache[contactId] = newTrust;
    await _persistContactTrust(newTrust);
    return newTrust;
  }

  /// Refresh contact trust data with updated analysis
  Future<ContactTrust> _refreshContactTrust(String contactId) async {
    final existing = _contactCache[contactId];
    if (existing == null) {
      return await _loadOrCreateContactTrust(contactId);
    }

    // Recalculate trust metrics
    final refreshed = _recalculateTrustMetrics(existing);
    _contactCache[contactId] = refreshed;
    await _persistContactTrust(refreshed);
    
    return refreshed;
  }

  /// Update contact metrics with new interaction
  ContactTrust _updateContactMetrics({
    required ContactTrust existing,
    required String message,
    required String appPackage,
    required DateTime timestamp,
    String? displayName,
  }) {
    // Update interaction count and patterns
    final newInteractionCount = existing.interactionCount + 1;
    final newPatterns = List<String>.from(existing.communicationPatterns);
    
    // Analyze message pattern
    final messagePattern = _analyzeMessagePattern(message, appPackage);
    if (messagePattern.isNotEmpty && !newPatterns.contains(messagePattern)) {
      newPatterns.add(messagePattern);
      // Keep only recent patterns (last 20)
      if (newPatterns.length > 20) {
        newPatterns.removeAt(0);
      }
    }

    // Calculate relationship duration
    final relationshipStart = timestamp.subtract(
      Duration(days: newInteractionCount * 2), // Estimate
    );
    final relationshipDuration = timestamp.difference(relationshipStart);

    // Determine trust level and score
    final trustLevel = _calculateTrustLevel(
      interactionCount: newInteractionCount,
      relationshipDuration: relationshipDuration,
      isInPhonebook: existing.isInPhonebook,
      patterns: newPatterns,
    );

    final trustScore = _calculateTrustScore(
      interactionCount: newInteractionCount,
      relationshipDuration: relationshipDuration,
      trustLevel: trustLevel,
    );

    return ContactTrust(
      contactId: existing.contactId,
      trustLevel: trustLevel,
      trustScore: trustScore,
      interactionCount: newInteractionCount,
      relationshipDuration: relationshipDuration,
      communicationPatterns: newPatterns,
      lastInteraction: timestamp,
      isInPhonebook: existing.isInPhonebook,
      displayName: displayName ?? existing.displayName,
    );
  }

  /// Analyze message pattern for behavioral profiling
  String _analyzeMessagePattern(String message, String appPackage) {
    final normalized = message.toLowerCase().trim();
    
    // Identify communication patterns
    if (normalized.length < 10) return 'short_message';
    if (normalized.contains(RegExp(r'[\u{1F600}-\u{1F64F}]', unicode: true))) return 'emoji_user';
    if (normalized.contains('good morning') || normalized.contains('good night')) {
      return 'courteous_communication';
    }
    if (normalized.contains(RegExp(r'\b(work|office|meeting|project)\b'))) {
      return 'professional_communication';
    }
    if (normalized.contains(RegExp(r'\b(family|mom|dad|sister|brother)\b'))) {
      return 'family_communication';
    }
    
    return 'general_communication';
  }

  /// Calculate trust level based on interaction history
  TrustLevel _calculateTrustLevel({
    required int interactionCount,
    required Duration relationshipDuration,
    required bool isInPhonebook,
    required List<String> patterns,
  }) {
    // Phone book contacts get initial trust boost
    int trustPoints = isInPhonebook ? 2 : 0;
    
    // Interaction count scoring
    if (interactionCount >= _verifiedContactMinInteractions) {
      trustPoints += 3;
    } else if (interactionCount >= _trustedContactMinInteractions) {
      trustPoints += 2;
    } else if (interactionCount >= 10) {
      trustPoints += 1;
    }
    
    // Relationship duration scoring
    if (relationshipDuration >= _longTermRelationshipThreshold) {
      trustPoints += 2;
    } else if (relationshipDuration >= const Duration(days: 30)) {
      trustPoints += 1;
    }
    
    // Communication pattern diversity (indicates genuine relationship)
    if (patterns.length >= 5) {
      trustPoints += 1;
    }
    
    // Recent activity (shows active relationship)
    if (relationshipDuration <= _activeRelationshipThreshold) {
      trustPoints += 1;
    }

    // Convert points to trust level
    if (trustPoints >= 7) return TrustLevel.verified;
    if (trustPoints >= 5) return TrustLevel.high;
    if (trustPoints >= 3) return TrustLevel.medium;
    if (trustPoints >= 1) return TrustLevel.low;
    return TrustLevel.unknown;
  }

  /// Calculate numerical trust score
  double _calculateTrustScore({
    required int interactionCount,
    required Duration relationshipDuration,
    required TrustLevel trustLevel,
  }) {
    double score = 0.0;
    
    // Base score from trust level
    switch (trustLevel) {
      case TrustLevel.verified:
        score = 0.95;
        break;
      case TrustLevel.high:
        score = 0.80;
        break;
      case TrustLevel.medium:
        score = 0.60;
        break;
      case TrustLevel.low:
        score = 0.30;
        break;
      case TrustLevel.unknown:
        score = 0.05;
        break;
    }
    
    // Boost for very active relationships
    if (interactionCount > 500) {
      score = (score * 1.1).clamp(0.0, 1.0);
    }
    
    // Boost for very long relationships
    if (relationshipDuration.inDays > 365) {
      score = (score * 1.05).clamp(0.0, 1.0);
    }
    
    return score;
  }

  /// Recalculate trust metrics (for refresh operations)
  ContactTrust _recalculateTrustMetrics(ContactTrust existing) {
    final trustLevel = _calculateTrustLevel(
      interactionCount: existing.interactionCount,
      relationshipDuration: existing.relationshipDuration,
      isInPhonebook: existing.isInPhonebook,
      patterns: existing.communicationPatterns,
    );

    final trustScore = _calculateTrustScore(
      interactionCount: existing.interactionCount,
      relationshipDuration: existing.relationshipDuration,
      trustLevel: trustLevel,
    );

    return ContactTrust(
      contactId: existing.contactId,
      trustLevel: trustLevel,
      trustScore: trustScore,
      interactionCount: existing.interactionCount,
      relationshipDuration: existing.relationshipDuration,
      communicationPatterns: existing.communicationPatterns,
      lastInteraction: existing.lastInteraction,
      isInPhonebook: existing.isInPhonebook,
      displayName: existing.displayName,
    );
  }

  /// Calculate relationship strength metrics
  double _calculateRelationshipStrength(ContactTrust trust) {
    final interactionWeight = (trust.interactionCount / 100.0).clamp(0.0, 1.0);
    final durationWeight = (trust.relationshipDuration.inDays / 365.0).clamp(0.0, 1.0);
    final patternWeight = (trust.communicationPatterns.length / 10.0).clamp(0.0, 1.0);
    
    return (interactionWeight * 0.4 + durationWeight * 0.4 + patternWeight * 0.2);
  }

  /// Calculate communication frequency
  double _calculateCommunicationFrequency(ContactTrust trust) {
    if (trust.relationshipDuration.inDays == 0) return 0.0;
    
    final messagesPerDay = trust.interactionCount / trust.relationshipDuration.inDays;
    return (messagesPerDay / 10.0).clamp(0.0, 1.0); // Normalize to 0-1
  }

  /// Calculate consistency score
  double _calculateConsistencyScore(ContactTrust trust) {
    // More patterns indicate consistent, varied communication
    return (trust.communicationPatterns.length / 15.0).clamp(0.0, 1.0);
  }

  /// Get trust evolution over time
  Future<List<Map<String, dynamic>>> _getTrustEvolution(String contactId) async {
    // This would require historical data storage
    // For now, return current state
    final trust = await evaluateContactTrust(contactId);
    return [
      {
        'timestamp': trust.lastInteraction.toIso8601String(),
        'trust_score': trust.trustScore,
        'trust_level': trust.trustLevel.toString(),
      }
    ];
  }

  /// Identify risk factors for this contact
  List<String> _identifyRiskFactors(ContactTrust trust) {
    final risks = <String>[];
    
    if (trust.trustLevel == TrustLevel.unknown) {
      risks.add('Unknown contact');
    }
    
    if (trust.interactionCount == 0) {
      risks.add('No interaction history');
    }
    
    if (!trust.isInPhonebook) {
      risks.add('Not in phone contacts');
    }
    
    if (trust.relationshipDuration.inDays < 7) {
      risks.add('Very new relationship');
    }
    
    return risks;
  }

  /// Identify protective factors for this contact
  List<String> _identifyProtectiveFactors(ContactTrust trust) {
    final protective = <String>[];
    
    if (trust.isInPhonebook) {
      protective.add('In phone contacts');
    }
    
    if (trust.interactionCount >= _trustedContactMinInteractions) {
      protective.add('Extensive interaction history');
    }
    
    if (trust.relationshipDuration >= _longTermRelationshipThreshold) {
      protective.add('Long-term relationship');
    }
    
    if (trust.communicationPatterns.contains('family_communication')) {
      protective.add('Family communication patterns');
    }
    
    if (trust.communicationPatterns.contains('professional_communication')) {
      protective.add('Professional communication patterns');
    }
    
    return protective;
  }

  /// Persist contact trust data
  Future<void> _persistContactTrust(ContactTrust trust) async {
    try {
      final key = '$_storagePrefix${trust.contactId}';
      final jsonStr = jsonEncode(_serializeContactTrust(trust));
      await _prefs.setString(key, jsonStr);
    } catch (e) {
      developer.log('Error persisting contact trust: $e', name: _logTag, error: e);
    }
  }

  /// Serialize contact trust for storage
  Map<String, dynamic> _serializeContactTrust(ContactTrust trust) {
    return {
      'trustLevel': trust.trustLevel.index,
      'trustScore': trust.trustScore,
      'interactionCount': trust.interactionCount,
      'relationshipDurationDays': trust.relationshipDuration.inDays,
      'communicationPatterns': trust.communicationPatterns,
      'lastInteraction': trust.lastInteraction.toIso8601String(),
      'isInPhonebook': trust.isInPhonebook,
      'displayName': trust.displayName,
    };
  }

  /// Deserialize contact trust from storage
  ContactTrust _deserializeContactTrust(Map<String, dynamic> data, String contactId) {
    return ContactTrust(
      contactId: contactId,
      trustLevel: TrustLevel.values[data['trustLevel'] as int],
      trustScore: (data['trustScore'] as num).toDouble(),
      interactionCount: data['interactionCount'] as int,
      relationshipDuration: Duration(days: data['relationshipDurationDays'] as int),
      communicationPatterns: List<String>.from(data['communicationPatterns'] as List),
      lastInteraction: DateTime.parse(data['lastInteraction'] as String),
      isInPhonebook: data['isInPhonebook'] as bool,
      displayName: data['displayName'] as String?,
    );
  }

  /// Ensure service is initialized
  Future<void> _ensureInitialized() async {
    if (!_initialized) {
      await initialize();
    }
  }

  /// Clear all contact data (for testing/reset)
  Future<void> clearAllData() async {
    await _ensureInitialized();
    
    final keys = _prefs.getKeys()
        .where((key) => key.startsWith(_storagePrefix))
        .toList();
    
    for (final key in keys) {
      await _prefs.remove(key);
    }
    
    _contactCache.clear();
    developer.log('Cleared all contact intelligence data', name: _logTag);
  }
}
