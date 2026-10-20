import 'dart:async';
import 'package:flutter/material.dart';
import '../core/services/intelligent_protection_service.dart';
import '../core/models/alert_types.dart';
import '../core/models/alert_config.dart';
import '../core/models/detection_models.dart' as models;
import 'dart:developer' as developer;

/// Legacy compatibility wrapper for scam detection
/// Redirects to the new Elephas AI backend
class SmartScamDetectionService extends ChangeNotifier {
  static SmartScamDetectionService? _instance;
  static SmartScamDetectionService get instance =>
      _instance ??= SmartScamDetectionService._();

  SmartScamDetectionService._();

  final IntelligentProtectionService _elephasService =
      IntelligentProtectionService(
    alertConfig: const AlertConfig(
        maxAlertsPerHour: 10,
        minAlertInterval: Duration(minutes: 5),
        minimumConfidence: 0.8,
        showVisualAlerts: true,
        playAudioAlerts: true,
        showNotifications: true),
  );
  bool _isInitialized = false;
  bool _isScanning = false;
  final List<models.DetectionResult> _scanHistory = [];

  /// Initialize the service
  Future<void> initialize() async {
    if (!_isInitialized) {
      await _elephasService.initialize();
      _isInitialized = true;
      notifyListeners();
    }
  }

  /// Analyze message for scam detection
  Future<models.DetectionResult> analyzeMessage(
    String message, {
    required String appPackage,
    required String contactId,
    String? conversationHistory,
    Map<String, dynamic>? backendResult,
  }) async {
    if (!_isInitialized) await initialize();

    _isScanning = true;
    notifyListeners();

    try {
      // Use backend result if available
      if (backendResult != null && !backendResult.containsKey('error')) {
        final riskScore = (backendResult['riskScore'] as num?)?.toDouble() ?? 0.0;
        return models.DetectionResult(
          isThreat: backendResult['isScam'] as bool? ?? false,
          riskScore: riskScore,
          confidence: (backendResult['confidence'] as num?)?.toDouble() ?? 0.0,
          reasoning: backendResult['reasoning'] as String? ?? 'Unknown reasoning',
          evidence: backendResult['evidence'] as Map<String, dynamic>?,
          detectionMethod: 'backend_api',
          metadata: {'source': 'backend', 'rawResponse': backendResult},
          riskLevel: _calculateRiskLevel(riskScore),
        );
      }

      // Fallback to local detection
      final result = await _elephasService.analyzeMessage(
        message: message,
        appPackage: appPackage,
        contactId: contactId,
        metadata: conversationHistory != null
            ? {'conversationHistory': conversationHistory}
            : null,
      );

      _scanHistory.add(result);
      if (_scanHistory.length > 100) {
        _scanHistory.removeAt(0);
      }

      return result;
    } finally {
      _isScanning = false;
      notifyListeners();
    }
  }

  /// Legacy scan method - now requires package name for context-aware filtering
  Future<models.DetectionResult> scanMessage(String message, {String packageName = 'unknown'}) async {
    return analyzeMessage(
      message,
      appPackage: packageName,
      contactId: 'unknown',
    );
  }

  /// Quick scan for immediate threats
  Future<models.DetectionResult> quickScan(String message) async {
    if (!_isInitialized) {
      await initialize(); // Initialize if not already done
    }

    developer.log('🔍 QUICK SCAN: Starting quick scan for message: $message',
        name: 'ScamDetection');

    try {
      // Use the main model through IntelligentProtectionService
      final result = await _elephasService.analyzeMessage(
        message: message,
        contactId: 'quick_scan', // Special ID for quick scan
        appPackage: 'com.elephas.ai.quickscan',
        metadata: {'scanType': 'quick'},
      );

      developer.log('✅ QUICK SCAN: Analysis complete - ${result.toString()}',
          name: 'ScamDetection');

      // Add to scan history
      _scanHistory.add(result);
      notifyListeners();

      return Future.value(result);
    } catch (e, stack) {
      developer.log('❌ QUICK SCAN: Error during analysis - $e\n$stack',
          name: 'ScamDetection');
      return Future.value(models.DetectionResult.error('Analysis failed: $e'));
    }
  }

  /// Get scan history
  List<models.DetectionResult> get scanHistory =>
      List.unmodifiable(_scanHistory);

  /// Clear scan history
  void clearHistory() {
    _scanHistory.clear();
    notifyListeners();
  }

  /// Check if currently scanning
  bool get isScanning => _isScanning;

  /// Check if initialized
  bool get isInitialized => _isInitialized;

  /// Get sensitivity level
  String get sensitivityLevel => 'balanced';

  /// Set sensitivity level (legacy compatibility)
  void setSensitivityLevel(String level) {
    // No-op for legacy compatibility
  }

  /// Get performance metrics
  Map<String, dynamic> getPerformanceMetrics() {
    return {
      'avgDetectionTimeMs': 100.0,
      'systemLoad': 0.2,
      'memoryUsageMb': 50.0,
      'batteryEfficiency': 95.0,
    };
  }

  /// Get monitored apps info
  List<Map<String, dynamic>> getMonitoredApps() {
    final apps = _elephasService.monitoredApps;
    return apps
        .map((appId) => {
              'packageName': appId,
              'appName': _getAppName(appId),
              'channelType': 'messaging',
              'isActive': true,
              'lastScan': DateTime.now().toIso8601String(),
              'threatsDetected': 0,
              'riskScore': 0.0,
            })
        .toList();
  }

  String _getAppName(String packageName) {
    switch (packageName) {
      case 'com.whatsapp':
        return 'WhatsApp';
      case 'com.facebook.orca':
        return 'Messenger';
      case 'com.android.messaging':
        return 'Messages';
      default:
        return packageName.split('.').last;
    }
  }

  /// Enable/disable for specific app
  Future<void> setAppEnabled(String packageName, bool enabled) async {
    // No-op for legacy compatibility
  }

  /// Check if app is enabled
  bool isAppEnabled(String packageName) {
    return true; // Default enabled for legacy compatibility
  }

  /// Get custom rules
  List<Map<String, dynamic>> getCustomRules() {
    return []; // Legacy compatibility
  }

  /// Add custom rule
  Future<void> addCustomRule(Map<String, dynamic> rule) async {
    // No-op for legacy compatibility
  }

  /// Remove custom rule
  Future<void> removeCustomRule(String ruleId) async {
    // No-op for legacy compatibility
  }

  /// Update settings
  Future<void> updateSettings(Map<String, dynamic> settings) async {
    // No-op for legacy compatibility
  }

  /// Get current settings
  Map<String, dynamic> getSettings() {
    return {
      'sensitivity': 'balanced',
      'enableRealTimeProtection': true,
      'enableOverlayAlerts': true,
      'enableContextAnalysis': true,
      'smsSensitivity': 0.7,
      'callSensitivity': 0.8,
      'screenSensitivity': 0.6,
      'defaultAlertLevel': 'medium',
    };
  }

  /// Clear cache (legacy compatibility)
  void clearCache() {
    // No-op for legacy compatibility
  }

  /// SMS sensitivity getter/setter (legacy)
  double get smsSensitivity => 0.7;
  set smsSensitivity(double value) {
    // No-op for legacy compatibility
  }

  /// Call sensitivity getter/setter (legacy)
  double get callSensitivity => 0.8;
  set callSensitivity(double value) {
    // No-op for legacy compatibility
  }

  /// Screen sensitivity getter/setter (legacy)
  double get screenSensitivity => 0.6;
  set screenSensitivity(double value) {
    // No-op for legacy compatibility
  }

  /// Default risk level getter/setter
  RiskLevel get defaultRiskLevel => RiskLevel.medium;
  set defaultRiskLevel(RiskLevel value) {
    // No-op for legacy compatibility
  }

  /// Update custom rule
  Future<void> updateCustomRule(
      String ruleId, Map<String, dynamic> rule) async {
    // No-op for legacy compatibility
  }

  /// Get the default alert level
  AlertLevel get defaultAlertLevel => _elephasService.defaultAlertLevel;

  /// Set the default alert level
  set defaultAlertLevel(AlertLevel level) {
    _elephasService.defaultAlertLevel = level;
    notifyListeners();
  }

  /// Calculate risk level from risk score
  RiskLevel _calculateRiskLevel(double riskScore) => RiskLevel.fromScore(riskScore);
}
