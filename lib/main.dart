// lib/main.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'core/services/intelligent_protection_service.dart';
import 'core/services/channel_monitor.dart';
import 'core/services/contact_intelligence.dart';
import 'core/services/conversation_analyzer.dart';
import 'screens/permissions_screen.dart';
import 'screens/settings_screen.dart';
import 'screens/history_screen.dart';
import 'services/screen_monitor_service.dart';
import 'services/overlay_service.dart';
import 'services/phase1_overlay_integration.dart';
import 'services/permissions_service.dart';
import 'services/sms_monitor_service.dart';
import 'services/scam_detection_service.dart';
import 'services/real_contacts_service.dart';
import 'services/device_registration_service.dart';

void main() async {
  // Make main async
  WidgetsFlutterBinding.ensureInitialized();

  try {
    // Create services
    final permissionsService = PermissionsService();
    final contactIntelligence = ContactIntelligenceService();
    final conversationAnalyzer = ConversationAnalyzer.instance;
    final channelMonitor = ChannelMonitor();
    final smsMonitorService = SmsMonitorService();

    // Sync real phone contacts (non-blocking - if permission isn't granted
    // yet, ScreenMonitorService safely defaults to treating senders as
    // unsaved/unknown until a later sync succeeds)
    RealContactsService.instance.syncContacts().catchError((e) {
      debugPrint('⚠️ Real contacts sync failed: $e');
    });

    // Register this install with the backend and start heartbeats, so the
    // admin dashboard can show real device/scan counts (non-blocking).
    DeviceRegistrationService.instance.registerAndStartHeartbeat().catchError((e) {
      debugPrint('⚠️ Device registration failed: $e');
    });

    // Get scam detection service singleton and initialize it
    final scamDetectionService = SmartScamDetectionService.instance;

    // Initialize with error handling
    try {
      await scamDetectionService.initialize();
    } catch (e) {
      debugPrint('⚠️ ScamDetectionService init failed: $e');
    }

    // Create main protection service with dependencies
    final protectionService = IntelligentProtectionService(
      contactIntelligence: contactIntelligence,
      conversationAnalyzer: conversationAnalyzer,
      channelMonitor: channelMonitor,
    );

    // Create and initialize overlay service
    final overlayService = OverlayService();
    overlayService.initialize();

    // Initialize sms monitoring with error handling
    try {
      await smsMonitorService.startMonitoring(
          scamDetectionService, overlayService);
    } catch (e) {
      debugPrint('⚠️ SMS monitoring init failed: $e');
    }

    // Create Phase 1 integration
    final phase1Integration = ScamShieldPhase1Overlay(
      protectionService: protectionService,
      overlayService: overlayService,
    );

    runApp(
      MultiProvider(
        providers: [
          // Core services
          Provider<ContactIntelligenceService>.value(
              value: contactIntelligence),
          Provider<ConversationAnalyzer>.value(value: conversationAnalyzer),
          ChangeNotifierProvider<ChannelMonitor>.value(value: channelMonitor),
          ChangeNotifierProvider<PermissionsService>.value(
              value: permissionsService),
          ChangeNotifierProvider<SmsMonitorService>.value(
              value: smsMonitorService),
          ChangeNotifierProvider<SmartScamDetectionService>.value(
              value: scamDetectionService),

          // Main services
          ChangeNotifierProvider<IntelligentProtectionService>.value(
              value: protectionService),
          ChangeNotifierProvider<OverlayService>.value(value: overlayService),
          Provider<ScamShieldPhase1Overlay>.value(value: phase1Integration),

          // Screen monitoring (still used for UI protection)
          ChangeNotifierProvider(create: (context) {
            final screenMonitor =
                ScreenMonitorService(overlayService: overlayService);
            screenMonitor.startMonitoring();
            return screenMonitor;
          }),
        ],
        child: const ElephantAI(),
      ),
    );
  } catch (e, stack) {
    debugPrint('❌ FATAL ERROR during app startup: $e');
    debugPrint('Stack: $stack');
    // Show a minimal error app
    runApp(
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: Text('App failed to start: $e'),
          ),
        ),
      ),
    );
  }
}

class ElephantAI extends StatelessWidget {
  const ElephantAI({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Elephas AI',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF2F6FAC)),
        scaffoldBackgroundColor: const Color(0xFFF7F9FC),
        useMaterial3: true,
      ),
      home: const PermissionsScreen(),
      routes: {
        '/settings': (context) => const SettingsScreen(),
        '/history': (context) => const HistoryScreen(),
      },
    );
  }
}
