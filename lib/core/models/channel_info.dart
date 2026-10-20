/// Information about a communication channel being monitored
class ChannelInfo {
  /// Package name of the app (e.g., com.whatsapp)
  final String packageName;

  /// User-friendly name of the app
  final String appName;

  /// Type of channel (e.g., messaging, dating, social)
  final String channelType;

  /// Whether monitoring is currently active
  final bool isActive;

  /// When monitoring last occurred
  final DateTime lastScan;

  /// Number of threats detected in this channel
  final int threatsDetected;

  /// Risk score for this channel (0-1)
  final double riskScore;

  const ChannelInfo({
    required this.packageName,
    required this.appName,
    required this.channelType,
    required this.isActive,
    required this.lastScan,
    this.threatsDetected = 0,
    this.riskScore = 0.0,
  });
}
