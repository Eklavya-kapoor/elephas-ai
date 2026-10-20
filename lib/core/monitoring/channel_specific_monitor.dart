import 'dart:async';
import 'dart:developer' as developer;
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import '../models/alert_types.dart' as alerts;
import '../models/app_monitoring_config.dart';
import '../models/threat_intelligence.dart';
import '../intelligence/zero_false_positive_detector.dart';

class ChannelSpecificMonitor extends ChangeNotifier {
  static const String _tag = 'ChannelSpecificMonitor';
  
  // Channel for native monitoring service
  static const MethodChannel _monitorChannel = MethodChannel('elephas_ai/channel_monitor');
  
  // Risk levels for different apps
  final Map<String, AppMonitoringConfig> _highRiskApps = const {
    'com.whatsapp': AppMonitoringConfig(
      packageName: 'com.whatsapp',
      displayName: 'WhatsApp',
      baseRiskLevel: alerts.RiskLevel.high,
      isEnabled: true,
    ),
    'com.facebook.orca': AppMonitoringConfig(
      packageName: 'com.facebook.orca',
      displayName: 'Facebook Messenger',
      baseRiskLevel: alerts.RiskLevel.high,
      isEnabled: true,
    ),
    'com.viber.voip': AppMonitoringConfig(
      packageName: 'com.viber.voip',
      displayName: 'Viber',
      baseRiskLevel: alerts.RiskLevel.high,
      isEnabled: true,
    ),
    'com.telegram.messenger': AppMonitoringConfig(
      packageName: 'com.telegram.messenger',
      displayName: 'Telegram',
      baseRiskLevel: alerts.RiskLevel.high,
      isEnabled: true,
    ),
  };

  final Map<String, AppMonitoringConfig> _mediumRiskApps = const {
    'com.google.android.apps.messaging': AppMonitoringConfig(
      packageName: 'com.google.android.apps.messaging',
      displayName: 'Messages',
      baseRiskLevel: alerts.RiskLevel.medium,
      isEnabled: true,
    ),
    'com.android.mms': AppMonitoringConfig(
      packageName: 'com.android.mms',
      displayName: 'SMS/MMS',
      baseRiskLevel: alerts.RiskLevel.medium,
      isEnabled: true,
    ),
  };

  // Apps to ignore in monitoring
  static const Set<String> _ignoredApps = {
    'com.android.systemui',
    'com.android.settings',
    'com.google.android.googlequicksearchbox',
  };

  bool _isInitialized = false;
  bool _isMonitoring = false;
  final Map<String, int> _channelStats = {};
  late ZeroFalsePositiveDetector _detector;
  Timer? _monitoringTimer;

  bool get isInitialized => _isInitialized;
  bool get isMonitoring => _isMonitoring;
  Map<String, int> get channelStats => Map.unmodifiable(_channelStats);

  /// Initialize the monitoring service
  Future<void> initialize(ZeroFalsePositiveDetector detector) async {
    _detector = detector;
    try {
      await _monitorChannel.invokeMethod('initialize');
      _setupMessageHandler();
      _isInitialized = true;
      notifyListeners();
    } catch (e) {
      developer.log('Failed to initialize channel monitor: $e', name: _tag);
      rethrow;
    }
  }

  /// Start monitoring for configured channels
  Future<void> startMonitoring() async {
    if (!_isInitialized) {
      throw StateError('ChannelSpecificMonitor must be initialized before starting monitoring');
    }

    if (_isMonitoring) {
      return; // Already monitoring
    }

    try {
      // Enable monitoring for all high-risk apps
      for (final entry in _highRiskApps.entries) {
        if (entry.value.isEnabled) {
          await setChannelMonitoring(entry.key, true);
        }
      }

      // Enable monitoring for medium-risk apps
      for (final entry in _mediumRiskApps.entries) {
        if (entry.value.isEnabled) {
          await setChannelMonitoring(entry.key, true);
        }
      }

      // Start periodic check for new messages
      _monitoringTimer?.cancel();
      _monitoringTimer = Timer.periodic(const Duration(seconds: 5), (timer) {
        _checkNewMessages();
      });

      _isMonitoring = true;
      notifyListeners();

      developer.log('Channel monitoring started successfully', name: _tag);
    } catch (e) {
      developer.log('Failed to start monitoring: $e', name: _tag);
      rethrow;
    }
  }

  /// Stop monitoring channels
  Future<void> stopMonitoring() async {
    if (!_isMonitoring) {
      return; // Not monitoring
    }

    try {
      // Disable monitoring for all apps
      for (final entry in _highRiskApps.entries) {
        await setChannelMonitoring(entry.key, false);
      }
      for (final entry in _mediumRiskApps.entries) {
        await setChannelMonitoring(entry.key, false);
      }

      // Stop periodic check
      _monitoringTimer?.cancel();
      _monitoringTimer = null;

      _isMonitoring = false;
      notifyListeners();

      developer.log('Channel monitoring stopped successfully', name: _tag);
    } catch (e) {
      developer.log('Failed to stop monitoring: $e', name: _tag);
      rethrow;
    }
  }

  Future<void> _checkNewMessages() async {
    try {
      final result = await _monitorChannel.invokeMethod('checkNewMessages');
      if (result != null) {
        final messages = List<Map<String, dynamic>>.from(result);
        for (final message in messages) {
          final packageName = message['packageName'] as String;
          final text = message['message'] as String;
          final sender = message['sender'] as String?;

          if (_ignoredApps.contains(packageName)) {
            continue;
          }

          _channelStats[packageName] = (_channelStats[packageName] ?? 0) + 1;

          final detectionResult = await _detector.analyzeMessage(
            messageText: text,
            senderIdentifier: sender ?? 'unknown',
            channel: packageName,
          );

          if (detectionResult.isScam) {
            await _handleScamDetection(packageName, text, detectionResult);
          }
        }
        notifyListeners();
      }
    } catch (e) {
      developer.log('Error checking new messages: $e', name: _tag);
    }
  }

  void _setupMessageHandler() {
    _monitorChannel.setMethodCallHandler((call) async {
      switch (call.method) {
        case 'onMessageDetected':
          final args = call.arguments as Map<String, dynamic>;
          final packageName = args['packageName'] as String;
          final message = args['message'] as String;
          final sender = args['sender'] as String?;
          
          // Skip ignored apps
          if (_ignoredApps.contains(packageName)) {
            return;
          }

          // Update stats
          _channelStats[packageName] = (_channelStats[packageName] ?? 0) + 1;
          
          // Check message with detector
          final detectionResult = await _detector.analyzeMessage(
            messageText: message,
            senderIdentifier: sender ?? 'unknown',
            channel: packageName,
          );

          if (detectionResult.isScam) {
            // Handle detected scam
            await _handleScamDetection(packageName, message, detectionResult);
          }
          
          notifyListeners();
          break;
      }
    });
  }

  Future<void> _handleScamDetection(
    String packageName,
    String message,
    ThreatIntelligence threat,
  ) async {
    try {
      await _monitorChannel.invokeMethod('blockMessage', {
        'packageName': packageName,
        'message': message,
        'confidence': threat.confidence,
        'threat_info': threat.toString(),
        'risk_level': threat.riskLevel.toString(),
      });
    } catch (e) {
      developer.log('Failed to handle scam detection: $e', name: _tag);
    }
  }

  /// Get detailed monitoring statistics
  Map<String, dynamic> getDetailedStats() {
    return {
      'monitored_apps': _channelStats.keys.toList(),
      'total_messages': _channelStats.values.fold(0, (sum, count) => sum + count),
      'app_counts': Map<String, int>.from(_channelStats),
      'high_risk_apps': _highRiskApps.keys.toList(),
      'medium_risk_apps': _mediumRiskApps.keys.toList(),
      'detector_status': _detector.isInitialized,
      'is_monitoring': _isMonitoring,
    };
  }

  /// Enable or disable monitoring for a specific channel
  Future<void> setChannelMonitoring(String packageName, bool enabled) async {
    try {
      await _monitorChannel.invokeMethod('setAppMonitoring', {
        'packageName': packageName,
        'enabled': enabled,
      });
      notifyListeners();
    } catch (e) {
      developer.log('Failed to set channel monitoring: $e', name: _tag);
      rethrow;
    }
  }

  /// Run diagnostics on the monitoring service
  Future<Map<String, dynamic>> runDiagnostics() async {
    try {
      final result = await _monitorChannel.invokeMethod('runDiagnostics');
      return {
        ...Map<String, dynamic>.from(result),
        'detector_status': _detector.isInitialized,
        'monitored_apps': _channelStats.keys.toList(),
        'is_monitoring': _isMonitoring,
      };
    } catch (e) {
      developer.log('Failed to run diagnostics: $e', name: _tag);
      rethrow;
    }
  }

  @override
  void dispose() {
    _monitoringTimer?.cancel();
    super.dispose();
  }
}

/// Represents an activity detected in a monitored app
class AppActivity {
  final String packageName;
  final String? windowTitle;
  final String? textContent;
  final DateTime timestamp;
  final ActivityType type;
  final Map<String, dynamic>? metadata;

  AppActivity({
    required this.packageName,
    this.windowTitle,
    this.textContent,
    required this.timestamp,
    required this.type,
    this.metadata,
  });

  factory AppActivity.fromMap(Map<String, dynamic> map) {
    return AppActivity(
      packageName: map['packageName'] as String,
      windowTitle: map['windowTitle'] as String?,
      textContent: map['textContent'] as String?,
      timestamp: DateTime.fromMillisecondsSinceEpoch(map['timestamp'] as int),
      type: ActivityType.values.firstWhere(
        (e) => e.toString().split('.').last == map['type'],
        orElse: () => ActivityType.unknown,
      ),
      metadata: map['metadata'] as Map<String, dynamic>?,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'packageName': packageName,
      'windowTitle': windowTitle,
      'textContent': textContent,
      'timestamp': timestamp.millisecondsSinceEpoch,
      'type': type.toString().split('.').last,
      'metadata': metadata,
    };
  }
}

/// Types of app activities we monitor
enum ActivityType {
  messageReceived,
  messageDisplayed,
  notificationShown,
  screenContent,
  unknown,
}
