import 'package:flutter/material.dart';

/// Minimal Elephas AI service for testing
class ElephasMainService extends ChangeNotifier {
  static ElephasMainService? _instance;
  static ElephasMainService get instance =>
      _instance ??= ElephasMainService._();

  ElephasMainService._();

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

/// Simple widget to integrate Elephas AI into your app
class ElephasWidget extends StatefulWidget {
  final Widget child;
  final bool autoStart;

  const ElephasWidget({
    super.key,
    required this.child,
    this.autoStart = true,
  });

  @override
  State<ElephasWidget> createState() => _ElephasWidgetState();
}

class _ElephasWidgetState extends State<ElephasWidget> {
  final _elephas = ElephasMainService.instance;

  @override
  void initState() {
    super.initState();
    _initializeElephas();
  }

  Future<void> _initializeElephas() async {
    await _elephas.initialize();
    if (widget.autoStart && mounted) {
      await _elephas.startProtection();
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: _elephas,
      builder: (context, child) {
        return Stack(
          children: [
            widget.child,

            // Show protection status indicator if active
            if (_elephas.isActive)
              Positioned(
                top: MediaQuery.of(context).padding.top + 10,
                right: 16,
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.green,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.security, color: Colors.white, size: 14),
                      SizedBox(width: 4),
                      Text('Protected',
                          style: TextStyle(color: Colors.white, fontSize: 12)),
                    ],
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}
