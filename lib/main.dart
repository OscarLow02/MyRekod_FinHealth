import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'firebase_options.dart';
import 'core/app_theme.dart';
import 'providers/onboarding_provider.dart';
import 'providers/expense_provider.dart';
import 'screens/splash_screen.dart';
import 'screens/auth/auth_wrapper.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  runApp(const MyRekodApp());
}

class MyRekodApp extends StatelessWidget {
  const MyRekodApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => OnboardingProvider()),
        ChangeNotifierProvider(create: (_) => ExpenseProvider()),
      ],
      child: MaterialApp(
        title: 'MyRekod',
        debugShowCheckedModeBanner: false,
        // Follow system theme (DESIGN.md §2 — Adaptive Themes)
        themeMode: ThemeMode.system,
        theme: AppTheme.lightTheme,
        darkTheme: AppTheme.darkTheme,
        // Show Splash strictly
        home: const SplashScreen(),
      ),
    );
  }
}

