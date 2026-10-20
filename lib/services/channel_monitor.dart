import 'dart:async';
import '../models/app_activity.dart';

/// Monitors specific channels/apps for activity
class ChannelSpecificMonitor {
  final List<AppConfig> _monitoredApps = [];
  final StreamController<AppActivity> _activityController = StreamController.broadcast();

  Stream<AppActivity> get activityStream => _activityController.stream;

  Future<void> startMonitoring() async {
    // Actual monitoring implementation would go here
  }

  Future<void> stopMonitoring() async {
    // Cleanup monitoring resources
  }

  List<AppConfig> getMonitoredApps() => List.unmodifiable(_monitoredApps);

  Future<void> setAppMonitoring(String packageName, bool enabled) async {
    final index = _monitoredApps.indexWhere((app) => app.packageName == packageName);
    if (index >= 0) {
      _monitoredApps[index] = _monitoredApps[index].copyWith(isEnabled: enabled);
    }
  }

  void dispose() {
    _activityController.close();
  }
}

/// Configuration for a monitored app
class AppConfig {
  final String packageName;
  final String displayName;
  final RiskLevel baseRiskLevel;
  final bool isEnabled;
  final List<String> monitoringRules;

  const AppConfig({
    required this.packageName,
    required this.displayName,
    this.baseRiskLevel = RiskLevel.medium,
    this.isEnabled = true,
    this.monitoringRules = const [],
  });

  AppConfig copyWith({
    String? packageName,
    String? displayName,
    RiskLevel? baseRiskLevel,
    bool? isEnabled,
    List<String>? monitoringRules,
  }) {
    return AppConfig(
      packageName: packageName ?? this.packageName,
      displayName: displayName ?? this.displayName,
      baseRiskLevel: baseRiskLevel ?? this.baseRiskLevel,
      isEnabled: isEnabled ?? this.isEnabled,
      monitoringRules: monitoringRules ?? this.monitoringRules,
    );
  }
}

/// Risk levels for apps
enum RiskLevel {
  low,
  medium,
  high,
  critical
}
