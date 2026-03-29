import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'screens/home_screen.dart';
import 'screens/login_screen.dart';
import 'services/notification_service.dart';
import 'services/settings_service.dart';
import 'services/supabase_service.dart';
import 'themes/masterpiece_theme.dart';

void main() {
  runZonedGuarded(() async {
    WidgetsFlutterBinding.ensureInitialized();

    // Load environment variables
    await dotenv.load(fileName: ".env");

    // Initialize services
    await SupabaseService().initialize();
    await NotificationService.init();
    await AppSettingsService.init();

    runApp(const KonsehalManagementApp());
  }, (error, stackTrace) {
    // Log errors in production (can be expanded to Sentry/Firebase later)
    debugPrint('GLOBAL ERROR: $error');
    debugPrint('STACK TRACE: $stackTrace');
  });
}

class KonsehalManagementApp extends StatelessWidget {
  const KonsehalManagementApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<bool>(
      valueListenable: AppSettingsService.isDarkMode,
      builder: (context, isDarkMode, child) {
        final initialHome = SupabaseService().isAuthenticated 
            ? const HomeScreen() 
            : const LoginScreen();

        return MaterialApp(
          title: 'Konsehal Management',
          debugShowCheckedModeBanner: false,
          theme: MasterpieceTheme.themeData,
          darkTheme: MasterpieceTheme.darkThemeData,
          themeMode: isDarkMode ? ThemeMode.dark : ThemeMode.light,
          home: initialHome,
        );
      },
    );
  }
}
