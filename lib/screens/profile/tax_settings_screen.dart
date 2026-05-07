import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../core/app_theme.dart';
import '../../models/tax_config.dart';
import '../../core/lhdn_constants.dart';
import '../../services/firestore_service.dart';
import '../../widgets/custom_dropdown.dart';

/// Tax & Financial Settings screen.
/// Section 1: Global Tax Configuration (dropdown + fields).
/// Section 2: Expense Categories management.
class TaxSettingsScreen extends StatefulWidget {
  const TaxSettingsScreen({super.key});

  @override
  State<TaxSettingsScreen> createState() => _TaxSettingsScreenState();
}

class _TaxSettingsScreenState extends State<TaxSettingsScreen> {
  // ── Firebase ──
  final _fs = FirestoreService();
  String? _userId;

  // ── Loading / saving state ──
  bool _isLoading = true;
  bool _isSaving = false;

  // ── Tax Configuration State ──
  String _defaultTaxType = '06'; // '06' = Not Applicable
  final TextEditingController _taxRateCtrl = TextEditingController();
  final TextEditingController _numUnitsCtrl = TextEditingController();
  final TextEditingController _ratePerUnitCtrl = TextEditingController();
  final TextEditingController _taxExemptionCtrl = TextEditingController();

  void _onFieldChange() {
    setState(() {}); // trigger rebuild to update enabled states
  }

  @override
  void initState() {
    super.initState();
    _userId = FirebaseAuth.instance.currentUser?.uid;
    _taxRateCtrl.addListener(_onFieldChange);
    _numUnitsCtrl.addListener(_onFieldChange);
    _ratePerUnitCtrl.addListener(_onFieldChange);
    _loadData();
  }

  Future<void> _loadData() async {
    if (_userId == null) {
      setState(() => _isLoading = false);
      return;
    }
    try {
      final taxConfig = await _fs.getTaxConfig(_userId!);
      if (mounted) {
        setState(() {
          _defaultTaxType = taxConfig.defaultTaxType;
          _taxRateCtrl.text = taxConfig.taxRate?.toString() ?? '';
          _numUnitsCtrl.text = taxConfig.numUnits?.toString() ?? '';
          _ratePerUnitCtrl.text = taxConfig.ratePerUnit?.toString() ?? '';
          _taxExemptionCtrl.text = taxConfig.taxExemptionDetails ?? '';
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  void dispose() {
    _taxRateCtrl.removeListener(_onFieldChange);
    _numUnitsCtrl.removeListener(_onFieldChange);
    _ratePerUnitCtrl.removeListener(_onFieldChange);
    _taxRateCtrl.dispose();
    _numUnitsCtrl.dispose();
    _ratePerUnitCtrl.dispose();
    _taxExemptionCtrl.dispose();
    super.dispose();
  }

  bool get _isTaxEnabled => _defaultTaxType != '06';

  bool get _isTaxRateEnabled =>
      _isTaxEnabled &&
      _numUnitsCtrl.text.isEmpty &&
      _ratePerUnitCtrl.text.isEmpty;

  bool get _isSpecificEnabled => _isTaxEnabled && _taxRateCtrl.text.isEmpty;

  // ── Save tax config to Firestore ──
  Future<void> _saveTaxConfig() async {
    if (_userId == null) return;
    setState(() => _isSaving = true);
    try {
      final config = TaxConfig(
        defaultTaxType: _defaultTaxType,
        taxRate: _isTaxRateEnabled && _taxRateCtrl.text.isNotEmpty
            ? double.tryParse(_taxRateCtrl.text)
            : null,
        numUnits: _isSpecificEnabled && _numUnitsCtrl.text.isNotEmpty
            ? double.tryParse(_numUnitsCtrl.text)
            : null,
        ratePerUnit: _isSpecificEnabled && _ratePerUnitCtrl.text.isNotEmpty
            ? double.tryParse(_ratePerUnitCtrl.text)
            : null,
        taxExemptionDetails: _taxExemptionCtrl.text.trim().isEmpty
            ? null
            : _taxExemptionCtrl.text.trim(),
      );
      await _fs.saveTaxConfig(_userId!, config);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Row(
              children: [
                Icon(Icons.check_circle_rounded, color: Colors.white, size: 20),
                SizedBox(width: 12),
                Text('Tax settings saved!'),
              ],
            ),
            backgroundColor: AppTheme.neonGreenDark,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppTheme.radiusSmall),
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to save: $e'),
            backgroundColor: Colors.redAccent,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          onPressed: () => Navigator.of(context).pop(),
          icon: const Icon(Icons.arrow_back_rounded),
          style: IconButton.styleFrom(
            minimumSize: const Size(
              AppTheme.minTouchTarget,
              AppTheme.minTouchTarget,
            ),
          ),
        ),
        title: const Text('Profile'),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ── Page Title ──
                  Text(
                    'Tax Settings',
                    style: theme.textTheme.headlineMedium?.copyWith(
                      color: AppTheme.primary,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Configure your LHDN tax compliance and financial rules.',
                    style: theme.textTheme.bodyLarge,
                  ),
                  const SizedBox(height: 28),

                  // ═══════════════════════════════
                  // Section 1: Tax Configuration
                  // ═══════════════════════════════
                  _buildSectionHeader(
                    theme,
                    icon: Icons.account_balance_outlined,
                    title: 'GLOBAL TAX CONFIGURATION',
                  ),
                  const SizedBox(height: 12),
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
                        // Tax Type Dropdown
                        CustomPremiumDropdown<String>(
                          label: 'Default Tax Type',
                          items: CustomDropdownBuilder.fromMap(
                            LhdnConstants.taxTypes,
                            icon: Icons.percent_rounded,
                          ),
                          value: _defaultTaxType,
                          onChanged: (val) {
                            if (val != null) {
                              setState(() {
                                _defaultTaxType = val;
                                if (val == '06') _taxRateCtrl.clear();
                              });
                            }
                          },
                          fillColor: theme.scaffoldBackgroundColor,
                          hint: 'Select Tax Type',
                        ),
                        const SizedBox(height: 20),

                        // Specific Tax (Units & Rate)
                        Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Number of Units',
                                    style: theme.textTheme.labelMedium
                                        ?.copyWith(fontWeight: FontWeight.w500),
                                  ),
                                  const SizedBox(height: 8),
                                  _buildTaxTextField(
                                    controller: _numUnitsCtrl,
                                    enabled: _isSpecificEnabled,
                                    hintText: 'Units',
                                    theme: theme,
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Rate per Unit',
                                    style: theme.textTheme.labelMedium
                                        ?.copyWith(fontWeight: FontWeight.w500),
                                  ),
                                  const SizedBox(height: 8),
                                  _buildTaxTextField(
                                    controller: _ratePerUnitCtrl,
                                    enabled: _isSpecificEnabled,
                                    hintText: 'Rate',
                                    theme: theme,
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),

                        // Tax Rate
                        Text(
                          'Tax Rate',
                          style: theme.textTheme.labelMedium?.copyWith(
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            Expanded(
                              child: _buildTaxTextField(
                                controller: _taxRateCtrl,
                                enabled: _isTaxRateEnabled,
                                hintText: 'Rate',
                                theme: theme,
                              ),
                            ),
                            const SizedBox(width: 12),
                            // % Percentage chip
                            Container(
                              height: AppTheme.minTouchTarget,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                              ),
                              alignment: Alignment.center,
                              decoration: BoxDecoration(
                                color: _isTaxRateEnabled
                                    ? theme.scaffoldBackgroundColor
                                    : theme.scaffoldBackgroundColor.withValues(
                                        alpha: 0.5,
                                      ),
                                borderRadius: BorderRadius.circular(
                                  AppTheme.radiusMedium,
                                ),
                              ),
                              child: Text(
                                '% Percentage',
                                style: theme.textTheme.bodyLarge?.copyWith(
                                  fontSize: 14,
                                  color: _isTaxRateEnabled
                                      ? theme.colorScheme.onSurfaceVariant
                                      : theme.colorScheme.onSurfaceVariant
                                            .withValues(alpha: 0.4),
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 20),

                        // Tax Exemption Details
                        Text(
                          'Tax Exemption Details (Optional)',
                          style: theme.textTheme.labelMedium?.copyWith(
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(height: 8),
                        TextFormField(
                          controller: _taxExemptionCtrl,
                          style: theme.textTheme.bodyLarge,
                          decoration: InputDecoration(
                            prefixIcon: Icon(
                              Icons.description_outlined,
                              size: 20,
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                            hintText: 'e.g., Certificate Number',
                            filled: true,
                            fillColor: theme.scaffoldBackgroundColor,
                            // Border inherited from global theme
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  // Save Tax Config Button
                  SizedBox(
                    width: double.infinity,
                    height: AppTheme.minTouchTarget + 4,
                    child: ElevatedButton.icon(
                      onPressed: _isSaving ? null : _saveTaxConfig,
                      icon: _isSaving
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor: AlwaysStoppedAnimation<Color>(
                                  Colors.white,
                                ),
                              ),
                            )
                          : const Icon(Icons.save_rounded, size: 20),
                      label: Text(_isSaving ? 'SAVING…' : 'SAVE TAX SETTINGS'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.primary,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(
                            AppTheme.radiusMedium,
                          ),
                        ),
                        elevation: 0,
                      ),
                    ),
                  ),
                  const SizedBox(height: 32),
                  const SizedBox(height: 32),
                ],
              ),
            ),
    );
  }

  // ── Section header with icon ──
  Widget _buildSectionHeader(
    ThemeData theme, {
    required IconData icon,
    required String title,
  }) {
    return Row(
      children: [
        Icon(icon, size: 18, color: AppTheme.primary),
        const SizedBox(width: 8),
        Text(
          title,
          style: theme.textTheme.labelMedium?.copyWith(
            fontWeight: FontWeight.w700,
            letterSpacing: 1.0,
            color: theme.colorScheme.onSurface,
          ),
        ),
      ],
    );
  }

  Widget _buildTaxTextField({
    required TextEditingController controller,
    required bool enabled,
    required String hintText,
    required ThemeData theme,
  }) {
    return TextFormField(
      controller: controller,
      enabled: enabled,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      textAlign: TextAlign.center,
      style: theme.textTheme.bodyLarge?.copyWith(
        color: enabled
            ? null
            : theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.4),
      ),
      decoration: InputDecoration(
        hintText: hintText,
        fillColor: enabled
            ? theme.scaffoldBackgroundColor
            : theme.scaffoldBackgroundColor.withValues(alpha: 0.5),
        // Border inherited from global theme
      ),
    );
  }

}
