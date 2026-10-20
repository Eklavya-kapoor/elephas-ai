import '../core/intelligence/contact_intelligence_service.dart';

/// Legacy compatibility wrapper for contact service
/// Redirects to the new Elephas AI backend contact intelligence
class HighPerformanceContactService {
  static HighPerformanceContactService? _instance;
  static HighPerformanceContactService get instance =>
      _instance ??= HighPerformanceContactService._();

  // Default constructor for compatibility
  HighPerformanceContactService() : this._();

  HighPerformanceContactService._();

  final ContactIntelligenceService _elephasService =
      ContactIntelligenceService();
  bool _isInitialized = false;

  /// Initialize the service
  Future<void> initialize() async {
    if (_isInitialized) return;
    await _elephasService.initialize();
    _isInitialized = true;
  }

  /// Get contact information
  Future<ContactInfo?> getContactInfo(String contactId) async {
    if (!_isInitialized) await initialize();

    try {
      final trust = await _elephasService.evaluateContactTrust(contactId);
      return ContactInfo(
        id: contactId,
        displayName: trust.displayName ?? 'Unknown',
        phoneNumber: null, // Not available in ContactTrust model
        isKnown: trust.isInPhonebook,
        riskLevel: _mapTrustLevelToRisk(trust.trustLevel),
        lastInteraction: trust.lastInteraction,
        trustScore: trust.trustScore,
      );
    } catch (e) {
      return null;
    }
  }

  /// Check if contact is trusted
  Future<bool> isContactTrusted(String contactId) async {
    if (!_isInitialized) await initialize();

    final trust = await _elephasService.evaluateContactTrust(contactId);
    return trust.trustScore > 0.7;
  }

  /// Get all contacts
  Future<List<ContactInfo>> getAllContacts() async {
    if (!_isInitialized) await initialize();

    // Legacy compatibility - return empty list or implement if needed
    return [];
  }

  /// Record interaction
  Future<void> recordInteraction({
    required String contactId,
    required String message,
    required String appPackage,
    DateTime? timestamp,
  }) async {
    if (!_isInitialized) await initialize();

    await _elephasService.recordInteraction(
      contactId: contactId,
      message: message,
      appPackage: appPackage,
      timestamp: timestamp ?? DateTime.now(),
    );
  }

  /// Update contact info
  Future<void> updateContactInfo(
      String contactId, Map<String, dynamic> info) async {
    // Legacy compatibility - implement if needed
  }

  /// Delete contact
  Future<void> deleteContact(String contactId) async {
    // Legacy compatibility - implement if needed
  }

  /// Search contacts
  Future<List<ContactInfo>> searchContacts(String query) async {
    // Legacy compatibility - return empty list or implement if needed
    return [];
  }

  /// Get contact statistics
  Map<String, dynamic> getStatistics() {
    return {
      'totalContacts': 0,
      'trustedContacts': 0,
      'riskContacts': 0,
      'unknownContacts': 0,
    };
  }

  /// Get stats (alias for getStatistics)
  Map<String, dynamic> getStats() {
    return getStatistics();
  }

  /// Has contact permission getter
  bool get hasContactPermission => true; // Default to true for compatibility

  /// Force refresh contacts
  Future<void> forceRefresh() async {
    // Legacy compatibility - implement if needed
  }

  /// Request contact permission
  Future<bool> requestContactPermission() async {
    // Legacy compatibility - implement if needed
    return true;
  }

  /// Helper method to map trust level to risk level string
  String _mapTrustLevelToRisk(dynamic trustLevel) {
    final trustLevelStr = trustLevel.toString().toLowerCase();
    if (trustLevelStr.contains('high')) return 'none';
    if (trustLevelStr.contains('medium')) return 'low';
    if (trustLevelStr.contains('low')) return 'medium';
    if (trustLevelStr.contains('unknown')) return 'high';
    return 'medium';
  }

  /// Check if initialized
  bool get isInitialized => _isInitialized;
}

/// Contact information model for legacy compatibility
class ContactInfo {
  final String id;
  final String displayName;
  final String? phoneNumber;
  final bool isKnown;
  final String riskLevel;
  final DateTime? lastInteraction;
  final double trustScore;
  final bool isSaved;
  final bool isFamilyContact;
  final bool isTrustedContact;
  final int messageHistoryCount;

  ContactInfo({
    required this.id,
    required this.displayName,
    this.phoneNumber,
    required this.isKnown,
    required this.riskLevel,
    this.lastInteraction,
    required this.trustScore,
    bool? isSaved,
    bool? isFamilyContact,
    bool? isTrustedContact,
    int? messageHistoryCount,
  })  : isSaved = isSaved ?? isKnown,
        isFamilyContact = isFamilyContact ?? false,
        isTrustedContact = isTrustedContact ?? (trustScore > 0.7),
        messageHistoryCount = messageHistoryCount ?? 0;

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'displayName': displayName,
      'phoneNumber': phoneNumber,
      'isKnown': isKnown,
      'riskLevel': riskLevel,
      'lastInteraction': lastInteraction?.toIso8601String(),
      'trustScore': trustScore,
    };
  }

  factory ContactInfo.fromJson(Map<String, dynamic> json) {
    return ContactInfo(
      id: json['id'],
      displayName: json['displayName'],
      phoneNumber: json['phoneNumber'],
      isKnown: json['isKnown'],
      riskLevel: json['riskLevel'],
      lastInteraction: json['lastInteraction'] != null
          ? DateTime.parse(json['lastInteraction'])
          : null,
      trustScore: (json['trustScore'] ?? 0.0).toDouble(),
    );
  }
}
