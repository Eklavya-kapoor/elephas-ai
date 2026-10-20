// lib/screens/home_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../services/screen_monitor_service.dart';
import '../services/overlay_service.dart';
import '../widgets/protection_status_card.dart';
import '../widgets/quick_scan_card.dart';
import '../widgets/stats_card.dart';
import '../screens/settings_screen.dart';
import '../screens/history_screen.dart';

/// Brand accent, matching the Elephas AI web presence.
const _brandBlue = Color(0xFF2F6FAC);

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;
      final screenMonitor = Provider.of<ScreenMonitorService>(context, listen: false);
      final overlay = Provider.of<OverlayService>(context, listen: false);

      await screenMonitor.startMonitoring();
      if (mounted) {
        await overlay.checkAndRequestOverlayPermission();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF7F9FC),
      appBar: AppBar(
        backgroundColor: Colors.white,
        foregroundColor: const Color(0xFF131A2A),
        elevation: 0,
        scrolledUnderElevation: 1,
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(20),
              child: Image.asset('assets/images/elephas_icon.png', height: 30, width: 30),
            ),
            const SizedBox(width: 10),
            const Text(
              'Elephas AI',
              style: TextStyle(fontWeight: FontWeight.w700),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.history_outlined),
            tooltip: 'History',
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => const HistoryScreen()),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.settings_outlined),
            tooltip: 'Settings',
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => const SettingsScreen()),
            ),
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const ProtectionStatusCard(),
              const SizedBox(height: 24),

              const QuickScanCard(),
              const SizedBox(height: 28),

              Row(
                children: [
                  Container(
                    width: 4,
                    height: 20,
                    decoration: BoxDecoration(
                      color: _brandBlue,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Text(
                    'Protection Statistics',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: const Color(0xFF131A2A),
                        ),
                  ),
                ],
              ),
              const SizedBox(height: 14),

              Consumer<ScreenMonitorService>(
                builder: (context, screenMonitor, child) {
                  return Column(
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: StatsCard(
                              title: 'Screens Monitored',
                              value: screenMonitor.totalScreensMonitored.toString(),
                              icon: Icons.screen_share,
                              color: _brandBlue,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: StatsCard(
                              title: 'Scams Detected',
                              value: screenMonitor.scamsDetected.toString(),
                              icon: Icons.warning_amber_rounded,
                              color: Colors.red.shade600,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: StatsCard(
                              title: 'Active Alerts',
                              value: screenMonitor.activeAlerts.toString(),
                              icon: Icons.notification_important_outlined,
                              color: Colors.orange.shade700,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: StatsCard(
                              title: 'Protection Score',
                              value: '${screenMonitor.protectionScore.toStringAsFixed(1)}%',
                              icon: Icons.verified_user_outlined,
                              color: Colors.green.shade600,
                            ),
                          ),
                        ],
                      ),
                    ],
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}
