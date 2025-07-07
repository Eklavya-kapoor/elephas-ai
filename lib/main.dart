// lib/main.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:provider/provider.dart';

import 'package:elephas_ai/screens/home_screen.dart';
import 'package:elephas_ai/screens/permission_screen.dart';
import 'package:elephas_ai/screens/splash_screen.dart';
import 'package:elephas_ai/services/overlay_service.dart';
import 'package:elephas_ai/services/screen_monitor_service.dart';
import 'package:elephas_ai/services/scam_detection_service.dart';
import 'package:elephas_ai/services/sms_monitor_service.dart';
import 'package:elephas_ai/services/call_monitor_service.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => OverlayService()),
        ChangeNotifierProvider(create: (_) => ScreenMonitorService()),
        ChangeNotifierProvider(create: (_) => SmartScamDetectionService()),
        ChangeNotifierProvider(create: (_) => SmsMonitorService()),
        ChangeNotifierProvider(create: (_) => CallMonitorService()),
      ],
      child: const MyApp(),
    ),
  );
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  static const MethodChannel _appControlChannel =
      MethodChannel('elephas_ai/app_control');

  late Future<bool> _initializationCheck;

  @override
  void initState() {
    super.initState();
    _initializationCheck = _initializeAndRequestPermissions();
  }

  Future<bool> _initializeAndRequestPermissions() async {
    // 1. Request all necessary permissions
    bool allGranted = await _requestAllNecessaryPermissions();
    if (!allGranted) return false;

    // Check if the widget is still mounted before proceeding
    if (!mounted) return false;

    // 2. Initialize services after permissions are granted
    final overlayService = Provider.of<OverlayService>(context, listen: false);
    final screenMonitorService =
        Provider.of<ScreenMonitorService>(context, listen: false);
    final scamDetectionService =
        Provider.of<SmartScamDetectionService>(context, listen: false);
    final smsMonitorService =
        Provider.of<SmsMonitorService>(context, listen: false);
    final callMonitorService =
        Provider.of<CallMonitorService>(context, listen: false);

    // Initialize core services
    overlayService.initialize();
    screenMonitorService.initialize(scamDetectionService, overlayService);

    // Start monitoring services
    await smsMonitorService.startMonitoring(
        scamDetectionService, overlayService);
    callMonitorService.startMonitoring();

    // Check if still mounted before continuing with async operations
    if (!mounted) return false;

    await screenMonitorService.startRealtimeMonitoring();

    // Check if still mounted before continuing with platform operations
    if (!mounted) return false;

    // 3. Start native background monitoring service
    try {
      await _appControlChannel.invokeMethod('startBackgroundMonitoringService');
    } on PlatformException catch (e) {
      // Use if (mounted) check before using context in error handling
      debugPrint(
          "Failed to start background monitoring service: '${e.message}'.");
    }

    return true;
  }

  Future<bool> _requestAllNecessaryPermissions() async {
    Map<Permission, PermissionStatus> statuses = await [
      Permission.sms,
      Permission.phone,
      Permission.notification,
      Permission.storage,
    ].request();

    return !statuses.values.any((status) => status.isDenied);
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Elephas AI',
      theme: ThemeData(
        primarySwatch: Colors.indigo,
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF4F46E5), // Elephas primary color
          brightness: Brightness.light,
        ),
      ),
      home: FutureBuilder<bool>(
        future: _initializationCheck,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const SplashScreen();
          }

          if (snapshot.data == true) {
            return const HomeScreen();
          }

          return const PermissionScreen();
        },
      ),
    );
  }
}
