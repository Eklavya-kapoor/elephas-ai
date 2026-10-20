/// Configuration for alert behavior and thresholds
class AlertConfig {
  /// Maximum number of alerts that can be shown per hour
  final int maxAlertsPerHour;

  /// Minimum time between consecutive alerts
  final Duration minAlertInterval;

  /// Minimum confidence level required to show an alert
  final double minimumConfidence;

  /// Whether to show visual alerts
  final bool showVisualAlerts;

  /// Whether to show audio alerts
  final bool playAudioAlerts;

  /// Whether to show notifications
  final bool showNotifications;

  const AlertConfig({
    this.maxAlertsPerHour =
        100, // Increased to ensure no scams are missed
    this.minAlertInterval = const Duration(
        seconds: 1), // Reduced to show alerts immediately
    this.minimumConfidence =
        0.60, // Matched with backend threshold for consistency
    this.showVisualAlerts = true,
    this.playAudioAlerts = true,
    this.showNotifications = true,
  });

  AlertConfig copyWith({
    int? maxAlertsPerHour,
    Duration? minAlertInterval,
    double? minimumConfidence,
    bool? showVisualAlerts,
    bool? playAudioAlerts,
    bool? showNotifications,
  }) {
    return AlertConfig(
      maxAlertsPerHour: maxAlertsPerHour ?? this.maxAlertsPerHour,
      minAlertInterval: minAlertInterval ?? this.minAlertInterval,
      minimumConfidence: minimumConfidence ?? this.minimumConfidence,
      showVisualAlerts: showVisualAlerts ?? this.showVisualAlerts,
      playAudioAlerts: playAudioAlerts ?? this.playAudioAlerts,
      showNotifications: showNotifications ?? this.showNotifications,
    );
  }
}
