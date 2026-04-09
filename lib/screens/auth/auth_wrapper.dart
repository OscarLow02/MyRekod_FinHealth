import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../services/firestore_service.dart';
import '../dashboard_screen.dart';
import '../onboarding/onboarding_screen.dart';
import 'login_screen.dart';

/// Reactive auth gate that listens to Firebase auth state changes.
/// Routes users to Login, Onboarding, or Dashboard based on their status.
class AuthWrapper extends StatelessWidget {
  const AuthWrapper({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        // Show loading while waiting for auth state
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(
              child: CircularProgressIndicator(),
            ),
          );
        }

        final user = snapshot.data;

        // Not logged in → Login screen
        if (user == null) {
          return const LoginScreen();
        }

        // Logged in → check if onboarding is complete
        return FutureBuilder<bool>(
          future: FirestoreService().hasBusinessProfile(user.uid),
          builder: (context, profileSnapshot) {
            if (profileSnapshot.connectionState == ConnectionState.waiting) {
              return const Scaffold(
                body: Center(
                  child: CircularProgressIndicator(),
                ),
              );
            }

            final hasProfile = profileSnapshot.data ?? false;

            if (hasProfile) {
              return const DashboardScreen();
            } else {
              return const OnboardingScreen();
            }
          },
        );
      },
    );
  }
}
