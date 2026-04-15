import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/app_theme.dart';
import '../../providers/onboarding_provider.dart';
import '../../widgets/tin_guide_bottom_sheet.dart';
import '../../core/validators.dart';

/// Step 1 of 3: Business Details — Name, TIN, BRN, MSIC Code.
/// Includes the TIN Registration Guide link from Figma.
class StepBusinessDetails extends StatefulWidget {
  const StepBusinessDetails({super.key});

  @override
  State<StepBusinessDetails> createState() => _StepBusinessDetailsState();
}

class _StepBusinessDetailsState extends State<StepBusinessDetails> {
  late TextEditingController _nameController;
  late TextEditingController _tinController;
  late TextEditingController _brnController;
  late TextEditingController _activityDescController;
  late TextEditingController _sstController;
  late TextEditingController _tourismTaxController;

  @override
  void initState() {
    super.initState();
    final provider = context.read<OnboardingProvider>();
    _nameController = TextEditingController(text: provider.businessName);
    _tinController = TextEditingController(text: provider.tinNumber);
    _brnController = TextEditingController(text: provider.brnNumber);
    _activityDescController = TextEditingController(text: provider.businessActivityDescription);
    _sstController = TextEditingController(text: provider.hasSst ? provider.sstNumber : '');
    _tourismTaxController = TextEditingController(text: provider.hasTourismTax ? provider.tourismTaxNumber : '');
  }

  @override
  void dispose() {
    _nameController.dispose();
    _tinController.dispose();
    _brnController.dispose();
    _activityDescController.dispose();
    _sstController.dispose();
    _tourismTaxController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final provider = context.watch<OnboardingProvider>(); // Use watch to react to state changes

    // TODO: Implement i18n
    const title = 'Business Details';
    const subtitle = 'Provide your official trade information.';
    const businessNameLabel = 'Business Name*';
    const businessNameHint = 'Enter your registered name';
    const tinLabel = 'TIN Number*';
    const tinGuideText = 'TIN Registration Guide';
    const tinHint = 'e.g. TR123456789';
    final brnLabel = provider.entityType == 'Person' 
        ? 'MyKad / Passport Number*' 
        : 'SSM Registration Number*';
    final brnHint = provider.entityType == 'Person' 
        ? 'e.g. 900101-14-1234' 
        : 'e.g. 202301012345';
    const msicLabel = 'Industry (MSIC Code)*';
    const msicHint = 'Select your industry';
    const activityDescLabel = 'Business Activity Description*';
    const activityDescHint = 'Brief description of your business activity';
    
    // Taxes
    const sstToggleLabel = 'Registered for Sales & Service Tax (SST)?';
    const sstLabel = 'SST Registration Number*';
    const sstHint = 'Enter your SST number';
    const tourismTaxToggleLabel = 'Registered for Tourism Tax?';
    const tourismTaxLabel = 'Tourism Tax Registration Number*';
    const tourismTaxHint = 'Enter your Tourism Tax number';

    // Placeholder dropdown items — PM will add full list later
    final msicItems = <String>[
      '47111 - Retail (General)',
      '56101 - Food & Beverage',
      '49100 - Transport Services',
      '62010 - IT Services',
      '96091 - Other Personal Services',
    ];

    return Form(
      key: provider.stepBusinessKey,
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

          // ── Business Name ──
          _buildFieldLabel(
              theme, businessNameLabel, Icons.storefront_outlined),
          const SizedBox(height: 8),
          TextFormField(
            controller: _nameController,
            textCapitalization: TextCapitalization.words,
            validator: (v) => AppValidators.requiredField(v, businessNameLabel.replaceAll('*', '')),
            decoration: const InputDecoration(hintText: businessNameHint),
            onChanged: provider.setBusinessName,
          ),
          const SizedBox(height: 24),

          // ── TIN Number + Guide Link ──
          Row(
            children: [
              Icon(Icons.badge_outlined,
                  size: 18, color: theme.colorScheme.onSurfaceVariant),
              const SizedBox(width: 8),
              Text(
                tinLabel,
                style: theme.textTheme.labelMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(width: 12),
              GestureDetector(
                onTap: () {
                  showModalBottomSheet(
                    context: context,
                    isScrollControlled: true,
                    backgroundColor: Colors.transparent,
                    builder: (_) => const TinGuideBottomSheet(),
                  );
                },
                child: Text(
                  tinGuideText,
                  style: theme.textTheme.labelMedium?.copyWith(
                    color: AppTheme.primary,
                    fontWeight: FontWeight.w600,
                    decoration: TextDecoration.underline,
                    decorationColor: AppTheme.primary,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          TextFormField(
            controller: _tinController,
            validator: AppValidators.tin,
            decoration: InputDecoration(
              hintText: tinHint,
              suffixIcon: IconButton(
                onPressed: () {
                  showModalBottomSheet(
                    context: context,
                    isScrollControlled: true,
                    backgroundColor: Colors.transparent,
                    builder: (_) => const TinGuideBottomSheet(),
                  );
                },
                icon: Icon(
                  Icons.info_outline_rounded,
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ),
            onChanged: provider.setTinNumber,
          ),
          const SizedBox(height: 24),

          // ── BRN Number (Dynamic) ──
          _buildFieldLabel(theme, brnLabel, Icons.description_outlined),
          const SizedBox(height: 8),
          TextFormField(
            controller: _brnController,
            validator: (v) => AppValidators.brn(v, provider.entityType),
            decoration: InputDecoration(hintText: brnHint),
            onChanged: provider.setBrnNumber,
          ),
          const SizedBox(height: 24),

          // ── MSIC Code Dropdown ──
          _buildFieldLabel(theme, msicLabel, Icons.category_outlined),
          const SizedBox(height: 8),
          DropdownButtonFormField<String>(
            initialValue: provider.msicCode.isEmpty ? null : provider.msicCode,
            hint: Text(
              msicHint,
              style: theme.textTheme.bodyLarge?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            decoration: const InputDecoration(),
            dropdownColor: theme.colorScheme.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
            items: msicItems.map((item) {
              return DropdownMenuItem(
                value: item,
                child: Text(
                  item,
                  style: theme.textTheme.bodyLarge?.copyWith(
                    color: theme.colorScheme.onSurface,
                  ),
                ),
              );
            }).toList(),
            validator: (v) => AppValidators.requiredField(v, 'Industry (MSIC Code)'),
            onChanged: (value) {
              if (value != null) provider.setMsicCode(value);
            },
          ),
          const SizedBox(height: 24),

          // ── Business Activity Description ──
          _buildFieldLabel(theme, activityDescLabel, Icons.article_outlined),
          const SizedBox(height: 8),
          TextFormField(
            controller: _activityDescController,
            textCapitalization: TextCapitalization.sentences,
            validator: (v) => AppValidators.requiredField(v, activityDescLabel.replaceAll('*', '')),
            decoration: const InputDecoration(hintText: activityDescHint),
            onChanged: provider.setBusinessActivityDescription,
          ),
          const SizedBox(height: 32),
          
          // ── Divider ──
          Divider(color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.2)),
          const SizedBox(height: 16),

          // ── SST Toggle ──
          SwitchListTile.adaptive(
            contentPadding: EdgeInsets.zero,
            title: Text(
              sstToggleLabel,
              style: theme.textTheme.bodyLarge,
            ),
            value: provider.hasSst,
            activeColor: AppTheme.primary,
            onChanged: provider.setHasSst,
          ),
          if (provider.hasSst) ...[
            const SizedBox(height: 16),
            _buildFieldLabel(theme, sstLabel, Icons.receipt_long_outlined),
            const SizedBox(height: 8),
            TextFormField(
              controller: _sstController,
              decoration: const InputDecoration(hintText: sstHint),
              onChanged: provider.setSstNumber,
            ),
          ],
          const SizedBox(height: 16),

          // ── Tourism Tax Toggle ──
          SwitchListTile.adaptive(
            contentPadding: EdgeInsets.zero,
            title: Text(
              tourismTaxToggleLabel,
              style: theme.textTheme.bodyLarge,
            ),
            value: provider.hasTourismTax,
            activeColor: AppTheme.primary,
            onChanged: provider.setHasTourismTax,
          ),
          if (provider.hasTourismTax) ...[
            const SizedBox(height: 16),
            _buildFieldLabel(theme, tourismTaxLabel, Icons.flight_takeoff_rounded),
            const SizedBox(height: 8),
            TextFormField(
              controller: _tourismTaxController,
              decoration: const InputDecoration(hintText: tourismTaxHint),
              onChanged: provider.setTourismTaxNumber,
            ),
          ],

          const SizedBox(height: 48), // Bottom padding
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
