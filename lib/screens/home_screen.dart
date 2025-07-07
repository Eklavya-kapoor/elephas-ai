// lib/screens/home_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:elephas_ai/services/scam_detection_service.dart';
import 'package:elephas_ai/services/sms_monitor_service.dart';
import 'package:elephas_ai/services/call_monitor_service.dart';
import 'package:elephas_ai/widgets/protection_status_card.dart';
import 'package:elephas_ai/widgets/quick_scan_card.dart';
import 'package:elephas_ai/widgets/stats_card.dart';

// FIX: Change StatelessWidget to StatefulWidget
class HomeScreen extends StatefulWidget {
  const HomeScreen(
      {super.key}); // Keep this const if the constructor of HomeScreen itself is const

  @override
  // This is correct for a StatefulWidget
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      // Ensure context is valid for Provider.of calls
      if (mounted) {
        final smsService =
            Provider.of<SmsMonitorService>(context, listen: false);
        final callService =
            Provider.of<CallMonitorService>(context, listen: false);
        final detectionService = Provider.of<SmartScamDetectionService>(context,
            listen:
                false); // Ensure this service is provided higher up in the tree

        smsService.startMonitoring(detectionService);
        callService.startMonitoring();
        // You might also want to start screen monitoring here
        // Provider.of<ScreenMonitorService>(context, listen: false).startScreenMonitoring(detectionService, Provider.of<OverlayService>(context, listen: false));
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        // FIX: Remove const from AppBar title if it's dynamic (like Text('Elephas AI'))
        // If it's static, you can keep const Text('Elephas AI')
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Image.asset(
              'assets/images/elephas_icon.png',
              height: 24,
              width: 24,
            ),
            const SizedBox(width: 8),
            const Text('Elephas AI'),
          ],
        ),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16), // Added const
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Now we can use const since we've added a const constructor
            const ProtectionStatusCard(),
            const SizedBox(height: 16), // This can remain const
            // Using const here improves performance since QuickScanCard has a const constructor
            const QuickScanCard(),
            const SizedBox(height: 16), // This can remain const
            Text(
              // This cannot be const because it depends on Theme.of(context)
              'Protection Statistics',
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 12), // This can remain const
            // Ensure SmsMonitorService and CallMonitorService are provided in your app's widget tree
            Consumer2<SmsMonitorService, CallMonitorService>(
              builder: (context, smsService, callService, child) {
                // FIX: This Column cannot be const because its children (Rows) are not const.
                return Column(
                  children: [
                    // FIX: This Row cannot be const because its children (Expanded/StatsCard) are not const. (Error on line 59 likely points here due to its children)
                    Row(
                      children: [
                        Expanded(
                          // Expanded cannot be const
                          // FIX: StatsCard cannot be const as its 'value' is dynamic.
                          child: StatsCard(
                            title: 'SMS Scanned',
                            value: smsService.totalSmsScanned
                                .toString(), // Dynamic value
                            icon: Icons.message,
                            color: Colors.blue,
                          ),
                        ),
                        const SizedBox(width: 12), // This can remain const
                        Expanded(
                          // Expanded cannot be const
                          // FIX: StatsCard cannot be const as its 'value' is dynamic.
                          child: StatsCard(
                            title: 'Scams Blocked',
                            value: smsService.scamsBlocked
                                .toString(), // Dynamic value
                            icon: Icons.block,
                            color: Colors.red,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12), // This can remain const
                    // FIX: This Row cannot be const because its children (Expanded/StatsCard) are not const.
                    Row(
                      children: [
                        Expanded(
                          // Expanded cannot be const
                          // FIX: StatsCard cannot be const as its 'value' is dynamic.
                          child: StatsCard(
                            title: 'Calls Monitored',
                            value: callService.totalCallsScanned
                                .toString(), // Dynamic value
                            icon: Icons.phone,
                            color: Colors.green,
                          ),
                        ),
                        const SizedBox(width: 12), // This can remain const
                        Expanded(
                          // Expanded cannot be const
                          // FIX: StatsCard cannot be const as its 'value' is dynamic.
                          child: StatsCard(
                            title: 'Suspicious Calls',
                            value: callService.suspiciousCalls
                                .toString(), // Dynamic value
                            icon: Icons.warning,
                            color: Colors.orange,
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
    );
  }
}
