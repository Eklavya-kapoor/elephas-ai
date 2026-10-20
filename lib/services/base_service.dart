import 'package:flutter/foundation.dart';

/// Base service class with common functionality for all services
abstract class BaseService extends ChangeNotifier {
  bool _isInitialized = false;
  bool _isRunning = false;
  String get serviceId;

  bool get isInitialized => _isInitialized;
  bool get isRunning => _isRunning;

  @protected
  void markInitialized() {
    _isInitialized = true;
    notifyListeners();
  }

  @protected
  void markStarted() {
    _isRunning = true;
    notifyListeners();
  }

  @protected
  void markStopped() {
    _isRunning = false;
    notifyListeners();
  }

  @mustCallSuper
  @override
  void dispose() {
    _isRunning = false;
    _isInitialized = false;
    super.dispose();
  }
}
