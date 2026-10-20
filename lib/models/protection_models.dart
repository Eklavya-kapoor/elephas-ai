enum ActivityType {
  messageReceived,
  messageDisplayed
}

abstract class MonitoringConfig {
  String get packageName;
  String get displayName;
  String get baseRiskLevel;
  bool get isEnabled;
  List<String> get monitoringRules;
}
