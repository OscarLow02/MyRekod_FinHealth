import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../core/app_theme.dart';
import '../../models/tax_config.dart';
import '../../core/lhdn_constants.dart';
import '../../services/firestore_service.dart';
import '../../widgets/custom_dropdown.dart';
import '../../widgets/app_dialogs.dart';

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

  // ── UI Redesign State ──
  bool _isUnitBased = false;
  bool _isExemptionEnabled = false;

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

          // Infer UI state from data
          _isUnitBased = taxConfig.numUnits != null || taxConfig.ratePerUnit != null;
          _isExemptionEnabled = taxConfig.taxExemptionDetails != null;

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

  // ── Save tax config to Firestore ──
  Future<void> _saveTaxConfig() async {
    if (_userId == null) return;
    setState(() => _isSaving = true);
    try {
      final bool isNA = _defaultTaxType == '06';
      final config = TaxConfig(
        defaultTaxType: _defaultTaxType,
        // Total Percentage mode: save taxRate, clear unit fields
        taxRate: !isNA && !_isUnitBased && _taxRateCtrl.text.isNotEmpty
            ? double.tryParse(_taxRateCtrl.text)
            : null,
        // Unit-Based mode: save unit fields, clear taxRate
        numUnits: !isNA && _isUnitBased && _numUnitsCtrl.text.isNotEmpty
            ? double.tryParse(_numUnitsCtrl.text)
            : null,
        ratePerUnit: !isNA && _isUnitBased && _ratePerUnitCtrl.text.isNotEmpty
            ? double.tryParse(_ratePerUnitCtrl.text)
            : null,
        taxExemptionDetails: (!isNA && _isExemptionEnabled && _taxExemptionCtrl.text.trim().isNotEmpty)
            ? _taxExemptionCtrl.text.trim()
            : null,
      );
      await _fs.saveTaxConfig(_userId!, config);
      if (mounted) {
        AppDialogs.showSystemAlert(
          context,
          title: 'Tax Settings Saved',
          body: 'Your global tax configuration and calculation methods have been successfully updated.',
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
    final bool isTaxNotApplicable = _defaultTaxType == '06';

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
                  _buildCardSection(
                    theme,
                    title: 'GLOBAL TAX CONFIGURATION',
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        CustomPremiumDropdown<String>(
                          label: 'Tax Type',
                          items: CustomDropdownBuilder.fromMap(
                            LhdnConstants.taxTypes,
                            icon: Icons.description_rounded,
                          ),
                          value: _defaultTaxType,
                          onChanged: (val) {
                            if (val != null) {
                              setState(() => _defaultTaxType = val);
                            }
                          },
                          fillColor: theme.colorScheme.surface,
                          hint: 'Select Tax Type',
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),

                  // ═══════════════════════════════
                  // Section 2: Calculation Method
                  // ═══════════════════════════════
                  _buildCardSection(
                    theme,
                    title: 'CALCULATION METHOD',
                    child: isTaxNotApplicable
                        ? _buildDisabledState(
                            theme,
                            'No active calculation method',
                            Icons.visibility_off_rounded,
                          )
                        : Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Segmented Control
                              Container(
                                padding: const EdgeInsets.all(6),
                                decoration: BoxDecoration(
                                  color: theme.colorScheme.surface,
                                  borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
                                ),
                                child: Row(
                                  children: [
                                    _buildSegmentTab(
                                      theme,
                                      label: 'Total Percentage',
                                      isActive: !_isUnitBased,
                                      onTap: () => setState(() => _isUnitBased = false),
                                    ),
                                    _buildSegmentTab(
                                      theme,
                                      label: 'Unit-Based',
                                      isActive: _isUnitBased,
                                      onTap: () => setState(() => _isUnitBased = true),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 24),

                              if (!_isUnitBased) ...[
                                // Total Percentage Mode
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(
                                      'Tax Rate',
                                      style: theme.textTheme.labelMedium?.copyWith(
                                        fontWeight: FontWeight.w600,
                                        color: theme.colorScheme.onSurfaceVariant,
                                      ),
                                    ),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: theme.colorScheme.surfaceContainerHighest,
                                        borderRadius: BorderRadius.circular(4),
                                      ),
                                      child: Text(
                                        'Required',
                                        style: theme.textTheme.labelSmall?.copyWith(
                                          color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.6),
                                          fontSize: 10,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 12),
                                _buildLargeNumericInput(
                                  theme,
                                  controller: _taxRateCtrl,
                                  suffixText: '%',
                                  hintText: '0.00',
                                ),
                                const SizedBox(height: 16),
                                Row(
                                  children: [
                                    Icon(
                                      Icons.info_outline_rounded,
                                      size: 14,
                                      color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.6),
                                    ),
                                    const SizedBox(width: 8),
                                    Text(
                                      'Applied to the total item subtotal.',
                                      style: theme.textTheme.bodySmall?.copyWith(
                                        color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.6),
                                      ),
                                    ),
                                  ],
                                ),
                              ] else ...[
                                // Unit-Based Mode
                                Row(
                                  children: [
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            'Number of Units',
                                            style: theme.textTheme.labelMedium?.copyWith(
                                              fontWeight: FontWeight.w600,
                                              color: theme.colorScheme.onSurfaceVariant,
                                            ),
                                          ),
                                          const SizedBox(height: 8),
                                          _buildTaxTextField(
                                            controller: _numUnitsCtrl,
                                            enabled: true,
                                            hintText: '0',
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
                                            style: theme.textTheme.labelMedium?.copyWith(
                                              fontWeight: FontWeight.w600,
                                              color: theme.colorScheme.onSurfaceVariant,
                                            ),
                                          ),
                                          const SizedBox(height: 8),
                                          _buildTaxTextField(
                                            controller: _ratePerUnitCtrl,
                                            enabled: true,
                                            hintText: '0.00',
                                            theme: theme,
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ],
                          ),
                  ),
                  const SizedBox(height: 16),

                  // ═══════════════════════════════
                  // Section 3: Tax Exemption
                  // ═══════════════════════════════
                  _buildCardSection(
                    theme,
                    title: 'TAX EXEMPTION',
                    child: isTaxNotApplicable
                        ? _buildDisabledState(
                            theme,
                            'Exemption criteria disabled',
                            Icons.lock_outline_rounded,
                          )
                        : Column(
                            children: [
                              Row(
                                children: [
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          'Tax Exemption',
                                          style: theme.textTheme.titleMedium?.copyWith(
                                            fontWeight: FontWeight.w700,
                                          ),
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          'Enable criteria for tax-free items',
                                          style: theme.textTheme.bodySmall?.copyWith(
                                            color: theme.colorScheme.onSurfaceVariant,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  Switch(
                                    value: _isExemptionEnabled,
                                    onChanged: (val) => setState(() => _isExemptionEnabled = val),
                                    activeColor: AppTheme.primary,
                                  ),
                                ],
                              ),
                              if (_isExemptionEnabled) ...[
                                const SizedBox(height: 16),
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
                                  ),
                                ),
                              ],
                            ],
                          ),
                  ),
                  const SizedBox(height: 32),

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
                                valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                              ),
                            )
                          : const Icon(Icons.save_rounded, size: 20),
                      label: Text(_isSaving ? 'SAVING…' : 'SAVE TAX SETTINGS'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.primary,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
                        ),
                        elevation: 0,
                      ),
                    ),
                  ),
                  const SizedBox(height: 32),
                ],
              ),
            ),
    );
  }

  // ── Helper Widgets ──

  Widget _buildCardSection(ThemeData theme, {String? title, required Widget child}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (title != null) ...[
          Text(
            title,
            style: theme.textTheme.labelMedium?.copyWith(
              fontWeight: FontWeight.w700,
              letterSpacing: 0.5,
              color: theme.colorScheme.onSurfaceVariant,
              fontSize: 11,
            ),
          ),
          const SizedBox(height: 12),
        ],
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: theme.colorScheme.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(AppTheme.radiusLarge),
          ),
          child: child,
        ),
      ],
    );
  }

  Widget _buildSegmentTab(
    ThemeData theme, {
    required String label,
    required bool isActive,
    required VoidCallback onTap,
  }) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          height: 40,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: isActive ? AppTheme.primary : Colors.transparent,
            borderRadius: BorderRadius.circular(AppTheme.radiusMedium - 4),
            boxShadow: isActive
                ? [
                    BoxShadow(
                      color: AppTheme.primary.withValues(alpha: 0.3),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    )
                  ]
                : null,
          ),
          child: Text(
            label,
            style: theme.textTheme.labelLarge?.copyWith(
              color: isActive ? Colors.white : theme.colorScheme.onSurfaceVariant,
              fontWeight: isActive ? FontWeight.w700 : FontWeight.w500,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildLargeNumericInput(
    ThemeData theme, {
    required TextEditingController controller,
    required String suffixText,
    required String hintText,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: theme.scaffoldBackgroundColor,
        borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
        border: Border.all(
          color: theme.colorScheme.onSurface.withValues(alpha: 0.1),
          width: 0.5,
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: controller,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              textAlign: TextAlign.end,
              style: theme.textTheme.displaySmall?.copyWith(
                fontWeight: FontWeight.w700,
                color: theme.colorScheme.onSurface,
              ),
              decoration: InputDecoration(
                hintText: hintText,
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                focusedBorder: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(horizontal: 12),
                filled: false,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Text(
            suffixText,
            style: theme.textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.w500,
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
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
      textAlign: TextAlign.end,
      style: theme.textTheme.bodyLarge?.copyWith(
        color: enabled
            ? null
            : theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.4),
      ),
      decoration: InputDecoration(
        hintText: hintText,
        filled: true,
        fillColor: theme.scaffoldBackgroundColor,
      ),
    );
  }

  Widget _buildDisabledState(ThemeData theme, String message, IconData icon) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          message,
          style: theme.textTheme.bodyMedium?.copyWith(
            color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.5),
            fontWeight: FontWeight.w500,
          ),
        ),
        Icon(
          icon,
          size: 20,
          color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.3),
        ),
      ],
    );
  }
}
