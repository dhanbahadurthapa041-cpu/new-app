import 'package:flutter/material.dart';
import 'services/storage_service.dart';
import 'services/notification_service.dart';
import 'utils/app_theme.dart';
import 'screens/first_run_setup_screen.dart';
import 'screens/home_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    await NotificationService.init();
  } catch (e) {
    debugPrint('Error initializing notifications: $e');
  }
  runApp(const AttendanceApp());
}

class AttendanceApp extends StatelessWidget {
  const AttendanceApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Attendance App',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: ThemeMode.system,
      home: const AppStartupGate(),
    );
  }
}

class AppStartupGate extends StatefulWidget {
  const AppStartupGate({super.key});

  @override
  State<AppStartupGate> createState() => _AppStartupGateState();
}

class _AppStartupGateState extends State<AppStartupGate> {
  bool _isLoading = true;
  bool _hasCompletedSetup = false;

  @override
  void initState() {
    super.initState();
    _loadSetupState();
  }

  Future<void> _loadSetupState() async {
    final hasCompletedSetup = await StorageService.hasCompletedSetup();
    if (!mounted) return;
    setState(() {
      _hasCompletedSetup = hasCompletedSetup;
      _isLoading = false;
    });
  }

  void _showHome() {
    setState(() {
      _hasCompletedSetup = true;
    });
  }

  void _showSetup() {
    setState(() {
      _hasCompletedSetup = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    if (!_hasCompletedSetup) {
      return FirstRunSetupScreen(onComplete: _showHome);
    }

    return HomeScreen(onSetupRequired: _showSetup);
  }
}
