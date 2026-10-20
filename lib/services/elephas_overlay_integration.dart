import 'dart:async';
import 'dart:developer' as developer;
import '../core/services/intelligent_protection_service.dart';
import '../core/models/alert_types.dart';
import '../core/models/detection_models.dart';
import 'overlay_service.dart';

/// Integration service that connects Elephas AI protection with existing overlay system
class ElephasPhase1Overlay {
  static const String _logTag = 'ElephasOverlay';

  final IntelligentProtectionService _protectionService;
  final OverlayService _overlayService;
  StreamSubscription<DetectionResult>? _alertSubscription;

  bool _isActive = false;

  ElephasPhase1Overlay({
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
      _alertSubscription = _protectionService.alertStream
          .listen((alert) => _handleThreatAlert(alert));

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
      _alertSubscription?.cancel();
      _alertSubscription = null;

      await _protectionService.stopProtection();

      _isActive = false;
      developer.log('Phase 1 protection with overlay stopped', name: _logTag);
    } catch (e) {
      developer.log('Error stopping protection: $e', name: _logTag, error: e);
    }
  }

  /// Handle threat alerts by showing the existing image overlay
  void _handleThreatAlert(DetectionResult alert) async {
    if (!alert.isThreat || !_isActive) return;

    try {
      developer.log('Showing overlay for threat: ${alert.reasoning}',
          name: _logTag);

      // Use your existing overlay service with simple message
      await _overlayService.showScamOverlay(
        'SCAM DETECTED', // Simple message
        _mapRiskLevelToAlertType(alert.riskLevel), // Map to your alert type
        {
          'confidence': alert.confidence.toString(),
          'riskLevel': alert.riskLevel.toString(),
          'timestamp': alert.timestamp.millisecondsSinceEpoch.toString(),
          'reasoning': alert.reasoning,
          if (alert.evidence?['phone_number'] != null)
            'scamNumber': alert.evidence!['phone_number'].toString(),
        },
      );

      developer.log('Overlay shown successfully for threat', name: _logTag);
    } catch (e) {
      developer.log('Error showing overlay for threat: $e',
          name: _logTag, error: e);
    }
  }

  /// Map our risk levels to your existing alert types
  String _mapRiskLevelToAlertType(RiskLevel riskLevel) {
    switch (riskLevel) {
      case RiskLevel.critical:
        return 'CRITICAL_SCAM';
      case RiskLevel.high:
        return 'HIGH_RISK_SCAM';
      case RiskLevel.medium:
        return 'MODERATE_SCAM';
      case RiskLevel.low:
        return 'LOW_RISK_SCAM';
      case RiskLevel.minimal:
        return 'POTENTIAL_SCAM';
    }
  }

  /// Test the overlay with a sample scam message
  Future<void> testOverlay({String? testMessage}) async {
    if (!_isActive) {
      developer.log('Protection not active, cannot test overlay',
          name: _logTag);
      return;
    }

    final message = testMessage ?? 'URGENT! Send OTP now or account blocked!';

    try {
      developer.log('Testing overlay with message: $message', name: _logTag);

      final result = await _protectionService.analyzeMessage(
        message: message,
        contactId: 'test_unknown_contact',
        appPackage: 'com.whatsapp',
      );

      if (result.isThreat) {
        developer.log('Test detected threat, overlay should appear',
            name: _logTag);
      } else {
        developer.log(
            'Test message not detected as threat: ${result.reasoning}',
            name: _logTag);
      }
    } catch (e) {
      developer.log('Error testing overlay: $e', name: _logTag, error: e);
    }
  }

  /// Get current status
  Map<String, dynamic> getStatus() {
    return {
      'isActive': _isActive,
      'protectionStatus': {
        'isActive': _protectionService.isActive,
      },
      'monitoredApps': _protectionService.getMonitoredAppsInfo(),
    };
  }

  /// Check if protection is active
  bool get isActive => _isActive;

  /// Dispose resources
  void dispose() {
    stopProtection();
  }
}
