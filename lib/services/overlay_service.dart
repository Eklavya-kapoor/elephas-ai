// lib/services/overlay_service.dart
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:permission_handler/permission_handler.dart';

class OverlayService extends ChangeNotifier {
  static const MethodChannel _overlayChannel = MethodChannel('elephas_ai/overlay');
  
  bool _isInitialized = false;
  bool _isShowingAlert = false;
  String _currentApp = '';

  // Duration for alert display
  static const Duration alertDuration = Duration(seconds: 10);
  Timer? _hideTimer;

  OverlayService() {
    debugPrint('🟢 [OverlayService] CONSTRUCTOR called: ${identityHashCode(this)}');
  }

  /// Initialize the overlay service
  void initialize() {
    debugPrint('🟢 [OverlayService] INITIALIZE called: ${identityHashCode(this)}');
    _isInitialized = true;
  }

  /// Set the current active app package name
  void setCurrentApp(String packageName) {
    if (_currentApp != packageName) {
      _currentApp = packageName;
      // Hide any existing alert when app changes
      if (_isShowingAlert) {
        hideAlert();
      }
      notifyListeners();
    }
  }

  /// Get the current active app package name
  String getCurrentApp() => _currentApp;

  /// Show alert overlay
  Future<void> showScamOverlay(String title, String severity, Map<String, String> data) async {
    if (!_isInitialized) {
      debugPrint('⚠️ OverlayService not initialized!');
      return;
    }

    // If another alert is showing, hide it and cancel its timer
    if (_isShowingAlert) {
      _hideTimer?.cancel();
      await hideAlert();
      // Small delay to ensure smooth transition
      await Future.delayed(const Duration(milliseconds: 100));
    }

    // Show appropriate image based on whether URL is present
    final alertType = data['containsUrl'] == 'true' ? 'url' : 'scam';
    
    try {
      _isShowingAlert = true;
      
      final bool success = await _overlayChannel.invokeMethod('showOverlay', {
        'title': title,
        'severity': severity,
        'data': data,
        'alertType': alertType,
      });

      if (!success) {
        debugPrint('❌ Failed to show overlay');
        _isShowingAlert = false;
      } else {
        // Start timer to auto-hide after duration
        _hideTimer?.cancel();
        _hideTimer = Timer(alertDuration, () async {
          await hideAlert();
        });
      }
    } catch (e) {
      debugPrint('❌ Error showing overlay: $e');
      _isShowingAlert = false;
    }
  }

  /// Hide any currently showing alert
  Future<void> hideAlert() async {
    _hideTimer?.cancel();
    _hideTimer = null;
    
    try {
      await _overlayChannel.invokeMethod('hideOverlay');
      _isShowingAlert = false;
    } catch (e) {
      debugPrint('❌ Error hiding alert: $e');
    }
  }

  /// Check and request overlay permission if needed
  Future<bool> checkAndRequestOverlayPermission() async {
    if (!await Permission.systemAlertWindow.isGranted) {
      debugPrint('🔒 Requesting overlay permission...');
      final status = await Permission.systemAlertWindow.request();
      return status.isGranted;
    }
    return true;
  }

  /// Test method to verify overlay functionality
  Future<void> testCompleteScamFlow() async {
    if (await checkAndRequestOverlayPermission()) {
      // Test regular scam alert
      await showScamOverlay(
        'Test Scam Alert',
        'HIGH_RISK',
        {
          'severity': 'HIGH_RISK',
          'containsUrl': 'false',
        },
      );

      // Wait between alerts
      await Future.delayed(const Duration(seconds: 3));

      // Test URL warning
      await showScamOverlay(
        'Test URL Warning',
        'HIGH_RISK',
        {
          'severity': 'HIGH_RISK',
          'containsUrl': 'true',
        },
      );
    } else {
      debugPrint('⚠️ Cannot test - overlay permission not granted');
    }
  }

  /// Test method to show a simple overlay after checking permissions
  Future<void> testShowOverlayWithPermission() async {
    if (await checkAndRequestOverlayPermission()) {
      await showScamOverlay(
        'Test Alert',
        'TEST',
        {
          'severity': 'TEST',
          'containsUrl': 'false',
        },
      );
      
      // Auto-hide after 3 seconds
      await Future.delayed(const Duration(seconds: 3));
      await hideAlert();
    } else {
      debugPrint('⚠️ Overlay permission not granted');
    }
  }
}
