import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:provider/provider.dart';
import '../services/elephas_main_service.dart';
import './home_screen.dart';

/// A modern, user-friendly permissions request screen
class ModernPermissionsScreen extends StatefulWidget {
  const ModernPermissionsScreen({super.key});

  @override
  State<ModernPermissionsScreen> createState() => _ModernPermissionsScreenState();
}

class _ModernPermissionsScreenState extends State<ModernPermissionsScreen> {
  Map<Permission, bool> _permissionStatus = {
    Permission.sms: false,
    Permission.phone: false,
    Permission.notification: false,
    Permission.systemAlertWindow: false,
    Permission.contacts: false,
  };
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _checkPermissions();
  }

  Future<void> _checkPermissions() async {
    Map<Permission, bool> newStatus = {};
    
    for (var permission in _permissionStatus.keys) {
      final status = await permission.status;
      newStatus[permission] = status.isGranted;
    }

    if (mounted) {
      setState(() {
        _permissionStatus = newStatus;
      });
    }
  }

  Future<void> _requestPermissions() async {
    setState(() {
      _isLoading = true;
    });

    try {
      for (var permission in _permissionStatus.keys) {
        if (!(_permissionStatus[permission] ?? false)) {
          final status = await permission.request();
          if (mounted) {
            setState(() {
              _permissionStatus[permission] = status.isGranted;
            });
          }
          // Add a small delay between permission requests to avoid overwhelming the system
          await Future.delayed(const Duration(milliseconds: 500));
        }
      }
      // Request notification permission
      if (!(_permissionStatus[Permission.notification] ?? false)) {
        final status = await Permission.notification.request();
        setState(() {
          _permissionStatus[Permission.notification] = status.isGranted;
        });
      }

      // Request overlay permission
      if (!(_permissionStatus[Permission.systemAlertWindow] ?? false)) {
        final status = await Permission.systemAlertWindow.request();
        setState(() {
          _permissionStatus[Permission.systemAlertWindow] = status.isGranted;
        });
      }

      // If all permissions granted, initialize the service
      if (_permissionStatus.values.every((isGranted) => isGranted)) {
        if (!mounted) return;  // Check if widget is still in the tree
        final service = context.read<ElephasMainService>();
        await service.initialize();
        if (!mounted) return;  // Check again after async operation
        await service.startProtection();
      }

    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _requestSinglePermission(Permission permission) async {
    final status = await permission.request();
    if (mounted) {
      setState(() {
        _permissionStatus[permission] = status.isGranted;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 24),
              Image.asset(
                'assets/images/elephas_logo.png',
                height: 60,
              ),
              const SizedBox(height: 24),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Theme.of(context).cardColor,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.grey.shade300),
                ),
                child: Column(
                  children: [
                    Text(
                      'Permission Level',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _permissionStatus.values.every((granted) => granted) 
                          ? 'All Set!' 
                          : 'Action Required',
                      style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                        color: _permissionStatus.values.every((granted) => granted)
                            ? Colors.green
                            : Colors.orange,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              Text(
                'Required Permissions',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'To protect you from scams, we need a few permissions:',
                style: Theme.of(context).textTheme.bodyLarge,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 32),
              ..._permissionStatus.entries.map((entry) {
                final permission = entry.key;
                final isGranted = entry.value;
                
                String title;
                String description;
                IconData icon;

                switch (permission) {
                  case Permission.notification:
                    title = 'Notifications';
                    description = 'To alert you about potential scams';
                    icon = Icons.notifications_active_outlined;
                    break;
                  case Permission.systemAlertWindow:
                    title = 'Overlay';
                    description = 'To show real-time scam warnings';
                    icon = Icons.layers_outlined;
                    break;
                  case Permission.sms:
                    title = 'SMS Access';
                    description = 'To monitor messages for scams';
                    icon = Icons.sms_outlined;
                    break;
                  case Permission.phone:
                    title = 'Phone';
                    description = 'For call scam protection';
                    icon = Icons.phone_outlined;
                    break;
                  case Permission.contacts:
                    title = 'Contacts';
                    description = 'To identify trusted contacts';
                    icon = Icons.contacts_outlined;
                    break;
                  default:
                    title = permission.toString();
                    description = 'Required for full protection';
                    icon = Icons.security_outlined;
                }

                return Column(
                  children: [
                    _buildPermissionCard(
                      title: title,
                      description: description,
                      isGranted: isGranted,
                      icon: icon,
                    ),
                    const SizedBox(height: 16),
                  ],
                );
              }).toList(),
              const Spacer(),
              if (_permissionStatus.values.every((granted) => granted))
                FilledButton.icon(
                  onPressed: () async {
                    if (!mounted) return;
                    final service = context.read<ElephasMainService>();
                    await service.initialize();
                    if (!mounted) return;
                    await service.startProtection();
                    if (!mounted) return;
                    if (!mounted) return;
                    final nav = Navigator.of(context);
                    nav.pushReplacement(
                      MaterialPageRoute(builder: (context) => const HomeScreen()),
                    );
                  },
                  icon: const Icon(Icons.check_circle),
                  label: const Text('Continue to App'),
                  style: FilledButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                )
              else
                Column(
                  children: [
                    FilledButton.icon(
                      onPressed: _isLoading ? null : _requestPermissions,
                      icon: _isLoading 
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                              ),
                            )
                          : const Icon(Icons.shield),
                      label: Text(_isLoading ? 'Setting up...' : 'Grant All Permissions'),
                      style: FilledButton.styleFrom(
                        backgroundColor: Colors.blue,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextButton(
                      onPressed: () async {
                        await openAppSettings();
                      },
                      child: const Text('Open Settings'),
                    ),
                  ],
                ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.grey.shade50,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.grey.shade200),
                ),
                child: const Row(
                  children: [
                    Icon(
                      Icons.security,
                      color: Colors.grey,
                      size: 20,
                    ),
                    SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        '🛡️ Your privacy is our priority. We only monitor messages to protect you from scams.',
                        style: TextStyle(
                          color: Colors.grey,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPermissionCard({
    required String title,
    required String description,
    required bool isGranted,
    required IconData icon,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: isGranted ? Colors.green.withValues(alpha: 13) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isGranted ? Colors.green.shade300 : Colors.grey.shade300,
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 8),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: isGranted ? null : () => _requestSinglePermission(_permissionStatus.entries.firstWhere((e) => e.value == false).key),
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: isGranted ? Colors.green.withValues(alpha: 26) : Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    icon,
                    size: 24,
                    color: isGranted ? Colors.green : Colors.grey.shade700,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        description,
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey.shade600,
                        ),
                      ),
                    ],
                  ),
                ),
                if (!isGranted)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.blue.shade50,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      'Grant',
                      style: TextStyle(
                        color: Colors.blue.shade700,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  )
                else
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.green.withValues(alpha: 26),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.check_circle,
                      color: Colors.green,
                      size: 20,
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
