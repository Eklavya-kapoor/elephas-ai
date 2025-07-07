import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/sms_monitor_service.dart';
import '../services/call_monitor_service.dart';

class ProtectionStatusCard extends StatelessWidget {
  const ProtectionStatusCard({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer2<SmsMonitorService, CallMonitorService>(
      builder: (context, smsService, callService, child) {
        final isProtected = smsService.isMonitoring && callService.isMonitoring;
        
        return Card(
          elevation: 4,
          child: Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              gradient: LinearGradient(
                colors: isProtected 
                  ? [Colors.green[400]!, Colors.green[600]!]
                  : [Colors.orange[400]!, Colors.orange[600]!],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
            child: Column(
              children: [
                Icon(
                  isProtected ? Icons.shield : Icons.shield_outlined,
                  size: 64,
                  color: Colors.white,
                ),
                const SizedBox(height: 16),
                Text(
                  isProtected ? 'PROTECTED' : 'PARTIAL PROTECTION',
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  isProtected 
                    ? 'Your device is fully protected from scams'
                    : 'Enable all protections for full security',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 16,
                    color: Colors.white.withValues(alpha: 230), // 0.9 ≈ 230/255
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    _buildStatusIndicator(
                      'SMS',
                      smsService.isMonitoring,
                      Icons.message,
                    ),
                    _buildStatusIndicator(
                      'Calls',
                      callService.isMonitoring,
                      Icons.phone,
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildStatusIndicator(String label, bool isActive, IconData icon) {
    return Column(
      children: [
        Icon(
          icon,
          color: isActive ? Colors.white : Colors.white.withValues(alpha: 128), // 0.5 ≈ 128/255
          size: 24,
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(
            color: isActive ? Colors.white : Colors.white.withValues(alpha: 128), // 0.5 ≈ 128/255
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 2),
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: isActive ? Colors.white : Colors.white.withValues(alpha: 77), // 0.3 ≈ 77/255
          ),
        ),
      ],
    );
  }
}