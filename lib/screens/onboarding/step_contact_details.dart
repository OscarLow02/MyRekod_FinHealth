import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:provider/provider.dart';
import '../../providers/onboarding_provider.dart';
import '../../core/validators.dart';
import '../../widgets/phone_input_field.dart';
import '../../widgets/custom_widgets.dart';

/// Step 2 of 3: Contact Details — Phone Number and Email.
/// Email is pre-filled from the authenticated user if available.
class StepContactDetails extends StatefulWidget {
  const StepContactDetails({super.key});

  @override
  State<StepContactDetails> createState() => _StepContactDetailsState();
}

class _StepContactDetailsState extends State<StepContactDetails> {
  late TextEditingController _phoneController;
  late TextEditingController _emailController;
  late TextEditingController _bankAccountController;

  @override
  void initState() {
    super.initState();
    final provider = context.read<OnboardingProvider>();
    _phoneController = TextEditingController(text: provider.phoneNumber);
    _bankAccountController =
        TextEditingController(text: provider.bankAccountNumber);

    // Pre-fill email from Firebase Auth if the provider email is empty
    final authEmail = FirebaseAuth.instance.currentUser?.email ?? '';
    final initialEmail = provider.email.isNotEmpty ? provider.email : authEmail;
    _emailController = TextEditingController(text: initialEmail);

    // Sync the pre-filled email back to the provider
    if (provider.email.isEmpty && authEmail.isNotEmpty) {
      provider.setEmail(authEmail);
    }

    // PhoneInputField writes the full international number (+dialCode+digits) into
    // _phoneController via its internal listener — we forward that to the provider here.
    _phoneController.addListener(() {
      provider.setPhoneNumber(_phoneController.text);
    });
  }

  @override
  void dispose() {
    _phoneController.dispose();
    _emailController.dispose();
    _bankAccountController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final provider = context.read<OnboardingProvider>();

    // TODO: Implement i18n
    const title = 'Contact Details';
    const subtitle = 'How can your customers reach you?';
    const phoneLabel = 'Phone Number*';
    const emailLabel = 'Email Address';
    const emailHint = 'name@business.com (Optional)';
    const bankAccountLabel = 'Bank Account Number';
    const bankAccountHint = 'e.g. 114000112233 (Optional)';

    return Form(
      key: provider.stepContactKey,
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 16),

            // ── Title ──
            Text(title, style: theme.textTheme.headlineLarge),
            const SizedBox(height: 8),
            Text(subtitle, style: theme.textTheme.bodyLarge),
            const SizedBox(height: 32),

            // ── Phone Number ──
            PhoneInputField(
              label: phoneLabel,
              controller: _phoneController,
              hint: '12 345 6789',
            ),
            const SizedBox(height: 24),

            // ── Email ──
            _buildFieldLabel(theme, emailLabel, Icons.mail_outline_rounded),
            const SizedBox(height: 8),
            AppTextField(
              controller: _emailController,
              keyboardType: TextInputType.emailAddress,
              validator: AppValidators.email,
              hintText: emailHint,
              onChanged: provider.setEmail,
            ),
            const SizedBox(height: 24),

            // ── Bank Account (Optional) ──
            _buildFieldLabel(
                theme, bankAccountLabel, Icons.account_balance_outlined),
            const SizedBox(height: 8),
            AppTextField(
              controller: _bankAccountController,
              keyboardType: TextInputType.number,
              validator: (v) => AppValidators.numeric(v, bankAccountLabel),
              hintText: bankAccountHint,
              onChanged: provider.setBankAccountNumber,
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  Widget _buildFieldLabel(ThemeData theme, String label, IconData icon) {
    return Row(
      children: [
        Icon(icon, size: 18, color: theme.colorScheme.onSurfaceVariant),
        const SizedBox(width: 8),
        Text(
          label,
          style: theme.textTheme.labelMedium?.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}
