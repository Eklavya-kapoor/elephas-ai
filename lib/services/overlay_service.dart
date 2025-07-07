// lib/services/overlay_service.dart
import 'package:flutter/material.dart'; // For @required and debugPrint, etc.
import 'package:flutter/services.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:flutter/foundation.dart'; // IMPORTANT: Add this import

// Make OverlayService extend ChangeNotifier
class OverlayService extends ChangeNotifier {
  static const MethodChannel _overlayChannel =
      MethodChannel('elephas_ai/overlay');
  static const MethodChannel _notificationChannel =
      MethodChannel('elephas_ai/notifications');

  bool _isInitialized = false;
  bool _isVisible = false;

  bool get isInitialized => _isInitialized;
  bool get isVisible => _isVisible;

  // Constructor (optional, but good for initialization)
  OverlayService() {
    _initMethodCallHandler();
  }

  void initialize() {
    debugPrint("OverlayService Initialized");
    // Any other setup logic that needs to run on init
  }

  // Handle incoming method calls from the native side
  void _initMethodCallHandler() {
    _overlayChannel.setMethodCallHandler((call) async {
      switch (call.method) {
        case 'onScamDetected':
          final String? message = call.arguments['message'];
          final String? detectedType = call.arguments['detectedType'];
          final String? scamNumber =
              call.arguments['scamNumber']; // For calls/SMS
          debugPrint(
              'Native: Scam Detected! Type: $detectedType, Message: $message, Number: $scamNumber');
          // You might want to update some state here and notify listeners
          // For now, let's just show the overlay
          await showScamOverlay(
              message ?? 'Unknown scam detected!',
              detectedType ?? 'unknown',
              scamNumber != null ? {'scamNumber': scamNumber} : null);
          break;
        case 'onNotificationIntercepted':
          final String? packageName = call.arguments['packageName'];
          final String? title = call.arguments['title'];
          final String? text = call.arguments['text'];
          debugPrint(
              'Native: Notification Intercepted! Package: $packageName, Title: $title, Text: $text');
          // Process notification for scams, then potentially show overlay
          // For simplicity, let's just show a toast for now
          Fluttertoast.showToast(
              msg: "Notification Intercepted: $title - $text");
          break;
        case 'onIncomingSms':
          final String? sender = call.arguments['sender'];
          final String? messageBody = call.arguments['messageBody'];
          debugPrint(
              'Native: Incoming SMS! Sender: $sender, Message: $messageBody');
          // Process SMS for scams, then potentially show overlay
          Fluttertoast.showToast(msg: "New SMS from $sender: $messageBody");
          break;
        case 'onIncomingCall':
          final String? phoneNumber = call.arguments['phoneNumber'];
          final int? callState =
              call.arguments['callState']; // 1=RINGING, 2=OFFHOOK, 0=IDLE
          debugPrint(
              'Native: Incoming Call! Number: $phoneNumber, State: $callState');
          // Process call for scams, then potentially show overlay
          Fluttertoast.showToast(
              msg: "Incoming call from $phoneNumber (State: $callState)");
          break;
        default:
          debugPrint('Unknown method: ${call.method}');
      }
    });
  }

  Future<void> initializeService() async {
    try {
      await _overlayChannel.invokeMethod('initialize');
      _isInitialized = true;
      notifyListeners();
      debugPrint('Overlay service initialized.');
    } on PlatformException catch (e) {
      debugPrint("Failed to initialize overlay service: '${e.message}'.");
      Fluttertoast.showToast(
          msg: "Error initializing overlay service: ${e.message}");
    }
  }

  Future<void> showScamOverlay(String message, String? alertType,
      Map<String, dynamic>? extraData) async {
    try {
      final Map<String, dynamic> params = {
        'message': message,
        'alertType': alertType ?? 'unknown',
      };

      if (extraData != null) {
        params.addAll(extraData);
      }

      await _overlayChannel.invokeMethod('showOverlay', params);
      _isVisible = true;
      notifyListeners();
      debugPrint('Overlay shown successfully.');
    } on PlatformException catch (e) {
      debugPrint("Failed to show overlay: '${e.message}'.");
      Fluttertoast.showToast(msg: "Error showing overlay: ${e.message}");
    }
  }

  Future<void> hideScamOverlay() async {
    try {
      await _overlayChannel.invokeMethod('hideOverlay');
      _isVisible = false;
      notifyListeners();
      debugPrint('Overlay hidden successfully.');
    } on PlatformException catch (e) {
      debugPrint("Failed to hide overlay: '${e.message}'.");
    }
  }

  // Permission checks and requests
  Future<bool> hasOverlayPermission() async {
    final status = await Permission.systemAlertWindow.status;
    return status.isGranted;
  }

  Future<void> openDrawOverlaysSettings() async {
    try {
      await _overlayChannel.invokeMethod('openDrawOverlaysSettings');
    } on PlatformException catch (e) {
      debugPrint("Failed to open overlay settings: '${e.message}'.");
      // Fallback for older Android versions or if method fails
      if (await canLaunchUrl(Uri.parse('package:com.android.settings'))) {
        launchUrl(Uri.parse('package:com.android.settings'));
      }
    }
  }

  Future<bool> hasNotificationAccess() async {
    try {
      final bool hasAccess =
          await _notificationChannel.invokeMethod('hasNotificationAccess');
      return hasAccess;
    } on PlatformException catch (e) {
      debugPrint("Failed to check notification access: '${e.message}'.");
      return false;
    }
  }

  Future<void> openNotificationListenerSettings() async {
    try {
      await _notificationChannel
          .invokeMethod('openNotificationListenerSettings');
    } on PlatformException catch (e) {
      debugPrint(
          "Failed to open notification listener settings: '${e.message}'.");
      // Fallback
      if (await canLaunchUrl(Uri.parse('package:com.android.settings'))) {
        launchUrl(Uri.parse('package:com.android.settings'));
      }
    }
  }

  @override
  void dispose() {
    // Perform any cleanup here if necessary, e.g., unregistering listeners
    debugPrint("OverlayService Disposed");
    super.dispose();
  }
}
