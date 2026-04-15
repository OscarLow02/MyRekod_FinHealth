import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../core/app_theme.dart';
import 'auth/auth_wrapper.dart';

/// Launch screen matching the Figma "Onboarding Preview" design.
/// Shows the MYREKOD brand, tagline, and a "Get Started" CTA button.
class SplashScreen extends StatelessWidget {
  const SplashScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    // TODO: Implement i18n — extract all user-facing strings
    const appName = 'MYREKOD';
    const tagline = 'Simplified financial tracking\nfor your business.';
    const ctaLabel = 'Get Started  →';
    const footerText = 'Join 5,000+ hawkers managing sales daily.';

    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
          child: Column(
            children: [
              const Spacer(flex: 2),

              // ── Brand Icon ──
              Container(
                width: 72,
                height: 72,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(AppTheme.radiusLarge),
                  boxShadow: [
                    BoxShadow(
                      color: theme.colorScheme.shadow.withValues(alpha: 0.2),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(AppTheme.radiusLarge),
                  child: Image.asset(
                    'assets/App Logo.jpeg',
                    width: 72,
                    height: 72,
                    fit: BoxFit.cover,
                  ),
                ),
              ),
              const SizedBox(height: 32),

              // ── App Name ──
              Text(
                appName,
                style: theme.textTheme.displayMedium?.copyWith(
                  fontWeight: FontWeight.w800,
                  letterSpacing: 2,
                ),
              ),
              const SizedBox(height: 12),

              // ── Tagline ──
              Text(
                tagline,
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyLarge,
              ),

              const Spacer(flex: 2),

              // ── Sales Preview Card (decorative) ──
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: theme.colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(AppTheme.radiusLarge),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "TODAY'S SALES",
                      // TODO: Implement i18n
                      style: theme.textTheme.labelMedium,
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Text(
                          'RM 2,450.00',
                          style: theme.textTheme.headlineMedium?.copyWith(
                            fontWeight: FontWeight.w800,
                            letterSpacing: -0.5,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Container(
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(
                            color: AppTheme.neonGreenDark.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Icon(
                            Icons.trending_up_rounded,
                            color: AppTheme.neonGreenDark,
                            size: 20,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    // Decorative skeleton lines
                    _buildSkeletonLine(context, 0.6),
                    const SizedBox(height: 10),
                    _buildSkeletonLine(context, 0.4),
                  ],
                ),
              ),

              const Spacer(flex: 3),

              // ── CTA Button ──
              SizedBox(
                width: double.infinity,
                height: AppTheme.minTouchTarget + 8,
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.of(context).pushReplacement(
                      MaterialPageRoute(
                        builder: (_) => const AuthWrapper(),
                      ),
                    );
                  },
                  child: const Text(ctaLabel),
                ),
              ),
              const SizedBox(height: 16),

              // ── Footer ──
              Text(
                footerText,
                style: theme.textTheme.labelMedium,
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSkeletonLine(BuildContext context, double widthFactor) {
    return FractionallySizedBox(
      widthFactor: widthFactor,
      alignment: Alignment.centerLeft,
      child: Container(
        height: 10,
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.onSurfaceVariant.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(5),
        ),
      ),
    );
  }
}
