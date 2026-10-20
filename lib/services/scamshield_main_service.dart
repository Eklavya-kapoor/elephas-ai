import 'package:flutter/material.dart';
import '../core/services/intelligent_protection_service.dart';
import '../services/overlay_service.dart';
import '../services/phase1_overlay_integration.dart';

/// Main ScamShield service that provides easy integration for your app
class ScamShieldMainService extends ChangeNotifier {
  static ScamShieldMainService? _instance;
  static ScamShieldMainService get instance =>
      _instance ??= ScamShieldMainService._();

  ScamShieldMainService._();

  late final IntelligentProtectionService _protectionService;
  late final OverlayService _overlayService;
  late final ScamShieldPhase1Overlay _integration;

  bool _isInitialized = false;
  bool _isActive = false;

  /// Initialize ScamShield with your existing overlay
  Future<void> initialize() async {
    if (_isInitialized) return;

    // Initialize services
    _protectionService = IntelligentProtectionService();
    _overlayService = OverlayService();
    _overlayService.initialize();

    // Create integration
    _integration = ScamShieldPhase1Overlay(
      protectionService: _protectionService,
      overlayService: _overlayService,
    );

    _isInitialized = true;
    notifyListeners();
  }

  /// Start protection - will show image overlay when scams detected
  Future<void> startProtection() async {
    if (!_isInitialized) await initialize();
    if (_isActive) return;

    await _integration.startProtectionWithOverlay();
    _isActive = true;
    notifyListeners();
  }

  /// Stop protection
  Future<void> stopProtection() async {
    if (!_isActive) return;

    await _integration.stopProtection();
    _isActive = false;
    notifyListeners();
  }

  /// Test the overlay with a scam message
  Future<void> testScamDetection() async {
    if (!_isActive) return;

    await _integration.testOverlay(
        'URGENT! Your bank account will be blocked. Send OTP: 123456');
  }

  /// Get monitored apps (WhatsApp, Telegram, Instagram, SMS, Gmail, etc.)
  List<String> getMonitoredApps() {
    if (!_isInitialized) return [];

    return _protectionService.monitoredApps
        .map((appId) => _getDisplayName(appId))
        .where((name) => name.isNotEmpty)
        .toList();
  }

  /// Get app display name from package ID
  String _getDisplayName(String packageId) {
    switch (packageId) {
      case 'com.whatsapp':
        return 'WhatsApp';
      case 'org.telegram.messenger':
        return 'Telegram';
      case 'com.instagram.android':
        return 'Instagram';
      case 'com.android.messaging':
        return 'Messages';
      case 'com.google.android.gm':
        return 'Gmail';
      case 'com.facebook.orca':
        return 'Messenger';
      default:
        final parts = packageId.split('.');
        return parts.length > 2 ? parts.last : packageId;
    }
  }

  /// Get performance stats
  Map<String, dynamic> getStats() {
    if (!_isInitialized) return {};
    return _protectionService.getPerformanceMetrics();
  }

  /// Check if currently active
  bool get isActive => _isActive;
  bool get isInitialized => _isInitialized;

  @override
  void dispose() {
    _integration.dispose();
    super.dispose();
  }
}

/// Simple widget to integrate ScamShield into your app
class ScamShieldWidget extends StatefulWidget {
  final Widget child;
  final bool autoStart;

  const ScamShieldWidget({
    super.key,
    required this.child,
    this.autoStart = true,
  });

  @override
  State<ScamShieldWidget> createState() => _ScamShieldWidgetState();
}

class _ScamShieldWidgetState extends State<ScamShieldWidget> {
  final _scamShield = ScamShieldMainService.instance;

  @override
  void initState() {
    super.initState();
    _initializeScamShield();
  }

  Future<void> _initializeScamShield() async {
    await _scamShield.initialize();
    if (widget.autoStart) {
      await _scamShield.startProtection();
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: _scamShield,
      builder: (context, child) {
        // You can add a subtle indicator here if needed
        return Stack(
          children: [
            widget.child,
            // Optional: Add a small indicator when protection is active
            if (_scamShield.isActive)
              Positioned(
                top: MediaQuery.of(context).padding.top + 10,
                right: 10,
                child: Container(
                  width: 8,
                  height: 8,
                  decoration: const BoxDecoration(
                    color: Colors.green,
                    shape: BoxShape.circle,
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
    _scamShield.dispose();
    super.dispose();
  }
}
