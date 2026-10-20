import 'package:flutter/material.dart';

/// Minimal test version of ElephasMainService
class ElephasMainServiceTest extends ChangeNotifier {
  static ElephasMainServiceTest? _instance;
  static ElephasMainServiceTest get instance => _instance ??= ElephasMainServiceTest._();
  
  ElephasMainServiceTest._();

  bool _isInitialized = false;
  bool _isActive = false;

  Future<void> initialize() async {
    _isInitialized = true;
    notifyListeners();
  }

  Future<void> startProtection() async {
    _isActive = true;
    notifyListeners();
  }

  Future<void> stopProtection() async {
    _isActive = false;
    notifyListeners();
  }

  bool get isInitialized => _isInitialized;
  bool get isActive => _isActive;
}
