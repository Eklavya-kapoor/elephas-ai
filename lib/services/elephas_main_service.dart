import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:provider/provider.dart';
import 'screen_monitor_service.dart';
import 'scam_detection_service.dart';
import 'overlay_service.dart';
import 'sms_monitor_service.dart';
import '../config/app_config.dart';

/// Main Elephas AI service that provides easy integration for your app
class ElephasMainService extends ChangeNotifier {
  static ElephasMainService? _instance;
  static ElephasMainService get instance =>
      _instance ??= ElephasMainService._();

  ElephasMainService._();

  bool _isInitialized = false;
  bool _isActive = false;
  bool _backendConnected = false;

  // Service references
  ScreenMonitorService? _screenMonitorService;
  SmartScamDetectionService? _scamDetectionService;
  OverlayService? _overlayService;
  SmsMonitorService? _smsMonitorService;

  /// Initialize Elephas with service references from context
  Future<void> initializeWithServices(BuildContext context) async {
    if (_isInitialized) return;

    debugPrint('🟢 [ElephasMainService] Initializing with services...');

    try {
      // Get service references from Provider
      _scamDetectionService =
          Provider.of<SmartScamDetectionService>(context, listen: false);
      _overlayService = Provider.of<OverlayService>(context, listen: false);
      _screenMonitorService =
          Provider.of<ScreenMonitorService>(context, listen: false);
      _smsMonitorService =
          Provider.of<SmsMonitorService>(context, listen: false);

      // Initialize scam detection service
      await _scamDetectionService?.initialize();

      // Screen monitoring is initialized through constructor

      // Request SMS permissions
      await _smsMonitorService?.requestPermissions();

      _isInitialized = true;
      notifyListeners();

      debugPrint(
          '🟢 [ElephasMainService] All services initialized and connected');
    } catch (e) {
      debugPrint('❌ [ElephasMainService] Failed to initialize services: $e');
      rethrow;
    }
  }

  /// Initialize Elephas (legacy method)
  Future<void> initialize() async {
    if (_isInitialized) return;

    debugPrint('🟢 [ElephasMainService] Basic initialization...');

    // Basic initialization without services
    await Future.delayed(const Duration(milliseconds: 100));

    _isInitialized = true;
    notifyListeners();

    debugPrint('🟢 [ElephasMainService] Basic initialization complete');
  }

  /// Start protection
  Future<void> startProtection() async {
    if (!_isInitialized) {
      throw StateError(
          'Must call initialize() or initializeWithServices() first');
    }

    if (_isActive) return;

    debugPrint('🟢 [ElephasMainService] Starting protection...');

    // Test backend connectivity first
    await testBackendConnection();

    try {
      // Start screen monitoring (this monitors WhatsApp, Telegram, etc.)
      if (_screenMonitorService != null) {
        await _screenMonitorService!.startMonitoring();
        debugPrint('🟢 [ElephasMainService] Screen monitoring started');
      }

      // Start SMS monitoring
      if (_smsMonitorService != null &&
          _scamDetectionService != null &&
          _overlayService != null) {
        await _smsMonitorService!
            .startMonitoring(_scamDetectionService!, _overlayService!);
        debugPrint('🟢 [ElephasMainService] SMS monitoring started');
      } else {
        debugPrint(
            '⚠️ [ElephasMainService] Cannot start SMS monitoring - required services not initialized');
      }

      _isActive = true;
      notifyListeners();

      debugPrint(
          '🟢 [ElephasMainService] Protection started successfully - monitoring WhatsApp, Telegram, SMS');

      // Test scam detection with backend
      if (_backendConnected) {
        await testScamDetectionWithBackend();
      }
    } catch (e) {
      debugPrint('❌ [ElephasMainService] Failed to start protection: $e');
      rethrow;
    }
  }

  /// Stop protection
  Future<void> stopProtection() async {
    if (!_isActive) return;

    debugPrint('🟡 [ElephasMainService] Stopping protection...');

    _isActive = false;
    notifyListeners();

    debugPrint('🟡 [ElephasMainService] Protection stopped');
  }

  /// Test backend connectivity
  Future<bool> testBackendConnection() async {
    try {
      debugPrint(
          '🔍 [ElephasMainService] Testing backend connection to ${AppConfig.localApiUrl}...');

      final response = await http.get(
        Uri.parse('${AppConfig.localApiUrl}/health'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer ${AppConfig.apiKey}',
        },
      ).timeout(const Duration(seconds: 5));

      if (response.statusCode == 200) {
        _backendConnected = true;
        debugPrint('✅ [ElephasMainService] Backend connection successful!');
        notifyListeners();
        return true;
      } else {
        debugPrint(
            '❌ [ElephasMainService] Backend returned status: ${response.statusCode}');
        _backendConnected = false;
        notifyListeners();
        return false;
      }
    } catch (e) {
      debugPrint('❌ [ElephasMainService] Backend connection failed: $e');
      _backendConnected = false;
      notifyListeners();
      return false;
    }
  }

  /// Test scam detection with sample message
  Future<void> testScamDetectionWithBackend() async {
    if (!_isInitialized || !_backendConnected) {
      debugPrint(
          '⚠️ [ElephasMainService] Cannot test - not initialized or backend not connected');
      return;
    }

    debugPrint(
        '🧪 [ElephasMainService] Testing scam detection with backend...');

    try {
      if (_scamDetectionService != null) {
        final result = await _scamDetectionService!.analyzeMessage(
          'URGENT! Your bank account will be closed! Click this link immediately: http://fake-bank-scam.com',
          appPackage: 'com.whatsapp',
          contactId: 'test_contact',
        );

        debugPrint(
            '🧪 [ElephasMainService] Test result: ${result.isThreat ? 'THREAT DETECTED' : 'Safe'}');
        debugPrint('🧪 [ElephasMainService] Confidence: ${result.confidence}');
        debugPrint('🧪 [ElephasMainService] Risk Level: ${result.riskLevel}');
      }
    } catch (e) {
      debugPrint('❌ [ElephasMainService] Test failed: $e');
    }
  }

  /// Get monitored apps list
  List<String> getMonitoredApps() {
    if (!_isInitialized) return [];
    return ['WhatsApp', 'Messages', 'Telegram'];
  }

  /// Get protection stats
  Map<String, dynamic> getStats() {
    if (!_isInitialized) return {};
    return {
      'threatsBlocked': 0,
      'scansPerformed': 0,
      'uptime': '0 minutes',
    };
  }

  // Getters
  bool get isInitialized => _isInitialized;
  bool get isActive => _isActive;
  bool get backendConnected => _backendConnected;

  @override
  void dispose() {
    if (_isActive) {
      stopProtection();
    }
    super.dispose();
  }
}

/// Simple widget to integrate Elephas AI into your app
class ElephasWidget extends StatefulWidget {
  final Widget child;
  final bool autoStart;

  const ElephasWidget({
    super.key,
    required this.child,
    this.autoStart = true,
  });

  @override
  State<ElephasWidget> createState() => _ElephasWidgetState();
}

class _ElephasWidgetState extends State<ElephasWidget> {
  final _elephas = ElephasMainService.instance;

  @override
  void initState() {
    super.initState();
    _initializeElephas();
  }

  Future<void> _initializeElephas() async {
    await _elephas.initialize();
    if (widget.autoStart && mounted) {
      await _elephas.startProtection();
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: _elephas,
      builder: (context, child) {
        return Stack(
          children: [
            widget.child,

            // Show protection status indicator if active
            if (_elephas.isActive)
              Positioned(
                top: MediaQuery.of(context).padding.top + 10,
                right: 16,
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.green,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.security, color: Colors.white, size: 14),
                      SizedBox(width: 4),
                      Text('Protected',
                          style: TextStyle(color: Colors.white, fontSize: 12)),
                    ],
                  ),
                ),
              ),
          ],
        );
      },
    );
  }

  @override
  void dispose() {
    super.dispose();
  }
}
