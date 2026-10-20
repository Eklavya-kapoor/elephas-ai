/// Represents the trust level of a contact
enum ContactTrustLevel {
  unknown('Unknown'),
  blocked('Blocked'),
  suspicious('Suspicious'),
  newContact('New Contact'),
  casual('Casual Contact'),
  regular('Regular Contact'),
  trusted('Trusted'),
  family('Family');

  final String description;
  const ContactTrustLevel(this.description);
}

/// Contact trust information
class ContactTrustInfo {
  final String displayName;
  final String? phoneNumber;
  final bool isSavedContact;
  final ContactTrustLevel trustLevel;
  final double trustScore;
  final int interactionCount;
  final DateTime? lastInteraction;

  const ContactTrustInfo({
    required this.displayName,
    this.phoneNumber,
    required this.isSavedContact,
    required this.trustLevel,
    this.trustScore = 0.0,
    required this.interactionCount,
    this.lastInteraction,
  });
}
