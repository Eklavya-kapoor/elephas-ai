import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'screens/modern_permissions_screen.dart';
import 'services/elephas_main_service.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(
    ChangeNotifierProvider(
      create: (_) => ElephasMainService.instance,
      child: const ElephasApp(),
    ),
  );
}

class ElephasApp extends StatelessWidget {
  const ElephasApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Elephas AI - Smart Protection',
      theme: ThemeData(
        primarySwatch: Colors.indigo,
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF4F46E5), // Elephas AI primary color
          brightness: Brightness.light,
        ),
      ),
      // Always start with the permissions screen
      home: const ModernPermissionsScreen(),
    );
  }
}
