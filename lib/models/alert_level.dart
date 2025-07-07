// lib/models/alert_level.dart

/// Represents different levels of scam alert severity
enum AlertLevel {
  /// No risk detected (0-49% confidence)
  none,

  /// Low-medium risk (50-69% confidence)
  /// Shows subtle warning
  medium,

  /// High risk (70-89% confidence)
  /// Shows prominent warning
  high,

  /// Critical risk (90-100% confidence)
  /// Shows immediate blocking alert
  critical,
}
