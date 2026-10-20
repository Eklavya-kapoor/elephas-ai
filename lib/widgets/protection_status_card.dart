import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/sms_monitor_service.dart';
import '../services/permissions_service.dart';

class ProtectionStatusCard extends StatefulWidget {
  const ProtectionStatusCard({super.key});

  @override
  State<ProtectionStatusCard> createState() => _ProtectionStatusCardState();
}

class _ProtectionStatusCardState extends State<ProtectionStatusCard> {
  String _protectionLevel = 'CHECKING...';
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _checkProtectionLevel();
  }

  Future<void> _checkProtectionLevel() async {
    try {
      final permissionsService =
          Provider.of<PermissionsService>(context, listen: false);
      final level = await permissionsService.getProtectionLevel();
      if (mounted) {
        setState(() {
          _protectionLevel = level;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _protectionLevel = 'UNKNOWN';
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<SmsMonitorService>(
      builder: (context, smsService, child) {
        // Determine colors and icons based on protection level
        Color getProtectionColor() {
          switch (_protectionLevel) {
            case 'FULL PROTECTION':
              return Colors.green;
            case 'GOOD PROTECTION':
              return Colors.lightGreen;
            case 'PARTIAL PROTECTION':
              return Colors.orange;
            case 'LIMITED PROTECTION':
              return Colors.red;
            default:
              return Colors.grey;
          }
        }

        IconData getProtectionIcon() {
          switch (_protectionLevel) {
            case 'FULL PROTECTION':
              return Icons.security;
            case 'GOOD PROTECTION':
              return Icons.verified_user;
            case 'PARTIAL PROTECTION':
              return Icons.warning;
            case 'LIMITED PROTECTION':
              return Icons.error;
            default:
              return Icons.shield_outlined;
          }
        }

        String getProtectionDescription() {
          switch (_protectionLevel) {
            case 'FULL PROTECTION':
              return 'Your device is fully protected from scams';
            case 'GOOD PROTECTION':
              return 'Good level of protection with minor gaps';
            case 'PARTIAL PROTECTION':
              return 'Enable all protections for full security';
            case 'LIMITED PROTECTION':
              return 'Your device is vulnerable. Grant permissions for protection';
            default:
              return 'Checking protection status...';
          }
        }

        return Card(
          elevation: 4,
          child: Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              gradient: LinearGradient(
                colors: [
                  getProtectionColor().withValues(alpha: 0.8),
                  getProtectionColor(),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
            child: Column(
              children: [
                _isLoading
                    ? const CircularProgressIndicator(color: Colors.white)
                    : Icon(
                        getProtectionIcon(),
                        size: 64,
                        color: Colors.white,
                      ),
                const SizedBox(height: 16),
                Text(
                  _protectionLevel,
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  getProtectionDescription(),
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
                      'Screen',
                      true, // Assume screen monitoring is working if app is running
                      Icons.screen_share,
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                ElevatedButton.icon(
                  onPressed: _checkProtectionLevel,
                  icon: const Icon(Icons.refresh),
                  label: const Text('Refresh Status'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white.withValues(alpha: 0.2),
                    foregroundColor: Colors.white,
                  ),
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
          color: isActive
              ? Colors.white
              : Colors.white.withValues(alpha: 128), // 0.5 ≈ 128/255
          size: 24,
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(
            color: isActive
                ? Colors.white
                : Colors.white.withValues(alpha: 128), // 0.5 ≈ 128/255
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 2),
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: isActive
                ? Colors.white
                : Colors.white.withValues(alpha: 77), // 0.3 ≈ 77/255
          ),
        ),
      ],
    );
  }
}
