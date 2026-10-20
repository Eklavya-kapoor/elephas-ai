import 'alert_types.dart';

/// Configuration for app-specific monitoring settings
class AppMonitoringConfig {
  /// The package name of the app (e.g., com.whatsapp)
  final String packageName;

  /// User-friendly display name
  final String displayName;

  /// Base risk level for this app's communications
  final RiskLevel baseRiskLevel;

  /// Whether monitoring is enabled for this app
  final bool isEnabled;

  /// App-specific monitoring rules and patterns
  final Map<String, dynamic> monitoringRules;

  /// Settings for OCR-based content scanning
  final bool enableOCR;

  const AppMonitoringConfig({
    required this.packageName,
    required this.displayName,
    required this.baseRiskLevel,
    this.isEnabled = true,
    this.monitoringRules = const {},
    this.enableOCR = false,
  });
}
