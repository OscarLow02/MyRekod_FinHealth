import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/app_theme.dart';
import '../../providers/onboarding_provider.dart';
import '../auth/auth_wrapper.dart';
import 'step_entity_type.dart';
import 'step_business_details.dart';
import 'step_contact_details.dart';
import 'step_address.dart';
import 'step_review.dart';

/// Main onboarding wizard shell.
/// Uses a PageView with controlled navigation (no accidental swipes).
/// Embeds: Entity Type → Business Details → Contact → Address → Review.
class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  late PageController _pageController;

  @override
  void initState() {
    super.initState();
    _pageController = PageController();
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _onNextPressed(OnboardingProvider provider) {
    provider.nextStep();
    _pageController.animateToPage(
      provider.currentStep,
      duration: const Duration(milliseconds: 350),
      curve: Curves.easeInOut,
    );
  }

  void _onBackPressed(OnboardingProvider provider) {
    if (provider.currentStep == 0) return;
    provider.prevStep();
    _pageController.animateToPage(
      provider.currentStep,
      duration: const Duration(milliseconds: 350),
      curve: Curves.easeInOut,
    );
  }

  Future<void> _onSubmit(OnboardingProvider provider) async {
    try {
      await provider.submit();
      if (!mounted) return;
      // Navigate to Dashboard via AuthWrapper (it will detect the profile)
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const AuthWrapper()),
        (route) => false,
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        // TODO: Implement i18n
        SnackBar(content: Text('Failed to save profile: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Consumer<OnboardingProvider>(
      builder: (context, provider, _) {
        final isLastStep =
            provider.currentStep == OnboardingProvider.totalPages - 1;

        // TODO: Implement i18n
        const brandName = 'MyRekod';
        const brandAccent = 'REKOD';

        return Scaffold(
          body: SafeArea(
            child: Column(
              children: [
                // ── Top Bar ──
                Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                  child: Row(
                    children: [
                      // Back button (hidden on first step)
                      if (provider.currentStep > 0)
                        IconButton(
                          onPressed: () => _onBackPressed(provider),
                          icon: const Icon(Icons.arrow_back_rounded),
                          style: IconButton.styleFrom(
                            minimumSize: const Size(
                              AppTheme.minTouchTarget,
                              AppTheme.minTouchTarget,
                            ),
                          ),
                        )
                      else
                        const SizedBox(width: AppTheme.minTouchTarget),
                      const SizedBox(width: 8),
                      // ── App Logo Icon ──
                      Container(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(8),
                          boxShadow: [
                            BoxShadow(
                              color: theme.colorScheme.shadow.withValues(alpha: 0.1),
                              blurRadius: 4,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: Image.asset(
                            'assets/App Logo.jpeg',
                            width: 28,
                            height: 28,
                            fit: BoxFit.cover,
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Text(
                        brandName,
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.5,
                        ),
                      ),
                      const Spacer(),
                      Text(
                        brandAccent,
                        style: theme.textTheme.titleMedium?.copyWith(
                          color: AppTheme.primary,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 1.5,
                        ),
                      ),
                      const SizedBox(width: 16),
                    ],
                  ),
                ),

                // ── Progress Section ──
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            provider.stepLabel,
                            style: theme.textTheme.labelMedium?.copyWith(
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          Text(
                            provider.progressHint,
                            style: theme.textTheme.labelMedium?.copyWith(
                              color: AppTheme.primary,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: LinearProgressIndicator(
                          value: provider.progress,
                          backgroundColor: theme
                              .colorScheme.onSurfaceVariant
                              .withValues(alpha: 0.15),
                          valueColor: const AlwaysStoppedAnimation<Color>(
                            AppTheme.primary,
                          ),
                          minHeight: 6,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 8),

                // ── Page Content ──
                Expanded(
                  child: PageView(
                    controller: _pageController,
                    physics: const NeverScrollableScrollPhysics(),
                    children: const [
                      StepEntityType(),
                      StepBusinessDetails(),
                      StepContactDetails(),
                      StepAddress(),
                      StepReview(),
                    ],
                  ),
                ),

                // ── Bottom Button ──
                Padding(
                  padding: const EdgeInsets.fromLTRB(24, 8, 24, 16),
                  child: SizedBox(
                    width: double.infinity,
                    height: AppTheme.minTouchTarget + 8,
                    child: ElevatedButton(
                      onPressed: provider.isSubmitting
                          ? null
                          : isLastStep
                              ? () => _onSubmit(provider)
                              : () => _onNextPressed(provider),
                      child: provider.isSubmitting
                          ? const SizedBox(
                              width: 24,
                              height: 24,
                              child: CircularProgressIndicator(
                                color: Colors.white,
                                strokeWidth: 2.5,
                              ),
                            )
                          : Text(
                              // TODO: Implement i18n
                              isLastStep
                                  ? 'Confirm & Go to Dashboard  →'
                                  : 'CONTINUE',
                            ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
