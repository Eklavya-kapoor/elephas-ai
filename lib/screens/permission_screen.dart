// lib/screens/permission_screen.dart
import 'package:flutter/material.dart';
import 'package:elephas_ai/services/overlay_service.dart';
import 'package:elephas_ai/services/screen_monitor_service.dart';
import 'package:fluttertoast/fluttertoast.dart'; // Make sure this is added to pubspec.yaml and you ran flutter pub get

// Import HomeScreen as well, as it's navigated to from here
import 'package:elephas_ai/screens/home_screen.dart';

class PermissionScreen extends StatefulWidget {
  // Ensure this constructor is const, as previously discussed
  const PermissionScreen({super.key});

  @override
  State<PermissionScreen> createState() => _PermissionScreenState();
}

class _PermissionScreenState extends State<PermissionScreen> {
  final OverlayService _overlayService = OverlayService();
  final ScreenMonitorService _screenMonitorService = ScreenMonitorService();

  bool _hasOverlayPermission = false;
  bool _hasNotificationAccess = false;
  bool _hasAccessibilityServiceEnabled = false;

  @override
  void initState() {
    super.initState();
    _checkPermissions();
  }

  Future<void> _checkPermissions() async {
    _hasOverlayPermission = await _overlayService.hasOverlayPermission();
    _hasNotificationAccess = await _overlayService
        .hasNotificationAccess(); // Placeholder for actual check
    _hasAccessibilityServiceEnabled = await _screenMonitorService
        .isAccessibilityServiceEnabled(); // Placeholder for actual check
    setState(() {});
  }

  Future<void> _requestPermission(String permissionType) async {
    switch (permissionType) {
      case 'overlay':
        await _overlayService.openDrawOverlaysSettings();
        break;
      case 'notification':
        await _overlayService.openNotificationListenerSettings();
        break;
      case 'accessibility':
        await _screenMonitorService.openAccessibilitySettings();
        break;
      case 'screen_capture':
        final granted =
            await _screenMonitorService.requestScreenCapturePermission();
        if (granted) {
          Fluttertoast.showToast(msg: "Screen capture permission granted!");
        } else {
          Fluttertoast.showToast(msg: "Screen capture permission denied.");
        }
        break;
    }
    // Give user time to grant permission, then recheck
    // It's good practice to show a toast or dialog here instructing the user
    // to grant the permission and return to the app.
    Fluttertoast.showToast(
        msg: "Please grant permission in settings and return to app.");
    Future.delayed(const Duration(seconds: 2), () => _checkPermissions());
  }

  @override
  Widget build(BuildContext context) {
    bool allPermissionsGranted = _hasOverlayPermission &&
        _hasNotificationAccess &&
        _hasAccessibilityServiceEnabled;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Permissions Required'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Elephas AI needs the following permissions to protect you in real-time:',
              style: TextStyle(fontSize: 16),
            ),
            const SizedBox(height: 20),
            _buildPermissionRow(
              'Draw Over Other Apps',
              _hasOverlayPermission,
              () => _requestPermission('overlay'),
              'Allows Elephas AI to show scam alerts on top of other apps.',
            ),
            _buildPermissionRow(
              'Notification Access',
              _hasNotificationAccess,
              () => _requestPermission('notification'),
              'Allows Elephas AI to analyze incoming notifications (e.g., messages) for scams.',
            ),
            _buildPermissionRow(
              'Accessibility Service',
              _hasAccessibilityServiceEnabled,
              () => _requestPermission('accessibility'),
              'Allows Elephas AI to monitor screen content in messaging apps for potential scams.',
            ),
            _buildPermissionRow(
              'Screen Capture',
              true, // This is requested on demand, not a persistent setting.
              () => _requestPermission('screen_capture'),
              'Required for one-time screen analysis for advanced checks.',
            ),
            const SizedBox(height: 30),
            if (allPermissionsGranted)
              Center(
                child: Column(
                  children: [
                    const Text(
                      'All necessary permissions granted!',
                      style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.green),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 20),
                    ElevatedButton(
                      onPressed: () {
                        Navigator.of(context).pushReplacement(
                          MaterialPageRoute(
                              builder: (context) => const HomeScreen()),
                        );
                      },
                      child: const Text('Continue to App'),
                    ),
                  ],
                ),
              )
            else
              const Center(
                child: Text(
                  'Please grant all required permissions to proceed.',
                  style: TextStyle(fontSize: 16, color: Colors.red),
                  textAlign: TextAlign.center,
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildPermissionRow(
      String title, bool granted, VoidCallback onPressed, String description) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                      fontSize: 16, fontWeight: FontWeight.bold),
                ),
                Text(
                  description,
                  style: const TextStyle(fontSize: 12, color: Colors.grey),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          ElevatedButton(
            onPressed: granted ? null : onPressed, // Disable button if granted
            style: ElevatedButton.styleFrom(
              backgroundColor: granted ? Colors.green : Colors.blue,
            ),
            child: Text(granted ? 'Granted' : 'Grant'),
          ),
        ],
      ),
    );
  }
}
