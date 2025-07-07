import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart';

class NotificationListenerService {
  static const MethodChannel _channel =
      MethodChannel('elephas_ai/notifications');

  static Future<bool> requestNotificationAccess() async {
    try {
      return await _channel.invokeMethod('requestNotificationAccess') ?? false;
    } catch (e) {
      debugPrint('Error requesting notification access: $e');
      return false;
    }
  }

  static Future<bool> hasNotificationAccess() async {
    try {
      return await _channel.invokeMethod('hasNotificationAccess') ?? false;
    } catch (e) {
      return false;
    }
  }

  static Future<void> startListening() async {
    try {
      await _channel.invokeMethod('startListening');
    } catch (e) {
      debugPrint('Error starting notification listener: $e');
    }
  }
}
