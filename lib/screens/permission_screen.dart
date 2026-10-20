import 'package:flutter/material.dart';
import 'package:elephas_ai/services/permission_service.dart';
import 'package:elephas_ai/screens/home_screen.dart';

class PermissionScreen extends StatefulWidget {
  const PermissionScreen({super.key});

  @override
  State<PermissionScreen> createState() => _PermissionScreenState();
}

class _PermissionScreenState extends State<PermissionScreen> {
  final PermissionService _permissionService = PermissionService();

  bool _hasOverlayPermission = false;
  bool _hasNotificationAccess = false;
  bool _hasAccessibilityServiceEnabled = false;
  bool _isCheckingPermissions = true;

  @override
  void initState() {
    super.initState();
    _checkPermissions();
  }

  Future<void> _checkPermissions() async {
    setState(() => _isCheckingPermissions = true);

    final hasOverlay = await _permissionService.hasOverlayPermission();
    final hasNotification =
        await _permissionService.hasNotificationPermission();
    final hasAccessibility =
        await _permissionService.hasAccessibilityPermission();

    if (mounted) {
      setState(() {
        _hasOverlayPermission = hasOverlay;
        _hasNotificationAccess = hasNotification;
        _hasAccessibilityServiceEnabled = hasAccessibility;
        _isCheckingPermissions = false;
      });

      // If all permissions are granted, navigate to home screen
      if (hasOverlay && hasNotification && hasAccessibility) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (context) => const HomeScreen()),
        );
      }
    }
  }

  Future<void> _requestPermission(String permissionType) async {
    try {
      switch (permissionType) {
        case 'overlay':
          await _permissionService.requestOverlayPermission(context);
          break;
        case 'notification':
          await _permissionService.requestNotificationPermission(context);
          break;
        case 'accessibility':
          await _permissionService.requestAccessibilityPermission(context);
          break;
      }

      // Wait a bit for the user to grant the permission
      await Future.delayed(const Duration(seconds: 1));
      await _checkPermissions();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Could not open settings: ${e.toString()}'),
            duration: const Duration(seconds: 3),
          ),
        );
      }
    }
  }

  Widget _buildPermissionCard({
    required String title,
    required String description,
    required IconData icon,
    required bool isGranted,
    required VoidCallback onRequest,
  }) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: ListTile(
        contentPadding: const EdgeInsets.all(16),
        leading: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: isGranted
                ? Colors.green.withAlpha(25)
                : Colors.blue.withAlpha(25),
            shape: BoxShape.circle,
          ),
          child: Icon(
            isGranted ? Icons.check_circle : icon,
            color: isGranted ? Colors.green : Colors.blue,
            size: 24,
          ),
        ),
        title: Text(
          title,
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 8),
            Text(
              description,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 12),
            if (!isGranted)
              ElevatedButton(
                onPressed: onRequest,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue,
                  foregroundColor: Colors.white,
                ),
                child: Text(isGranted ? 'Granted' : 'Enable'),
              ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Required Permissions'),
        centerTitle: true,
      ),
      body: _isCheckingPermissions
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _checkPermissions,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.symmetric(vertical: 16),
                child: Column(
                  children: [
                    const Padding(
                      padding: EdgeInsets.all(16),
                      child: Text(
                        'Elephas AI needs the following permissions to protect you from scams:',
                        style: TextStyle(fontSize: 16),
                        textAlign: TextAlign.center,
                      ),
                    ),
                    _buildPermissionCard(
                      title: 'Display Over Apps',
                      description:
                          'Allows Elephas AI to show alerts when potential scams are detected in your messages.',
                      icon: Icons.layers,
                      isGranted: _hasOverlayPermission,
                      onRequest: () => _requestPermission('overlay'),
                    ),
                    _buildPermissionCard(
                      title: 'Notifications',
                      description:
                          'Enables alerts and keeps you informed about the app\'s protection status.',
                      icon: Icons.notifications,
                      isGranted: _hasNotificationAccess,
                      onRequest: () => _requestPermission('notification'),
                    ),
                    _buildPermissionCard(
                      title: 'Accessibility Service',
                      description:
                          'Required to analyze messages in real-time and protect you from scams. This service is secure and respects your privacy.',
                      icon: Icons.security,
                      isGranted: _hasAccessibilityServiceEnabled,
                      onRequest: () => _requestPermission('accessibility'),
                    ),
                    if (!_hasOverlayPermission ||
                        !_hasNotificationAccess ||
                        !_hasAccessibilityServiceEnabled)
                      const Padding(
                        padding: EdgeInsets.all(16),
                        child: Text(
                          'Please enable all permissions to start protecting your messages from scams.',
                          style: TextStyle(
                            color: Colors.grey,
                            fontStyle: FontStyle.italic,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                  ],
                ),
              ),
            ),
    );
  }
}
