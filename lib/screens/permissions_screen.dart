// lib/screens/permissions_screen.dart
import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:provider/provider.dart';
import '../services/permissions_service.dart';
import '../services/real_contacts_service.dart';
import 'home_screen.dart';

class PermissionsScreen extends StatefulWidget {
  const PermissionsScreen({super.key});

  @override
  State<PermissionsScreen> createState() => _PermissionsScreenState();
}

class _PermissionsScreenState extends State<PermissionsScreen> {
  bool _isLoading = true;
  late PermissionsService _permissionsService;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _permissionsService = Provider.of<PermissionsService>(context, listen: false);
      _checkPermissions();
    });
  }

  Future<void> _checkPermissions() async {
    setState(() => _isLoading = true);

    try {
      await _permissionsService.checkAllPermissions();
      await _permissionsService.checkSpecialPermissions();
      await _permissionsService.getProtectionLevel();
    } catch (e) {
      debugPrint('Error checking permissions: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  void _continueToApp() {
    // Re-sync now that contacts permission is very likely granted (it wasn't
    // yet at app launch, when the first sync attempt ran)
    RealContactsService.instance.syncContacts();

    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (context) => const HomeScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<PermissionsService>(
      builder: (context, permissionsService, child) {
        final canContinue = !_isLoading && permissionsService.hasAllRequiredPermissions();
        
        return Scaffold(
          appBar: AppBar(
            title: const Text('Required Setup'),
            elevation: 0,
            centerTitle: true,
            actions: [
              IconButton(
                icon: const Icon(Icons.refresh),
                onPressed: _isLoading ? null : _checkPermissions,
                tooltip: 'Refresh permissions',
              ),
            ],
          ),
          body: _isLoading
              ? const Center(child: CircularProgressIndicator())
              : SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (!permissionsService.isAccessibilityEnabled)
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(16),
                          margin: const EdgeInsets.only(bottom: 20),
                          decoration: BoxDecoration(
                            color: Colors.red.withValues(alpha: 0.08),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: Colors.red.withValues(alpha: 0.4)),
                          ),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Icon(Icons.shield_outlined, color: Colors.red),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      "Without Accessibility, we can't protect you",
                                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                        fontWeight: FontWeight.bold,
                                        color: Colors.red.shade700,
                                      ),
                                    ),
                                    const SizedBox(height: 6),
                                    const Text(
                                      "This is how Elephas reads incoming WhatsApp, Telegram, and SMS messages to catch scams. "
                                      "No other permission can substitute for it — you won't be able to continue until it's turned on.",
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),

                      Text(
                        'Protection Level: ${permissionsService.protectionLevel}',
                        style: Theme.of(context).textTheme.headlineSmall,
                      ),
                      const SizedBox(height: 24),

                      Text(
                        'Required Permissions',
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 16),
                      ...permissionsService.permissions.entries.map((entry) {
                        final permission = entry.key;
                        final status = entry.value;


                        return ListTile(
                          title: Text(permission.toString().split('.').last),
                          subtitle: Text(status.toString().split('.').last),
                          trailing: status.isGranted 
                              ? const Icon(Icons.check_circle, color: Colors.green)
                              : TextButton(
                                  child: const Text('Grant'),
                                  onPressed: () async {
                                    await permission.request();
                                    await _checkPermissions();
                                  },
                                ),
                        );
                      }),

                      const SizedBox(height: 20),
                      
                      // Special Permissions Section
                      Text(
                        'Special Permissions',
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      const SizedBox(height: 10),
                      ...permissionsService.specialPermissions.entries.map((entry) {
                        return ListTile(
                          title: Text(entry.key),
                          subtitle: Text(entry.value ? 'Granted' : 'Not Granted'),
                          trailing: entry.value
                              ? const Icon(Icons.check_circle, color: Colors.green)
                              : TextButton(
                                  child: const Text('Enable'),
                                  onPressed: () async {
                                    switch (entry.key) {
                                      case 'accessibility':
                                        await permissionsService.openAccessibilitySettings();
                                        break;
                                      case 'systemAlertWindow':
                                        await permissionsService.openSystemAlertWindowSettings();
                                        break;
                                    }
                                    await _checkPermissions();
                                  },
                                ),
                        );
                      }),
                    ],
                  ),
                ),
          bottomNavigationBar: Container(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (!canContinue) 
                  ElevatedButton.icon(
                    onPressed: _isLoading ? null : () async {
                      setState(() => _isLoading = true);
                      for (var entry in permissionsService.permissions.entries) {
                        if (!entry.value.isGranted) {
                          await entry.key.request();
                        }
                      }
                      await _checkPermissions();
                    },
                    icon: _isLoading 
                        ? const SizedBox(
                            width: 20, 
                            height: 20, 
                            child: CircularProgressIndicator(strokeWidth: 2)
                          )
                        : const Icon(Icons.security),
                    label: Text(_isLoading ? 'Setting up...' : 'Grant All Permissions'),
                    style: ElevatedButton.styleFrom(
                      minimumSize: const Size(double.infinity, 48),
                    ),
                  ),
                if (!canContinue) const SizedBox(height: 8),
                ElevatedButton(
                  onPressed: canContinue ? _continueToApp : null,
                  child: const Text('Continue to App'),
                  style: ElevatedButton.styleFrom(
                    minimumSize: const Size(double.infinity, 48),
                    backgroundColor: canContinue ? Colors.blue : Colors.grey,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
