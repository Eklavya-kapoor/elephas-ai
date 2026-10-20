/// Alert configuration for the protection service
class AlertConfig {
  final int maxAlertsPerHour;
  final Duration minTimeBetweenAlerts;
  final bool enableVibration;
  final bool enableSound;
  final bool enableToast;

  const AlertConfig({
    this.maxAlertsPerHour = 10,
    this.minTimeBetweenAlerts = const Duration(seconds: 30),
    this.enableVibration = true,
    this.enableSound = true,
    this.enableToast = true,
  });

  factory AlertConfig.conservative() {
    return const AlertConfig(
      maxAlertsPerHour: 5,
      minTimeBetweenAlerts: Duration(minutes: 1),
    );
  }
}
