import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:permission_handler/permission_handler.dart';

class PermissionService {
  static const platform =
      MethodChannel('com.example.scamshield_flutter_app/accessibility');

  Future<bool> hasAllPermissions() async {
    final hasOverlay = await hasOverlayPermission();
    final hasNotification = await hasNotificationPermission();
    final hasAccessibility = await hasAccessibilityPermission();
    return hasOverlay && hasNotification && hasAccessibility;
  }

  Future<bool> hasOverlayPermission() async {
    return await Permission.systemAlertWindow.isGranted;
  }

  Future<bool> hasNotificationPermission() async {
    return await Permission.notification.isGranted;
  }

  Future<bool> hasAccessibilityPermission() async {
    try {
      final bool isEnabled =
          await platform.invokeMethod('isAccessibilityEnabled');
      return isEnabled;
    } on PlatformException catch (_) {
      return false;
    }
  }

  Future<void> requestOverlayPermission(BuildContext context) async {
    final status = await Permission.systemAlertWindow.status;

    if (status.isDenied) {
      final result = await Permission.systemAlertWindow.request();
      if (result.isGranted) return;
    }

    if (!context.mounted) return;

    // If still not granted, show a dialog explaining why we need it
    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text('Overlay Permission Required'),
        content: const Text(
          'Elephas AI needs permission to display alerts when potential scams are detected. '
          'Please enable "Display over other apps" in Settings.',
        ),
        actions: [
          TextButton(
            child: const Text('Later'),
            onPressed: () => Navigator.of(context).pop(),
          ),
          FilledButton(
            child: const Text('Open Settings'),
            onPressed: () async {
              Navigator.of(context).pop();
              await openAppSettings();
            },
          ),
        ],
      ),
    );
  }

  Future<void> requestNotificationPermission(BuildContext context) async {
    final status = await Permission.notification.status;

    if (status.isDenied) {
      final result = await Permission.notification.request();
      if (result.isGranted) return;
    }

    if (!context.mounted) return;

    // If still not granted, show a dialog explaining why we need it
    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text('Notification Permission Required'),
        content: const Text(
          'Elephas AI needs notification permission to alert you about potential scams '
          'and keep you informed about its protection status.',
        ),
        actions: [
          TextButton(
            child: const Text('Later'),
            onPressed: () => Navigator.of(context).pop(),
          ),
          FilledButton(
            child: const Text('Open Settings'),
            onPressed: () async {
              Navigator.of(context).pop();
              await openAppSettings();
            },
          ),
        ],
      ),
    );
  }

  Future<void> requestAccessibilityPermission(BuildContext context) async {
    final bool hasPermission = await hasAccessibilityPermission();
    if (hasPermission) return;

    if (!context.mounted) return;

    // Show a detailed dialog with visual aids and clear instructions
    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text('Enable Protection Service'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Elephas AI needs accessibility service to protect you from scams '
                'by analyzing messages in real-time.',
                style: TextStyle(fontSize: 16),
              ),
              const SizedBox(height: 16),
              const Text(
                'To enable:',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildStep(1, 'Tap "Open Settings" below'),
                      _buildStep(2, 'Find "Installed Services"'),
                      _buildStep(3, 'Select "Elephas AI"'),
                      _buildStep(4, 'Toggle the switch to ON'),
                      _buildStep(5, 'Tap "ALLOW" on the permission dialog'),
                      _buildStep(6, 'Return to Elephas AI'),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'Note: This service only monitors messaging apps for your protection '
                'and does not interfere with other accessibility services.',
                style: TextStyle(fontStyle: FontStyle.italic),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            child: const Text('Later'),
            onPressed: () => Navigator.of(context).pop(),
          ),
          FilledButton.icon(
            icon: const Icon(Icons.settings),
            label: const Text('Open Settings'),
            onPressed: () async {
              Navigator.of(context).pop();
              try {
                // Try to open accessibility settings directly
                const String accessibilitySettings =
                    'android.settings.ACCESSIBILITY_SETTINGS';
                await platform.invokeMethod('openAccessibilitySettings',
                    {'settings': accessibilitySettings});
              } catch (e) {
                // Fallback to general settings if direct navigation fails
                await openAppSettings();
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text(
                          'Please find and enable Elephas AI in Accessibility Services'),
                      duration: Duration(seconds: 5),
                    ),
                  );
                }
              }
            },
          ),
        ],
      ),
    );
  }

  Widget _buildStep(int number, String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            margin: const EdgeInsets.only(right: 8),
            padding: const EdgeInsets.all(6),
            decoration: const BoxDecoration(
              color: Colors.blue,
              shape: BoxShape.circle,
            ),
            child: Text(
              number.toString(),
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 12,
              ),
            ),
          ),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(fontSize: 14),
            ),
          ),
        ],
      ),
    );
  }
}
