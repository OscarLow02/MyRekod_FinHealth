import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/app_theme.dart';
import '../../providers/onboarding_provider.dart';
import '../../widgets/custom_dropdown.dart';

/// Step 3 of 3: Registered Address — Address lines, City, State, Postcode.
/// Uses a dropdown for Malaysian state codes.
class StepAddress extends StatefulWidget {
  const StepAddress({super.key});

  @override
  State<StepAddress> createState() => _StepAddressState();
}

class _StepAddressState extends State<StepAddress> {
  late TextEditingController _address1Controller;
  late TextEditingController _address2Controller;
  late TextEditingController _address3Controller;
  late TextEditingController _cityController;
  late TextEditingController _postcodeController;

  // Standard Malaysian state codes
  // TODO: Implement i18n — state names may require translation
  static const List<Map<String, String>> _malaysianStates = [
    {'code': 'JHR', 'name': 'Johor'},
    {'code': 'KDH', 'name': 'Kedah'},
    {'code': 'KTN', 'name': 'Kelantan'},
    {'code': 'MLK', 'name': 'Melaka'},
    {'code': 'NSN', 'name': 'Negeri Sembilan'},
    {'code': 'PHG', 'name': 'Pahang'},
    {'code': 'PRK', 'name': 'Perak'},
    {'code': 'PLS', 'name': 'Perlis'},
    {'code': 'PNG', 'name': 'Pulau Pinang'},
    {'code': 'SBH', 'name': 'Sabah'},
    {'code': 'SWK', 'name': 'Sarawak'},
    {'code': 'SGR', 'name': 'Selangor'},
    {'code': 'TRG', 'name': 'Terengganu'},
    {'code': 'KUL', 'name': 'W.P. Kuala Lumpur'},
    {'code': 'PJY', 'name': 'W.P. Putrajaya'},
    {'code': 'LBN', 'name': 'W.P. Labuan'},
  ];

  @override
  void initState() {
    super.initState();
    final provider = context.read<OnboardingProvider>();
    _address1Controller = TextEditingController(text: provider.addressLine1);
    _address2Controller = TextEditingController(text: provider.addressLine2);
    _address3Controller = TextEditingController(text: provider.addressLine3);
    _cityController = TextEditingController(text: provider.city);
    _postcodeController = TextEditingController(text: provider.postalCode);
  }

  @override
  void dispose() {
    _address1Controller.dispose();
    _address2Controller.dispose();
    _address3Controller.dispose();
    _cityController.dispose();
    _postcodeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final provider = context.watch<OnboardingProvider>();

    // TODO: Implement i18n
    const title = 'Registered Address';
    const subtitle = 'Where is your business officially located?';
    const address1Label = 'Address Line 1*';
    const address1Hint = 'Street name, building, unit number';
    const address2Label = 'Address Line 2 (Optional)';
    const address2Hint = 'Floor, suite, apartment, etc.';
    const address3Label = 'Address Line 3 (Optional)';
    const address3Hint = 'Additional address info';
    const cityLabel = 'City*';
    const cityHint = 'e.g. Petaling Jaya';
    const stateLabel = 'State*';
    const stateHint = 'Select your state';
    const postcodeLabel = 'Postcode*';
    const postcodeHint = 'e.g. 47600';

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
          const SizedBox(height: 32),

          // ── Address Line 1 ──
          _buildFieldLabel(theme, address1Label, Icons.location_on_outlined),
          const SizedBox(height: 8),
          TextFormField(
            controller: _address1Controller,
            textCapitalization: TextCapitalization.words,
            decoration: const InputDecoration(hintText: address1Hint),
            onChanged: provider.setAddressLine1,
          ),
          const SizedBox(height: 24),

          // ── Address Line 2 ──
          _buildFieldLabel(
              theme, address2Label, Icons.location_city_outlined),
          const SizedBox(height: 8),
          TextFormField(
            controller: _address2Controller,
            textCapitalization: TextCapitalization.words,
            decoration: const InputDecoration(hintText: address2Hint),
            onChanged: provider.setAddressLine2,
          ),
          const SizedBox(height: 24),

          // ── Address Line 3 ──
          _buildFieldLabel(
              theme, address3Label, Icons.add_business_outlined),
          const SizedBox(height: 8),
          TextFormField(
            controller: _address3Controller,
            textCapitalization: TextCapitalization.words,
            decoration: const InputDecoration(hintText: address3Hint),
            onChanged: provider.setAddressLine3,
          ),
          const SizedBox(height: 24),

          // ── City ──
          _buildFieldLabel(theme, cityLabel, Icons.apartment_outlined),
          const SizedBox(height: 8),
          TextFormField(
            controller: _cityController,
            textCapitalization: TextCapitalization.words,
            decoration: const InputDecoration(hintText: cityHint),
            onChanged: provider.setCity,
          ),
          const SizedBox(height: 24),

          CustomPremiumDropdown<String>(
            label: stateLabel,
            hint: stateHint,
            items: _malaysianStates.map((state) => CustomDropdownItem<String>(
              label: '${state['name']} (${state['code']})',
              value: state['code']!,
              icon: Icons.map_outlined,
            )).toList(),
            value: provider.stateCode.isEmpty ? null : provider.stateCode,
            onChanged: (value) {
              if (value != null) provider.setStateCode(value);
            },
            isSearchable: true,
          ),
          const SizedBox(height: 24),

          // ── Postcode ──
          _buildFieldLabel(theme, postcodeLabel, Icons.pin_outlined),
          const SizedBox(height: 8),
          TextFormField(
            controller: _postcodeController,
            keyboardType: TextInputType.number,
            maxLength: 5,
            decoration: const InputDecoration(
              hintText: postcodeHint,
              counterText: '', // Hide character counter
            ),
            onChanged: provider.setPostalCode,
          ),
          const SizedBox(height: 24),
        ],
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
