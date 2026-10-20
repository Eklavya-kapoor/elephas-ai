import 'dart:async';
import 'dart:developer' as developer;
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/alert_config.dart' as legacy_config;
import '../models/alert_types.dart';
import '../models/detection_models.dart';
import '../models/channel_info.dart';
import './channel_monitor.dart';
import './conversation_analyzer.dart';
import './contact_intelligence.dart';

/// Core service for intelligent scam detection and protection
/// Coordinates zero false positive detection with channel-specific monitoring
class IntelligentProtectionService with ChangeNotifier {
  static const String _logTag = 'IntelligentProtection';

  // Core components
  final ContactIntelligenceService _contactIntelligence;
  final ConversationAnalyzer _conversationAnalyzer;
  final ChannelMonitor _channelMonitor;

  // Protection state
  bool _isInitialized = false;
  bool _isActive = false;
  DateTime? _lastActivityTime;
  DateTime? _lastScanTime;

  // Statistics tracking
  int _totalScans = 0;
  int _threatsDetected = 0;
  int _falsePositivesPrevented = 0;
  double _accuracy = 100.0;

  // Detection history
  final List<DetectionResult> _detectionHistory = [];

  // Alert management
  final legacy_config.AlertConfig _alertConfig;
  final _alertController = StreamController<DetectionResult>.broadcast();
  final _statsController = StreamController<Map<String, dynamic>>.broadcast();
  Timer? _alertLimitResetTimer;
  DateTime? _lastAlertTime;
  int _alertsThisHour = 0;

  // Performance metrics
  final Map<String, num> _metrics = {
    'avgDetectionTimeMs': 0.0,
    'systemLoad': 0.0,
    'memoryUsageMb': 0.0,
    'batteryEfficiency': 100.0,
  };

  // Alert level configuration
  AlertLevel _defaultAlertLevel = AlertLevel.medium;

  /// Gets the current default alert level for new detections
  AlertLevel get defaultAlertLevel => _defaultAlertLevel;

  /// Sets the default alert level and notifies listeners
  set defaultAlertLevel(AlertLevel level) {
    if (_defaultAlertLevel != level) {
      _defaultAlertLevel = level;
      notifyListeners();
      // Persist the new setting
      _persistSettings();
    }
  }

  /// Internal method to persist settings
  Future<void> _persistSettings() async {
    final prefs = await SharedPreferences.getInstance();

    // Persist protection state
    await prefs.setBool('isActive', _isActive);

    // Persist alert config
    await prefs.setString('defaultAlertLevel', _defaultAlertLevel.name);

    // Persist stats
    await prefs.setInt('totalScans', _totalScans);
    await prefs.setInt('threatsDetected', _threatsDetected);
    await prefs.setInt('falsePositivesPrevented', _falsePositivesPrevented);
    await prefs.setDouble('accuracy', _accuracy);

    // Persist metrics
    await prefs.setDouble('avgDetectionTimeMs',
        _metrics['avgDetectionTimeMs']?.toDouble() ?? 0.0);
    await prefs.setDouble(
        'systemLoad', _metrics['systemLoad']?.toDouble() ?? 0.0);
    await prefs.setDouble(
        'memoryUsageMb', _metrics['memoryUsageMb']?.toDouble() ?? 0.0);
    await prefs.setDouble('batteryEfficiency',
        _metrics['batteryEfficiency']?.toDouble() ?? 100.0);

    // Persist timestamps
    await prefs.setString(
        'lastActivityTime', _lastActivityTime?.toIso8601String() ?? '');
    await prefs.setString(
        'lastScanTime', _lastScanTime?.toIso8601String() ?? '');

    developer.log('Settings persisted successfully', name: _logTag);
  }

  /// Internal method to load persisted settings
  Future<void> _loadSettings() async {
    try {
      final prefs = await SharedPreferences.getInstance();

      // Load protection state
      _isActive = prefs.getBool('isActive') ?? false;

      // Load alert config - handle type mismatches gracefully
      try {
        final alertLevelName = prefs.getString('defaultAlertLevel');
        if (alertLevelName != null) {
          _defaultAlertLevel = AlertLevel.values.firstWhere(
              (level) => level.name == alertLevelName,
              orElse: () => AlertLevel.medium);
        }
      } catch (e) {
        // Type mismatch - clear corrupted value and use default
        developer.log('Clearing corrupted defaultAlertLevel setting',
            name: _logTag);
        await prefs.remove('defaultAlertLevel');
        _defaultAlertLevel = AlertLevel.medium;
      }

      // Load stats
      _totalScans = prefs.getInt('totalScans') ?? 0;
      _threatsDetected = prefs.getInt('threatsDetected') ?? 0;
      _falsePositivesPrevented = prefs.getInt('falsePositivesPrevented') ?? 0;
      _accuracy = prefs.getDouble('accuracy') ?? 100.0;

      // Load metrics
      _metrics['avgDetectionTimeMs'] =
          prefs.getDouble('avgDetectionTimeMs') ?? 0.0;
      _metrics['systemLoad'] = prefs.getDouble('systemLoad') ?? 0.0;
      _metrics['memoryUsageMb'] = prefs.getDouble('memoryUsageMb') ?? 0.0;
      _metrics['batteryEfficiency'] =
          prefs.getDouble('batteryEfficiency') ?? 100.0;

      // Load timestamps - handle type mismatches gracefully
      try {
        final lastActivityStr = prefs.getString('lastActivityTime');
        if (lastActivityStr?.isNotEmpty ?? false) {
          _lastActivityTime = DateTime.tryParse(lastActivityStr!);
        }
      } catch (e) {
        await prefs.remove('lastActivityTime');
      }

      try {
        final lastScanStr = prefs.getString('lastScanTime');
        if (lastScanStr?.isNotEmpty ?? false) {
          _lastScanTime = DateTime.tryParse(lastScanStr!);
        }
      } catch (e) {
        await prefs.remove('lastScanTime');
      }

      developer.log('Settings loaded successfully', name: _logTag);
    } catch (e) {
      developer.log('Error loading settings, using defaults: $e',
          name: _logTag);
      // Use default values if loading fails
    }
  }

  // Getters for protection state
  bool get isInitialized => _isInitialized;
  bool get isActive => _isActive;
  bool get isProtecting => _isActive && _isInitialized;
  DateTime? get lastActivityTime => _lastActivityTime;
  DateTime? get lastScanTime => _lastScanTime;

  // Getters for monitoring and alerts
  Set<String> get monitoredApps => _channelMonitor.monitoredApps;
  bool get canShowAlert => _alertsThisHour < _alertConfig.maxAlertsPerHour;
  DateTime? get lastAlertTime => _lastAlertTime;
  int get remainingAlerts =>
      (_alertConfig.maxAlertsPerHour - _alertsThisHour).toInt();

  // Getters for statistics
  int get totalScans => _totalScans;
  int get scamsDetected => _threatsDetected;
  int get falsePositivesPrevented => _falsePositivesPrevented;
  double get detectionAccuracy => _accuracy;
  List<DetectionResult> get detectionHistory =>
      List.unmodifiable(_detectionHistory);

  // Getters for stream access
  Stream<DetectionResult> get alertStream => _alertController.stream;
  Stream<Map<String, dynamic>> get statsStream => _statsController.stream;

  IntelligentProtectionService({
    legacy_config.AlertConfig? alertConfig,
    ContactIntelligenceService? contactIntelligence,
    ConversationAnalyzer? conversationAnalyzer,
    ChannelMonitor? channelMonitor,
  })  : _alertConfig = alertConfig ?? const legacy_config.AlertConfig(),
        _contactIntelligence =
            contactIntelligence ?? ContactIntelligenceService(),
        _conversationAnalyzer =
            conversationAnalyzer ?? ConversationAnalyzer.instance,
        _channelMonitor = channelMonitor ?? ChannelMonitor() {
    developer.log('Creating IntelligentProtectionService', name: _logTag);
    _setupAlertLimitReset();
  }

  void _setupAlertLimitReset() {
    _alertLimitResetTimer?.cancel();
    _alertLimitResetTimer = Timer.periodic(
      const Duration(hours: 1),
      (_) {
        _alertsThisHour = 0;
        notifyListeners();
      },
    );
  }

  /// Initialize the protection service
  Future<void> initialize() async {
    if (_isInitialized) return;

    try {
      // Load persisted settings first
      await _loadSettings();

      // Initialize core components
      await Future.wait([
        _contactIntelligence.initialize(),
        _conversationAnalyzer.initialize(),
        _channelMonitor.initialize(),
      ]);

      _isInitialized = true;
      developer.log('Protection service initialized', name: _logTag);
    } catch (e) {
      developer.log('Failed to initialize: $e', name: _logTag);
      rethrow;
    }
  }

  /// Start protection monitoring
  Future<void> startProtection() async {
    if (!_isInitialized) {
      throw StateError('Service not initialized');
    }

    if (_isActive) return;

    _isActive = true;
    _lastActivityTime = DateTime.now();
    developer.log('Protection started', name: _logTag);
    notifyListeners();
  }

  /// Stop protection monitoring
  Future<void> stopProtection() async {
    if (!_isActive) return;

    _isActive = false;
    _lastActivityTime = DateTime.now();
    developer.log('Protection stopped', name: _logTag);
    notifyListeners();
  }

  /// Get filtered detection history
  List<DetectionResult> getDetectionHistory({
    bool onlyThreats = false,
    DateTime? since,
    String? appPackage,
  }) {
    return _detectionHistory.where((result) {
      if (onlyThreats && !result.isThreat) {
        return false;
      }
      if (since != null && result.timestamp.isBefore(since)) {
        return false;
      }
      if (appPackage != null && result.metadata?['appPackage'] != appPackage) {
        return false;
      }
      return true;
    }).toList()
      ..sort((a, b) => b.timestamp.compareTo(a.timestamp)); // Most recent first
  }

  /// Add detection result to history
  void _addToHistory(DetectionResult result) {
    _detectionHistory.add(result);
    notifyListeners();
  }

  /// Clear detection history
  void clearHistory() {
    _detectionHistory.clear();
    notifyListeners();
  }

  /// Report false positive
  Future<void> reportFalsePositive(DetectionResult result) async {
    if (!_detectionHistory.contains(result)) return;

    try {
      // Update metrics
      _falsePositivesPrevented++;
      _updateAccuracy(true);

      // Update result metadata
      final index = _detectionHistory.indexOf(result);
      final updatedMetadata = Map<String, dynamic>.from(result.metadata ?? {})
        ..addAll({
          'wasFalsePositive': true,
          'reportedAt': DateTime.now().millisecondsSinceEpoch,
        });

      // Create updated result
      final updatedResult = DetectionResult(
        isThreat: result.isThreat,
        riskScore: result.riskScore,
        confidence: result.confidence,
        riskLevel: result.riskLevel,
        message: result.message,
        reasoning: result.reasoning,
        evidence: result.evidence,
        contactId: result.contactId,
        detectedType: result.detectedType,
        metadata: updatedMetadata,
      );

      // Update history
      _detectionHistory[index] = updatedResult;
      notifyListeners();

      // Log for analysis
      developer.log(
        'False positive reported for detection: ${result.reasoning}',
        name: _logTag,
      );
    } catch (e) {
      developer.log(
        'Error reporting false positive: $e',
        name: _logTag,
        error: e,
      );
    }
  }

  /// Analyze message for potential scams
  Future<DetectionResult> analyzeMessage({
    required String message,
    String? contactId,
    String? appPackage,
    Map<String, dynamic>? metadata,
  }) async {
    if (!_isInitialized) {
      throw StateError('Service not initialized');
    }

    _lastActivityTime = DateTime.now();
    _totalScans++;

    try {
      // Create context with metadata
      final context = await _getMessageContext(contactId, appPackage);
      if (metadata != null) {
        context['metadata'] = metadata;
      }

      // Get result from analyzer
      final result = await _conversationAnalyzer.analyzeMessage(
        message: message,
        appPackage: context['channel'] as String? ?? 'unknown',
        contactId: contactId,
        conversationHistory: metadata?['history'] as String?,
      );

      _updateMetrics(result);
      _addToHistory(result);

      if (result.isScam) {
        _threatsDetected++;
        await _handleAlert(result);
      }

      return result;
    } catch (e) {
      developer.log('Error analyzing message: $e', name: _logTag, error: e);
      rethrow;
    }
  }

  /// Get context for message analysis
  Future<Map<String, dynamic>> _getMessageContext(
      String? contactId, String? appPackage) async {
    final context = <String, dynamic>{
      'timestamp': DateTime.now().millisecondsSinceEpoch,
      'app': appPackage,
    };

    if (contactId != null) {
      final contactInfo = await _contactIntelligence.getContactInfo(contactId);
      if (contactInfo != null) {
        context['contactInfo'] = contactInfo;
      }
    }

    return context;
  }

  /// Update service metrics based on detection result
  void _updateMetrics(DetectionResult result) {
    // Update performance metrics
    _metrics['avgDetectionTimeMs'] =
        (_metrics['avgDetectionTimeMs']! + 100) / 2;

    // Update accuracy if we have feedback
    if (result.metadata?.containsKey('wasFalsePositive') ?? false) {
      final wasFalse = result.metadata!['wasFalsePositive'] as bool;
      if (wasFalse) {
        _falsePositivesPrevented++;
      }
      _updateAccuracy(wasFalse);
    }

    _lastScanTime = DateTime.now();
    _emitStats();
  }

  /// Update accuracy based on feedback
  void _updateAccuracy(bool wasFalsePositive) {
    final totalChecks = _totalScans;
    if (totalChecks == 0) return;

    final successfulDetections = totalChecks - _falsePositivesPrevented;
    _accuracy = (successfulDetections / totalChecks) * 100;
  }

  /// Emit current stats to subscribers
  void _emitStats() {
    if (!_statsController.isClosed) {
      _statsController.add({
        'totalScans': _totalScans,
        'threatsDetected': _threatsDetected,
        'falsePositivesPrevented': _falsePositivesPrevented,
        'accuracy': _accuracy,
        'lastScanTime': _lastScanTime?.millisecondsSinceEpoch,
        'isActive': _isActive,
        'metrics': Map<String, num>.from(_metrics),
      });
    }
  }

  /// Get performance metrics about the protection service
  Map<String, num> getPerformanceMetrics() {
    return Map<String, num>.from(_metrics);
  }

  /// Get information about monitored apps
  List<ChannelInfo> getMonitoredAppsInfo() {
    return _channelMonitor.getActiveChannels();
  }

  /// Get monitored app information
  List<ChannelInfo> getMonitoredChannels() {
    return _channelMonitor.getActiveChannels();
  }

  /// Handle alert for detection result
  Future<void> _handleAlert(DetectionResult result) async {
    if (!result.shouldAlert) return;

    // Check alert limits
    if (_alertsThisHour >= _alertConfig.maxAlertsPerHour) {
      developer.log(
        'Alert limit reached: $_alertsThisHour alerts this hour',
        name: _logTag,
      );
      return;
    }

    // Check alert cooldown
    if (_lastAlertTime != null) {
      final timeSinceLastAlert = DateTime.now().difference(_lastAlertTime!);
      if (timeSinceLastAlert < _alertConfig.minAlertInterval) {
        developer.log(
          'Alert cooldown active: ${_alertConfig.minAlertInterval - timeSinceLastAlert} remaining',
          name: _logTag,
        );
        return;
      }
    }

    try {
      // Send alert
      _alertController.add(result);
      _alertsThisHour++;
      _lastAlertTime = DateTime.now();
      notifyListeners();

      developer.log(
        'Alert sent: ${result.threatType} (${result.riskLevel})',
        name: _logTag,
      );
    } catch (e) {
      developer.log(
        'Error sending alert: $e',
        name: _logTag,
        error: e,
      );
    }
  }

  @override
  void dispose() {
    _alertLimitResetTimer?.cancel();
    _alertController.close();
    _statsController.close();
    super.dispose();
  }
}
