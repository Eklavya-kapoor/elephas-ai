import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:provider/provider.dart';
import '../services/elephas_main_service.dart';
import 'main_screen.dart';

class DetailedPermissionsScreen extends StatefulWidget {
  const DetailedPermissionsScreen({super.key});

  @override
  State<DetailedPermissionsScreen> createState() => _DetailedPermissionsScreenState();
}

class _DetailedPermissionsScreenState extends State<DetailedPermissionsScreen>
    with TickerProviderStateMixin {
  late AnimationController _fadeController;
  late Animation<double> _fadeAnimation;
  
  Map<Permission, PermissionStatus> _permissions = {};
  Map<String, bool> _specialPermissions = {};
  bool _isLoading = true;
  bool _isGrantingPermissions = false;
  int _grantedCount = 0;
  final int _totalPermissions = 8; // Total permissions needed

  @override
  void initState() {
    super.initState();
    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
    
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _fadeController, curve: Curves.easeOut),
    );
    
    _checkAllPermissions();
    _fadeController.forward();
  }

  @override
  void dispose() {
    _fadeController.dispose();
    super.dispose();
  }

  Future<void> _checkAllPermissions() async {
    setState(() {
      _isLoading = true;
    });

    try {
      // Check basic permissions
      final permissions = await [
        Permission.sms,
        Permission.phone,
        Permission.notification,
        Permission.storage,
        Permission.systemAlertWindow,
        Permission.microphone,
      ].request();

      // Check special permissions
      const MethodChannel channel = MethodChannel('com.example.elephas_flutter_app/permissions');
      Map<String, bool> specialPermissions = {};
      try {
        specialPermissions['accessibility'] = await channel.invokeMethod('checkAccessibilityPermission') ?? false;
        specialPermissions['notificationListener'] = await channel.invokeMethod('checkNotificationListenerPermission') ?? false;
      } catch (e) {
        debugPrint('Error checking special permissions: $e');
        specialPermissions['accessibility'] = false;
        specialPermissions['notificationListener'] = false;
      }

      // Count granted permissions
      int grantedCount = 0;
      for (var status in permissions.values) {
        if (status == PermissionStatus.granted) grantedCount++;
      }
      for (var granted in specialPermissions.values) {
        if (granted) grantedCount++;
      }

      setState(() {
        _permissions = permissions;
        _specialPermissions = specialPermissions;
        _grantedCount = grantedCount;
        _isLoading = false;
      });

      // Auto-navigate if all permissions are granted
      if (_grantedCount >= 7) { // At least 7 out of 8 for good protection
        _navigateToMain();
      }
    } catch (e) {
      debugPrint('Error checking permissions: $e');
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _requestAllPermissions() async {
    setState(() {
      _isGrantingPermissions = true;
    });

    try {
      // Request basic permissions
      await [
        Permission.sms,
        Permission.phone,
        Permission.notification,
        Permission.storage,
        Permission.systemAlertWindow,
        Permission.microphone,
      ].request();

      // Request special permissions
      const MethodChannel channel = MethodChannel('com.example.elephas_flutter_app/permissions');
      try {
        await channel.invokeMethod('requestAccessibilityPermission');
        await channel.invokeMethod('requestNotificationListenerPermission');
      } catch (e) {
        debugPrint('Error requesting special permissions: $e');
      }

      // Re-check all permissions
      await _checkAllPermissions();
    } catch (e) {
      debugPrint('Error requesting permissions: $e');
    } finally {
      setState(() {
        _isGrantingPermissions = false;
      });
    }
  }

  void _navigateToMain() {
    Future.delayed(const Duration(milliseconds: 1000), () async {
      if (mounted) {
        // Initialize and start Elephas AI protection
        try {
          final elephasService = Provider.of<ElephasMainService>(context, listen: false);
          await elephasService.initializeWithServices(context);
          await elephasService.startProtection();
          debugPrint('🟢 [DetailedPermissionsScreen] Elephas AI protection started');
          
          // Start native background monitoring service
          const MethodChannel appControlChannel = MethodChannel('elephas_ai/app_control');
          try {
            await appControlChannel.invokeMethod('startBackgroundMonitoringService');
            debugPrint('🟢 [DetailedPermissionsScreen] Background monitoring service started');
          } on PlatformException catch (e) {
            debugPrint("Failed to start background monitoring service: '${e.message}'.");
          }
        } catch (e) {
          debugPrint('⚠️ [DetailedPermissionsScreen] Error starting protection: $e');
        }

        if (!mounted) return;
        
        Navigator.of(context).pushReplacement(
          PageRouteBuilder(
            pageBuilder: (context, animation, secondaryAnimation) => const MainScreen(),
            transitionsBuilder: (context, animation, secondaryAnimation, child) {
              return FadeTransition(opacity: animation, child: child);
            },
            transitionDuration: const Duration(milliseconds: 600),
          ),
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Color(0xFF4F46E5),
              Color(0xFF7C3AED),
              Color(0xFF9333EA),
            ],
          ),
        ),
        child: SafeArea(
          child: FadeTransition(
            opacity: _fadeAnimation,
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                children: [
                  const SizedBox(height: 20),
                  
                  // Header
                  Column(
                    children: [
                      Container(
                        width: 100,
                        height: 100,
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.2),
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: Colors.white.withValues(alpha: 0.3),
                            width: 2,
                          ),
                        ),
                        child: const Icon(
                          Icons.security,
                          size: 50,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 16),
                      const Text(
                        'Elephas AI Setup',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 28,
                          fontWeight: FontWeight.bold,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Grant permissions for complete protection',
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.9),
                          fontSize: 16,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                  
                  const SizedBox(height: 30),
                  
                  // Permission Status Overview
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.2),
                      ),
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 60,
                          height: 60,
                          decoration: BoxDecoration(
                            color: _grantedCount >= 7 
                                ? Colors.green.withValues(alpha: 0.2)
                                : Colors.orange.withValues(alpha: 0.2),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            _grantedCount >= 7 ? Icons.check_circle : Icons.warning,
                            color: _grantedCount >= 7 ? Colors.green : Colors.orange,
                            size: 30,
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '$_grantedCount of $_totalPermissions Permissions Granted',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              Text(
                                _grantedCount >= 7 
                                    ? 'Great! Almost ready to protect you'
                                    : 'More permissions needed for full protection',
                                style: TextStyle(
                                  color: Colors.white.withValues(alpha: 0.8),
                                  fontSize: 14,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  
                  const SizedBox(height: 24),
                  
                  // Permissions List
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.1),
                            blurRadius: 20,
                            offset: const Offset(0, 8),
                          ),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Required Permissions',
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF1F2937),
                            ),
                          ),
                          const SizedBox(height: 16),
                          
                          if (_isLoading)
                            const Expanded(
                              child: Center(
                                child: CircularProgressIndicator(),
                              ),
                            )
                          else
                            Expanded(
                              child: ListView(
                                children: [
                                  _buildPermissionItem(
                                    'Messages & SMS',
                                    'Monitor SMS for scam detection',
                                    _permissions[Permission.sms] == PermissionStatus.granted,
                                    Icons.message,
                                    Colors.blue,
                                  ),
                                  _buildPermissionItem(
                                    'Phone',
                                    'Detect scam calls (currently disabled)',
                                    _permissions[Permission.phone] == PermissionStatus.granted,
                                    Icons.phone,
                                    Colors.green,
                                  ),
                                  _buildPermissionItem(
                                    'Notifications',
                                    'Send scam alerts to you',
                                    _permissions[Permission.notification] == PermissionStatus.granted,
                                    Icons.notifications,
                                    Colors.orange,
                                  ),
                                  _buildPermissionItem(
                                    'Storage',
                                    'Store protection data locally',
                                    _permissions[Permission.storage] == PermissionStatus.granted,
                                    Icons.storage,
                                    Colors.purple,
                                  ),
                                  _buildPermissionItem(
                                    'System Overlay',
                                    'Show scam alerts over apps',
                                    _permissions[Permission.systemAlertWindow] == PermissionStatus.granted,
                                    Icons.layers,
                                    Colors.red,
                                  ),
                                  _buildPermissionItem(
                                    'Microphone',
                                    'For voice-based scam detection (optional)',
                                    _permissions[Permission.microphone] == PermissionStatus.granted,
                                    Icons.mic,
                                    Colors.teal,
                                  ),
                                  _buildPermissionItem(
                                    'Accessibility Service',
                                    'Monitor messaging apps (WhatsApp, Telegram)',
                                    _specialPermissions['accessibility'] ?? false,
                                    Icons.accessibility,
                                    Colors.indigo,
                                  ),
                                  _buildPermissionItem(
                                    'Notification Access',
                                    'Read notifications for scam detection',
                                    _specialPermissions['notificationListener'] ?? false,
                                    Icons.notifications_active,
                                    Colors.pink,
                                  ),
                                ],
                              ),
                            ),
                          
                          const SizedBox(height: 20),
                          
                          // Action Button
                          if (_grantedCount >= 7)
                            SizedBox(
                              width: double.infinity,
                              height: 56,
                              child: ElevatedButton(
                                onPressed: _navigateToMain,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFF10B981),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(16),
                                  ),
                                  elevation: 0,
                                ),
                                child: const Text(
                                  'Start Protection',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            )
                          else
                            SizedBox(
                              width: double.infinity,
                              height: 56,
                              child: ElevatedButton(
                                onPressed: _isGrantingPermissions ? null : _requestAllPermissions,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFF4F46E5),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(16),
                                  ),
                                  elevation: 0,
                                ),
                                child: _isGrantingPermissions
                                    ? const SizedBox(
                                        width: 24,
                                        height: 24,
                                        child: CircularProgressIndicator(
                                          color: Colors.white,
                                          strokeWidth: 2,
                                        ),
                                      )
                                    : const Text(
                                        'Grant All Permissions',
                                        style: TextStyle(
                                          color: Colors.white,
                                          fontSize: 18,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                              ),
                            ),
                          
                          const SizedBox(height: 12),
                          Text(
                            'Note: Call monitoring is disabled. Only messaging apps are monitored.',
                            style: TextStyle(
                              color: Colors.grey.shade600,
                              fontSize: 12,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPermissionItem(
    String title,
    String description,
    bool isGranted,
    IconData icon,
    Color color,
  ) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isGranted 
            ? Colors.green.withValues(alpha: 0.05)
            : Colors.red.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isGranted 
              ? Colors.green.withValues(alpha: 0.2)
              : Colors.red.withValues(alpha: 0.2),
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              icon,
              color: color,
              size: 20,
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
                    color: Color(0xFF1F2937),
                  ),
                ),
                Text(
                  description,
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey.shade600,
                  ),
                ),
              ],
            ),
          ),
          Icon(
            isGranted ? Icons.check_circle : Icons.cancel,
            color: isGranted ? Colors.green : Colors.red,
            size: 24,
          ),
        ],
      ),
    );
  }
}
