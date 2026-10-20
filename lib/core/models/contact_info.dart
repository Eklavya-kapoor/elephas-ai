/// Contact information and trust metrics
class ContactInfo {
  final String id;
  final double trustScore;
  final bool knownScammer;
  final DateTime lastVerified;
  final Map<String, dynamic> metadata;

  ContactInfo({
    required this.id,
    required this.trustScore,
    required this.knownScammer,
    required this.lastVerified,
    required this.metadata,
  });

  /// Convert to JSON for API requests
  Map<String, dynamic> toJson() => {
    'contact_id': id,
    'trust_score': trustScore,
    'known_scammer': knownScammer,
    'last_verified': lastVerified.toIso8601String(),
    'metadata': metadata,
  };

  /// Create from API response
  factory ContactInfo.fromJson(Map<String, dynamic> json) {
    return ContactInfo(
      id: json['contact_id'] as String,
      trustScore: (json['trust_score'] as num).toDouble(),
      knownScammer: json['known_scammer'] as bool,
      lastVerified: DateTime.parse(json['last_verified'] as String),
      metadata: json['metadata'] as Map<String, dynamic>? ?? {},
    );
  }

  /// Create an unknown contact
  factory ContactInfo.unknown(String id) {
    return ContactInfo(
      id: id,
      trustScore: 0.0,
      knownScammer: false,
      lastVerified: DateTime.now(),
      metadata: {'source': 'unknown'},
    );
  }

  /// Create a trusted contact
  factory ContactInfo.trusted(String id) {
    return ContactInfo(
      id: id,
      trustScore: 1.0,
      knownScammer: false,
      lastVerified: DateTime.now(),
      metadata: {'source': 'trusted'},
    );
  }
}
