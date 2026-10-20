import 'dart:async';
import 'dart:developer' as developer;
import 'package:flutter/services.dart';
import '../core/services/intelligent_protection_service.dart';
import '../core/models/detection_models.dart';
import '../core/models/alert_types.dart';
import 'overlay_service.dart';

/// Integration service that connects Phase 1 protection with existing overlay system
class ScamShieldPhase1Overlay {
  static const String _logTag = 'Phase1Overlay';

  final IntelligentProtectionService _protectionService;
  final OverlayService _overlayService;
  StreamSubscription<DetectionResult>? _alertSubscription;
  Timer? _statusCheckTimer;

  bool _isActive = false;
  int _overlaysShown = 0;
  DateTime? _lastOverlayTime;

  ScamShieldPhase1Overlay({
    required IntelligentProtectionService protectionService,
    required OverlayService overlayService,
  })  : _protectionService = protectionService,
        _overlayService = overlayService;

  /// Initialize and start the integrated protection with overlay
  Future<void> startProtectionWithOverlay() async {
    if (_isActive) return;

    try {
      developer.log('Starting Phase 1 protection with overlay integration',
          name: _logTag);

      // Initialize both services
      await _protectionService.initialize();
      await _protectionService.startProtection();

      // Connect alert stream to overlay
      _alertSubscription = _protectionService.alertStream.listen(
        (alert) => _handleThreatAlert(alert),
        onError: (error) {
          developer.log('Error in alert stream: $error',
              name: _logTag, error: error);
        },
      );

      // Start periodic status check
      _statusCheckTimer = Timer.periodic(const Duration(minutes: 5), (timer) {
        _checkServicesStatus();
      });

      _isActive = true;
      developer.log('Phase 1 protection with overlay is now active',
          name: _logTag);
    } catch (e) {
      developer.log('Failed to start protection with overlay: $e',
          name: _logTag, error: e);
      rethrow;
    }
  }

  /// Stop the integrated protection
  Future<void> stopProtection() async {
    if (!_isActive) return;

    try {
      _statusCheckTimer?.cancel();
      _statusCheckTimer = null;

      await _alertSubscription?.cancel();
      _alertSubscription = null;

      await _protectionService.stopProtection();

      _isActive = false;
      _overlaysShown = 0;
      _lastOverlayTime = null;

      developer.log('Phase 1 protection with overlay stopped', name: _logTag);
    } catch (e) {
      developer.log('Error stopping protection: $e', name: _logTag, error: e);
      rethrow;
    }
  }

  /// Dispose and clean up resources
  Future<void> dispose() async {
    try {
      // Stop protection first
      if (_isActive) {
        await stopProtection();
      }

      // Clean up subscriptions
      await _alertSubscription?.cancel();
      _statusCheckTimer?.cancel();

      developer.log('Phase 1 overlay integration disposed', name: _logTag);
    } catch (e) {
      developer.log('Error during disposal: $e', name: _logTag, error: e);
    }
  }

  /// Periodic check of services status
  void _checkServicesStatus() {
    if (!_isActive) return;

    try {
      final protectionActive = _protectionService.isProtecting;
      if (!protectionActive) {
        developer.log('Protection service inactive, restarting...',
            name: _logTag);
        _protectionService.startProtection();
      }
    } catch (e) {
      developer.log('Error checking services status: $e',
          name: _logTag, error: e);
    }
  }

  /// Handle threat alerts by showing the overlay with haptic feedback
  Future<void> _handleThreatAlert(DetectionResult alert) async {
    if (!alert.isThreat || !_isActive) return;

    try {
      developer.log(
          'Showing overlay for threat: ${alert.reasoning} (Level: ${alert.riskLevel})',
          name: _logTag);

      // Trigger haptic feedback based on risk level
      await _triggerHapticFeedback(alert.riskLevel);

      // Format alert message
      final message = _formatAlertMessage(alert);

      // Show overlay with detailed information
      await _overlayService.showScamOverlay(
        message,
        alert.threatType,
        {
          'confidence': alert.confidence.toStringAsFixed(3),
          'riskLevel': alert.riskLevel.toString(),
          'timestamp': alert.timestamp.millisecondsSinceEpoch.toString(),
          'reasoning': alert.reasoning.toString(),
          if (alert.evidence?['phone_number'] != null)
            'scamNumber': alert.evidence!['phone_number'].toString(),
          'detectionMethod': alert.detectionMethod.toString(),
        },
      );

      _overlaysShown++;
      _lastOverlayTime = DateTime.now();

      developer.log('Overlay shown successfully for threat', name: _logTag);
    } catch (e) {
      developer.log('Error showing overlay for threat: $e',
          name: _logTag, error: e);
    }
  }

  /// Format the alert message based on detection result
  String _formatAlertMessage(DetectionResult alert) {
    final baseMessage = 'SCAM ALERT: ${alert.threatType}';
    if (alert.reasoning.isNotEmpty) {
      return '$baseMessage\n\n${alert.reasoning}';
    }
    return baseMessage;
  }

  /// Trigger appropriate haptic feedback based on risk level
  Future<void> _triggerHapticFeedback(RiskLevel riskLevel) async {
    try {
      switch (riskLevel) {
        case RiskLevel.critical:
        case RiskLevel.high:
          await HapticFeedback.heavyImpact();
          break;
        case RiskLevel.medium:
          await HapticFeedback.mediumImpact();
          break;
        case RiskLevel.low:
        case RiskLevel.minimal:
          await HapticFeedback.lightImpact();
          break;
      }
    } catch (e) {
      developer.log('Error triggering haptic feedback: $e',
          name: _logTag, error: e);
    }
  }

  /// Test overlay functionality with a sample message
  Future<bool> testOverlay(String message) async {
    if (!_isActive) {
      developer.log('Cannot test overlay: Protection not active',
          name: _logTag);
      return false;
    }

    try {
      developer.log('Testing overlay with message: $message', name: _logTag);

      final result = await _protectionService.analyzeMessage(message: message);

      if (result.isThreat) {
        developer.log('Test message detected as threat! Showing overlay...',
            name: _logTag);
        await _handleThreatAlert(result);
        developer.log('Test overlay shown successfully', name: _logTag);
        return true;
      }

      return false;
    } catch (e) {
      developer.log('Error testing overlay: $e', name: _logTag, error: e);
      return false;
    }
  }

  /// Get current service status
  Map<String, dynamic> getStatus() {
    return {
      'isActive': _isActive,
      'protection': {
        'isInitialized': _protectionService.isInitialized,
        'isProtecting': _protectionService.isProtecting,
        'lastScanTime': _protectionService.lastScanTime?.millisecondsSinceEpoch,
        'totalScans': _protectionService.totalScans,
        'scamsDetected': _protectionService.scamsDetected,
      },
      'overlay': {
        'overlaysShown': _overlaysShown,
        'lastOverlayTime': _lastOverlayTime?.millisecondsSinceEpoch,
      },
      'monitoredApps': _protectionService.monitoredApps,
      'startedAt': DateTime.now().toIso8601String(),
    };
  }

  /// Check if protection is active
  bool get isActive => _isActive;

  /// Get total number of overlays shown
  int get overlaysShown => _overlaysShown;

  /// Get timestamp of last overlay shown
  DateTime? get lastOverlayTime => _lastOverlayTime;
}
