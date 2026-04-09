import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/app_theme.dart';
import '../../providers/onboarding_provider.dart';

/// Pre-step: Entity type selection matching Figma "Who are you registering?"
/// Two large tappable cards for Sole Trader vs Registered SME.
class StepEntityType extends StatelessWidget {
  const StepEntityType({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final provider = context.watch<OnboardingProvider>();

    // TODO: Implement i18n
    const title = 'Who are you\nregistering?';
    const subtitle =
        'Choose the legal structure that best\ndescribes your business activities.';
    const soleTraderTitle = 'Person (Sole Trader)';
    const soleTraderDesc =
        'Independent hawker or individual\nfreelancer without a registered\ncompany.';
    const smeTitle = 'Business (Registered SME)';
    const smeDesc =
        'Formally registered entity with a\nbusiness registration number and\nstaff.';

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 16),

          // ── Title ──
          Text(title, style: theme.textTheme.headlineLarge),
          const SizedBox(height: 12),
          Text(subtitle, style: theme.textTheme.bodyLarge),
          const SizedBox(height: 32),

          // ── Sole Trader Card ──
          _EntityCard(
            icon: Icons.person_outline_rounded,
            title: soleTraderTitle,
            description: soleTraderDesc,
            isSelected: provider.entityType == 'sole_trader',
            onTap: () => provider.setEntityType('sole_trader'),
          ),
          const SizedBox(height: 16),

          // ── Business SME Card ──
          _EntityCard(
            icon: Icons.business_center_outlined,
            title: smeTitle,
            description: smeDesc,
            isSelected: provider.entityType == 'registered_sme',
            onTap: () => provider.setEntityType('registered_sme'),
          ),

          const SizedBox(height: 32),

          // ── Security Badge ──
          Center(
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.lock_rounded,
                  size: 14,
                  color: theme.colorScheme.onSurfaceVariant,
                ),
                const SizedBox(width: 6),
                Text(
                  // TODO: Implement i18n
                  'SECURE 256-BIT ENCRYPTED REGISTRATION',
                  style: theme.textTheme.labelMedium?.copyWith(
                    fontSize: 11,
                    letterSpacing: 0.5,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// A large tappable selection card with icon, title, and description.
class _EntityCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String description;
  final bool isSelected;
  final VoidCallback onTap;

  const _EntityCard({
    required this.icon,
    required this.title,
    required this.description,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        width: double.infinity,
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: theme.colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(AppTheme.radiusLarge),
          border: Border.all(
            color: isSelected ? AppTheme.primary : Colors.transparent,
            width: 2,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: isSelected
                    ? AppTheme.primary.withValues(alpha: 0.15)
                    : theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
              ),
              child: Icon(
                icon,
                color: isSelected
                    ? AppTheme.primary
                    : theme.colorScheme.onSurfaceVariant,
                size: 24,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              title,
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              description,
              style: theme.textTheme.bodyLarge,
            ),
          ],
        ),
      ),
    );
  }
}
