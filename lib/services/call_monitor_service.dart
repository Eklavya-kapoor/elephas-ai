import 'package:flutter/foundation.dart';
import 'package:call_log/call_log.dart';
import 'package:permission_handler/permission_handler.dart';

class CallMonitorService extends ChangeNotifier {
  bool _isMonitoring = false;
  int _totalCallsScanned = 0;
  int _suspiciousCalls = 0;
  final List<String> _blockedNumbers = [];

  bool get isMonitoring => _isMonitoring;
  int get totalCallsScanned => _totalCallsScanned;
  int get suspiciousCalls => _suspiciousCalls;
  List<String> get blockedNumbers => _blockedNumbers;

  Future<bool> requestPermissions() async {
    final phonePermission = await Permission.phone.request();
    return phonePermission.isGranted;
  }

  Future<void> startMonitoring() async {
    if (!await requestPermissions()) return;

    _isMonitoring = true;
    notifyListeners();
  }

  void stopMonitoring() {
    _isMonitoring = false;
    notifyListeners();
  }

  Future<List<CallLogEntry>> getRecentCalls() async {
    if (!await Permission.phone.isGranted) return [];

    try {
      final entries = (await CallLog.get()).toList(); // ✅ Convert to List
      _totalCallsScanned = entries.length;

      _suspiciousCalls = entries
          .where((call) => _isSuspiciousNumber(call.number ?? ''))
          .length;

      notifyListeners();
      return entries;
    } catch (e) {
      return [];
    }
  }

  bool _isSuspiciousNumber(String number) {
    // Simple patterns for suspicious numbers
    if (number.length < 5) return true;
    if (number.startsWith('0000')) return true;
    if (number.contains('*') || number.contains('#')) return true;
    return _blockedNumbers.contains(number);
  }

  void blockNumber(String number) {
    if (!_blockedNumbers.contains(number)) {
      _blockedNumbers.add(number);
      notifyListeners();
    }
  }

  void unblockNumber(String number) {
    _blockedNumbers.remove(number);
    notifyListeners();
  }

  bool isBlocked(String number) {
    return _blockedNumbers.contains(number);
  }
}
