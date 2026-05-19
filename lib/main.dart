import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:provider/provider.dart';
import 'firebase_options.dart';
import 'core/app_theme.dart';
import 'providers/onboarding_provider.dart';
import 'providers/expense_provider.dart';
import 'providers/sales_provider.dart';
import 'providers/customer_provider.dart';
import 'providers/dashboard_provider.dart';
import 'providers/settings_provider.dart';
import 'screens/splash_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  // Pass all uncaught "fatal" errors from the framework to Crashlytics
  FlutterError.onError = FirebaseCrashlytics.instance.recordFlutterFatalError;

  // Pass all uncaught asynchronous errors that aren't handled by the Flutter framework
  PlatformDispatcher.instance.onError = (error, stack) {
    FirebaseCrashlytics.instance.recordError(error, stack, fatal: true);
    return true;
  };

  runApp(const MyRekodApp());
}

class MyRekodApp extends StatelessWidget {
  const MyRekodApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => SettingsProvider()),
        ChangeNotifierProvider(create: (_) => OnboardingProvider()),
        ChangeNotifierProvider(create: (_) => ExpenseProvider()),
        ChangeNotifierProvider(create: (_) => SalesProvider()),
        ChangeNotifierProvider(create: (_) => CustomerProvider()),
        ChangeNotifierProvider(create: (_) => DashboardProvider()),
      ],
      child: Consumer<SettingsProvider>(
        builder: (context, settings, child) {
          return MaterialApp(
            title: 'MyRekod',
            debugShowCheckedModeBanner: false,
            themeMode: ThemeMode.system,
            theme: settings.isHighContrast ? AppTheme.highContrastTheme : AppTheme.lightTheme,
            darkTheme: settings.isHighContrast ? AppTheme.highContrastTheme : AppTheme.darkTheme,
            builder: (context, child) {
              return GestureDetector(
                onTap: () {
                  FocusManager.instance.primaryFocus?.unfocus();
                },
                child: child,
              );
            },
            home: const SplashScreen(),
          );
        },
      ),
    );
  }
}

