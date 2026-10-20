/// Information about an app being monitored for potential scams
class MonitoredAppInfo {
  final String packageName;
  final String appName;
  final bool isActive;
  final DateTime lastScan;
  final int threatsDetected;
  final double riskScore;

  MonitoredAppInfo({
    required this.packageName,
    required this.appName,
    required this.isActive,
    required this.lastScan,
    this.threatsDetected = 0,
    this.riskScore = 0.0,
  });

  Map<String, dynamic> toJson() => {
    'packageName': packageName,
    'appName': appName,
    'isActive': isActive,
    'lastScan': lastScan.toIso8601String(),
    'threatsDetected': threatsDetected,
    'riskScore': riskScore,
  };
}
