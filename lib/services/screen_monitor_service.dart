// lib/services/screen_monitor_service.dart
import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart';
import 'package:elephas_ai/models/alert_level.dart';
import 'package:elephas_ai/models/scam_detection_models.dart';
import 'scam_detection_service.dart';
import 'overlay_service.dart';

class ScreenMonitorService extends ChangeNotifier {
  static const MethodChannel _screenMonitorChannel =
      MethodChannel('elephas_ai/screen_monitor');
  static const MethodChannel _ocrChannel = MethodChannel('elephas_ai/ocr');
  static const MethodChannel _appControlChannel =
      MethodChannel('elephas_ai/app_control');

  SmartScamDetectionService? _scamDetectionService;
  OverlayService? _overlayService;

  bool _isMonitoring = false;
  bool get isMonitoring => _isMonitoring;

  void initialize(
      SmartScamDetectionService scamDetection, OverlayService overlayService) {
    _scamDetectionService = scamDetection;
    _overlayService = overlayService;
    _screenMonitorChannel.setMethodCallHandler(_handleNativeMethodCall);
    debugPrint(
        'ScreenMonitorService initialized and listening for native calls.');
  }

  Future<dynamic> _handleNativeMethodCall(MethodCall call) async {
    debugPrint(
        'Received native method call on screenMonitorChannel: ${call.method}');
    switch (call.method) {
      case 'onScreenContent':
        final content = call.arguments['content'] as String? ?? '';
        final packageName = call.arguments['packageName'] as String? ?? '';
        final x = call.arguments['x'] as double? ?? 0.0;
        final y = call.arguments['y'] as double? ?? 0.0;
        final width = call.arguments['width'] as double? ?? 0.0;
        final height = call.arguments['height'] as double? ?? 0.0;

        if (content.isNotEmpty &&
            _scamDetectionService != null &&
            _overlayService != null) {
          await _performRealTimeScamDetection(
              content, packageName, x, y, width, height);
        }
        break;
      case 'onAppChanged':
        await scanScreenForScams();
        break;
      default:
        debugPrint('Unknown method call: ${call.method}');
    }
  }

  Future<void> _performRealTimeScamDetection(String content, String packageName,
      double x, double y, double width, double height) async {
    try {
      final result = await _scamDetectionService!.scanMessage(content);

      if (result.isScam && result.alertLevel != AlertLevel.none) {
        String alertType = _getAlertType(result.alertLevel);
        String alertMessage = _formatAlertMessage(result, packageName);

        await _overlayService!.showScamOverlay(
          alertMessage,
          alertType,
          {
            'x': x,
            'y': y,
            'width': width,
            'height': height,
            'packageName': packageName,
            'content': content,
            'confidence': result.confidence,
            'scamTypes': result.scamTypes,
          },
        );

        await _alertUser(result.alertLevel);

        debugPrint(
            'BERT detected scam in $packageName: ${result.reason} (confidence: ${result.confidence})');
      }
    } catch (e) {
      debugPrint("Error in real-time scam detection: $e");
    }
  }

  String _getAlertType(AlertLevel level) {
    switch (level) {
      case AlertLevel.critical:
        return 'critical_blocking';
      case AlertLevel.high:
        return 'high_warning';
      case AlertLevel.medium:
        return 'medium_notice';
      case AlertLevel.none:
        return 'none';
    }
  }

  String _formatAlertMessage(ScamDetectionResult result, String packageName) {
    String emoji = _getAlertEmoji(result.alertLevel);
    String confidenceText = '${(result.confidence * 100).toInt()}%';

    switch (result.alertLevel) {
      case AlertLevel.critical:
        return '$emoji CRITICAL SCAM ALERT ($confidenceText confident)\n${result.reason}';
      case AlertLevel.high:
        return '$emoji WARNING: Potential Scam ($confidenceText confident)\n${result.reason}';
      case AlertLevel.medium:
        return '$emoji Suspicious Content ($confidenceText confident)\n${result.reason}';
      case AlertLevel.none:
        return '';
    }
  }

  String _getAlertEmoji(AlertLevel level) {
    switch (level) {
      case AlertLevel.critical:
        return '🚨';
      case AlertLevel.high:
        return '⚠️';
      case AlertLevel.medium:
        return '⚡';
      case AlertLevel.none:
        return '';
    }
  }

  Future<void> _alertUser(AlertLevel level) async {
    try {
      switch (level) {
        case AlertLevel.critical:
          await _appControlChannel
              .invokeMethod('vibrate', {'duration': 1000, 'pattern': 'urgent'});
          await _appControlChannel
              .invokeMethod('playAlertSound', {'type': 'critical'});
          break;
        case AlertLevel.high:
          await _appControlChannel
              .invokeMethod('vibrate', {'duration': 500, 'pattern': 'warning'});
          await _appControlChannel
              .invokeMethod('playAlertSound', {'type': 'warning'});
          break;
        case AlertLevel.medium:
          await _appControlChannel
              .invokeMethod('vibrate', {'duration': 200, 'pattern': 'gentle'});
          break;
        case AlertLevel.none:
          break;
      }
    } catch (e) {
      debugPrint("Error alerting user: $e");
    }
  }

  Future<void> scanScreenForScams() async {
    if (_scamDetectionService == null || _overlayService == null) return;
    try {
      final Map<String, dynamic>? screenData = await _screenMonitorChannel
          .invokeMethod('captureScreenWithTextPositions');

      if (screenData == null) return;

      final Uint8List? imageBytes = screenData['imageBytes'];
      final List<dynamic>? textBlocks = screenData['textBlocks'];

      if (imageBytes == null || textBlocks == null) return;

      for (final block in textBlocks) {
        final String text = block['text'] ?? '';
        final double x = block['x']?.toDouble() ?? 0.0;
        final double y = block['y']?.toDouble() ?? 0.0;
        final double width = block['width']?.toDouble() ?? 0.0;
        final double height = block['height']?.toDouble() ?? 0.0;

        if (text.isNotEmpty) {
          final result = await _scamDetectionService!.scanMessage(text);
          if (result.isScam) {
            await _overlayService!.showScamOverlay(
              "⚠️ SCAM DETECTED: ${result.reason}",
              "ocr_positioned",
              {
                'x': x,
                'y': y,
                'width': width,
                'height': height,
                'text': text,
              },
            );

            await _alertUser(result.alertLevel);
          }
        }
      }
    } catch (e) {
      debugPrint("Error in enhanced screen scanning: $e");
    }
  }

  Future<String?> extractTextFromImage(Uint8List imageBytes) async {
    try {
      final String? extractedText = await _ocrChannel.invokeMethod(
        'extractText',
        {'image': imageBytes},
      );
      return extractedText;
    } on PlatformException catch (e) {
      debugPrint("Failed to extract text: '${e.message}'.");
      return null;
    }
  }

  Future<bool> isAccessibilityServiceEnabled() async {
    try {
      final bool isEnabled = await _appControlChannel
          .invokeMethod('isAccessibilityServiceEnabled');
      return isEnabled;
    } on PlatformException catch (e) {
      debugPrint(
          "Failed to check accessibility service status: '${e.message}'.");
      return false;
    }
  }

  Future<void> openAccessibilitySettings() async {
    try {
      await _appControlChannel.invokeMethod('openAccessibilitySettings');
    } on PlatformException catch (e) {
      debugPrint("Failed to open accessibility settings: '${e.message}'.");
    }
  }

  Future<bool> requestScreenCapturePermission() async {
    try {
      final bool? granted = await _screenMonitorChannel
          .invokeMethod('requestScreenCapturePermission');
      return granted ?? false;
    } on PlatformException catch (e) {
      debugPrint(
          "Failed to request screen capture permission: '${e.message}'.");
      return false;
    }
  }

  Future<void> startRealtimeMonitoring() async {
    try {
      await _screenMonitorChannel.invokeMethod('startRealtimeMonitoring', {
        'scanInterval': 1000,
        'minTextLength': 10,
        'enablePositionTracking': true,
      });
      _isMonitoring = true;
      notifyListeners();
      debugPrint('Real-time scam monitoring started.');
    } on PlatformException catch (e) {
      debugPrint("Failed to start real-time monitoring: '${e.message}'.");
    }
  }

  Future<void> stopRealtimeMonitoring() async {
    try {
      await _screenMonitorChannel.invokeMethod('stopRealtimeMonitoring');
      _isMonitoring = false;
      notifyListeners();
      debugPrint('Real-time scam monitoring stopped.');
    } on PlatformException catch (e) {
      debugPrint("Failed to stop real-time monitoring: '${e.message}'.");
    }
  }

  @override
  void dispose() {
    stopRealtimeMonitoring();
    debugPrint('ScreenMonitorService disposed');
    super.dispose();
  }
}
