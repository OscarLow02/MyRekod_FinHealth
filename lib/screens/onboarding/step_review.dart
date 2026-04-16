import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/app_theme.dart';
import '../../providers/onboarding_provider.dart';

/// Final Review step matching Figma "Check your details" screen.
/// Shows a read-only summary of all entered data before submission.
class StepReview extends StatelessWidget {
  const StepReview({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final provider = context.watch<OnboardingProvider>();

    // TODO: Implement i18n
    const title = 'Check your details';
    const subtitle =
        'Ensure everything is correct before we\nset up your business vault.';
    const securityText = 'Bank-grade data encryption';
    const termsText =
        'By confirming, you agree to the Merchant\nTerms of Service';

    // Format entity type for display
    final entityDisplay = provider.entityType == 'sole_trader'
        ? 'Sole Proprietorship'
        : 'Registered SME';

    final taxDetails = [
      'MSIC: ${provider.msicCode.isEmpty ? '—' : provider.msicCode}',
      'Act: ${provider.businessActivityDescription.isEmpty ? '—' : provider.businessActivityDescription}',
      'SST: ${provider.hasSst ? provider.sstNumber : 'NA'}',
      'TTx: ${provider.hasTourismTax ? provider.tourismTaxNumber : 'NA'}',
    ].join('\n');

    final contactDetails = [
      if (provider.phoneNumber.isNotEmpty) provider.phoneNumber,
      if (provider.email.isNotEmpty) provider.email,
      if (provider.bankAccountNumber.isNotEmpty)
        'Bank: ${provider.bankAccountNumber}'
      else
        'Bank: —',
    ].join('\n');

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 16),

          // ── Title ──
          Text(title, style: theme.textTheme.headlineLarge),
          const SizedBox(height: 8),
          Text(subtitle, style: theme.textTheme.bodyLarge),
          const SizedBox(height: 24),

          // ── Entity Type Card ──
          _ReviewCard(
            icon: Icons.person_outline_rounded,
            label: 'ENTITY TYPE',
            value: entityDisplay,
          ),
          const SizedBox(height: 12),

          // ── Business Name Card ──
          _ReviewCard(
            icon: Icons.storefront_outlined,
            label: 'BUSINESS NAME',
            value: provider.businessName.isEmpty ? '—' : provider.businessName,
          ),
          const SizedBox(height: 12),

          // ── Taxes & Legal Card ──
          _ReviewCard(
            icon: Icons.badge_outlined,
            label: 'TAX & REGISTRATION',
            value:
                'TIN: ${provider.tinNumber.isEmpty ? '—' : provider.tinNumber}\n'
                'BRN: ${provider.brnNumber.isEmpty ? '—' : provider.brnNumber}\n'
                '$taxDetails',
          ),
          const SizedBox(height: 12),

          // ── Contact Card ──
          _ReviewCard(
            icon: Icons.phone_outlined,
            label: 'CONTACT',
            value: contactDetails.isEmpty ? '—' : contactDetails,
          ),
          const SizedBox(height: 12),

          // ── Address Card ──
          _ReviewCard(
            icon: Icons.location_on_outlined,
            label: 'ADDRESS',
            value: _formatAddress(provider),
          ),
          const SizedBox(height: 24),

          // ── Security Badge ──
          Center(
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.verified_user_rounded,
                  size: 16,
                  color: AppTheme.neonGreenDark,
                ),
                const SizedBox(width: 6),
                Text(
                  securityText,
                  style: theme.textTheme.labelMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // ── Terms ──
          Center(
            child: Text(
              termsText,
              textAlign: TextAlign.center,
              style: theme.textTheme.labelMedium?.copyWith(
                fontSize: 12,
              ),
            ),
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  String _formatAddress(OnboardingProvider provider) {
    final parts = <String>[];
    if (provider.addressLine1.isNotEmpty) parts.add(provider.addressLine1);
    if (provider.addressLine2.isNotEmpty) parts.add(provider.addressLine2);
    if (provider.addressLine3.isNotEmpty) parts.add(provider.addressLine3);

    final cityState = <String>[];
    if (provider.city.isNotEmpty) cityState.add(provider.city);
    if (provider.stateCode.isNotEmpty) cityState.add(provider.stateCode);
    if (provider.postalCode.isNotEmpty) cityState.add(provider.postalCode);

    if (cityState.isNotEmpty) parts.add(cityState.join(', '));

    return parts.isEmpty ? '—' : parts.join('\n');
  }
}

/// A themed summary card for the review step.
class _ReviewCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _ReviewCard({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final borderColor = AppTheme.secondaryDark; // #B6A4F3

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
        border: Border.all(
          color: borderColor.withValues(alpha: 0.5),
          width: 1,
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: AppTheme.primary.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: AppTheme.primary, size: 20),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: theme.textTheme.labelMedium?.copyWith(
                    fontSize: 11,
                    letterSpacing: 0.5,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  value,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                    height: 1.4,
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
