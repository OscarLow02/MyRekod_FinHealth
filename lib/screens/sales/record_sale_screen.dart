import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../core/app_theme.dart';
import '../../core/lhdn_constants.dart';
import '../../models/customer.dart';
import '../../providers/sale_calculator_provider.dart';
import '../../widgets/custom_widgets.dart';
import '../../widgets/custom_dropdown.dart';
import '../../widgets/app_dialogs.dart';

/// The "Iceberg" Record Sale form.
///
/// Visually simple (quantity, item, customer, total) but internally manages
/// 30+ LHDN-compliant fields. Uses [SaleCalculatorProvider] for real-time
/// pricing calculations and 5-cent rounding.
class RecordSaleScreen extends StatefulWidget {
  const RecordSaleScreen({super.key});

  @override
  State<RecordSaleScreen> createState() => _RecordSaleScreenState();
}

class _RecordSaleScreenState extends State<RecordSaleScreen> {
  final _formKey = GlobalKey<FormState>();
  final _quantityController = TextEditingController(text: '1');
  final _discountController = TextEditingController();
  final _discountDescController = TextEditingController();
  final _notesController = TextEditingController();
  final _taxRateController = TextEditingController();

  bool _showAdvanced = false;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    // Initialize the provider after build
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<SaleCalculatorProvider>().initialize();
    });
  }

  @override
  void dispose() {
    _quantityController.dispose();
    _discountController.dispose();
    _discountDescController.dispose();
    _notesController.dispose();
    _taxRateController.dispose();
    super.dispose();
  }

  // ── Back Press / Discard Guard ──────────────────────────────────────────

  void _handleBackPress() {
    final calc = context.read<SaleCalculatorProvider>();
    final hasData = calc.selectedItem != null || calc.selectedCustomer != null;

    if (hasData) {
      AppDialogs.showActionModal(
        context,
        title: 'Discard Sale?',
        body: 'If you go back now, all sale details will be discarded.',
        primaryButtonText: 'Discard',
        primaryButtonColor: Colors.redAccent,
        onPrimaryPressed: () => Navigator.of(context).pop(),
        secondaryButtonText: 'Keep Editing',
        icon: Icons.warning_amber_rounded,
        iconColor: Colors.orange,
      );
    } else {
      Navigator.of(context).pop();
    }
  }

  // ── Date Picker ─────────────────────────────────────────────────────────

  Future<void> _selectDate(BuildContext context) async {
    final calc = context.read<SaleCalculatorProvider>();
    final picked = await showDatePicker(
      context: context,
      initialDate: calc.saleDate,
      firstDate: DateTime(2000),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: Theme.of(context).colorScheme.copyWith(
                  primary: AppTheme.primary,
                  onPrimary: Colors.white,
                ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null) {
      calc.setSaleDate(picked);
    }
  }

  // ── Submit Sale ─────────────────────────────────────────────────────────

  Future<void> _submitSale() async {
    if (!_formKey.currentState!.validate()) return;

    final calc = context.read<SaleCalculatorProvider>();
    if (!calc.canSubmit) return;

    setState(() => _isSaving = true);

    try {
      final record = await calc.submitSale();

      if (!mounted) return;
      setState(() => _isSaving = false);

      if (record != null) {
        // Show success confirmation with review details
        _showSuccessReview(record.invoiceNumber, record.totalPayable);
      } else {
        AppDialogs.showActionModal(
          context,
          title: 'Submission Failed',
          body: calc.error ?? 'Could not save the sale. Please try again.',
          primaryButtonText: 'OK',
          onPrimaryPressed: () {},
          icon: Icons.error_outline_rounded,
          iconColor: Colors.redAccent,
          primaryButtonColor: Colors.redAccent,
        );
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _isSaving = false);
      AppDialogs.showActionModal(
        context,
        title: 'Error',
        body: 'An unexpected error occurred.\n\n$e',
        primaryButtonText: 'OK',
        onPrimaryPressed: () {},
        icon: Icons.error_outline_rounded,
        iconColor: Colors.redAccent,
        primaryButtonColor: Colors.redAccent,
      );
    }
  }

  void _showSuccessReview(String invoiceNumber, double total) {
    final theme = Theme.of(context);
    // TODO: Implement i18n
    const successTitle = 'Sale Recorded';
    final successBody = '$invoiceNumber • RM ${total.toStringAsFixed(2)}';

    AppDialogs.showActionModal(
      context,
      title: successTitle,
      body: successBody,
      primaryButtonText: 'Record Another',
      onPrimaryPressed: () {
        context.read<SaleCalculatorProvider>().resetForm();
        _quantityController.text = '1';
        _discountController.clear();
        _discountDescController.clear();
        _notesController.clear();
        _taxRateController.clear();
        setState(() => _showAdvanced = false);
      },
      secondaryButtonText: 'Done',
      onSecondaryPressed: () => Navigator.pop(context),
      icon: Icons.check_circle_outline_rounded,
      iconColor: theme.brightness == Brightness.dark
          ? AppTheme.neonGreenDark
          : AppTheme.neonGreenLight,
      primaryButtonColor: AppTheme.primary,
    );
  }

  // ── Preview Bottom Sheet ────────────────────────────────────────────────

  void _showPreviewSheet() {
    if (!_formKey.currentState!.validate()) return;

    final calc = context.read<SaleCalculatorProvider>();
    if (!calc.canSubmit) return;

    final theme = Theme.of(context);

    AppDialogs.showTransactionReviewSheet(
      context,
      title: 'Review Sale',
      primaryIcon: Icons.receipt_long_rounded,
      primaryButtonText: 'Confirm & Submit',
      onPrimaryPressed: _submitSale,
      secondaryButtonText: 'Edit Details',
      overviewCard: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
          borderRadius: BorderRadius.circular(AppTheme.radiusLarge),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _reviewRow('Item', calc.selectedItem?.name ?? '-', theme),
            _reviewRow('Customer', calc.selectedCustomer?.name ?? '-', theme),
            _reviewRow(
              'Qty × Price',
              '${calc.quantity.toStringAsFixed(calc.quantity == calc.quantity.roundToDouble() ? 0 : 2)} × RM ${calc.unitPrice.toStringAsFixed(2)}',
              theme,
            ),
            _reviewDivider(theme),
            _reviewRow('Subtotal', 'RM ${calc.subtotal.toStringAsFixed(2)}', theme),
            if (calc.discountAmount > 0)
              _reviewRow(
                'Discount',
                '- RM ${calc.discountAmount.toStringAsFixed(2)}',
                theme,
                valueColor: Colors.orange,
              ),
            if (calc.taxAmount > 0)
              _reviewRow(
                'Tax (${calc.taxRate.toStringAsFixed(1)}%)',
                '+ RM ${calc.taxAmount.toStringAsFixed(2)}',
                theme,
              ),
            if (calc.roundingAmount != 0)
              _reviewRow(
                'Rounding',
                '${calc.roundingAmount >= 0 ? '+' : ''} RM ${calc.roundingAmount.toStringAsFixed(2)}',
                theme,
                valueColor: theme.colorScheme.onSurfaceVariant,
              ),
            _reviewDivider(theme),
            _reviewRow(
              'Total Payable',
              'RM ${calc.totalPayable.toStringAsFixed(2)}',
              theme,
              isBold: true,
              valueColor: theme.brightness == Brightness.dark
                  ? AppTheme.neonGreenDark
                  : AppTheme.neonGreenLight,
            ),
            const SizedBox(height: 8),
            _reviewRow(
              'Payment',
              LhdnConstants.paymentModes[calc.paymentMode] ?? 'Cash',
              theme,
            ),
          ],
        ),
      ),
    );
  }

  Widget _reviewRow(
    String label,
    String value,
    ThemeData theme, {
    bool isBold = false,
    Color? valueColor,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: theme.textTheme.bodyLarge?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          Flexible(
            child: Text(
              value,
              style: theme.textTheme.bodyLarge?.copyWith(
                fontWeight: isBold ? FontWeight.w700 : FontWeight.w600,
                color: valueColor,
                fontSize: isBold ? 18 : null,
              ),
              textAlign: TextAlign.end,
            ),
          ),
        ],
      ),
    );
  }

  Widget _reviewDivider(ThemeData theme) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Container(
        height: 1,
        color: theme.colorScheme.surfaceContainerHighest,
      ),
    );
  }

  // ══════════════════════════════════════════════════════════════════════════
  //  BUILD
  // ══════════════════════════════════════════════════════════════════════════

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        _handleBackPress();
      },
      child: Scaffold(
        appBar: AppBar(
          // TODO: Implement i18n
          title: const Text('Record Sale'),
          backgroundColor: Colors.transparent,
          elevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: _handleBackPress,
          ),
        ),
        body: Consumer<SaleCalculatorProvider>(
          builder: (context, calc, _) {
            if (calc.isLoading) {
              return const Center(child: CircularProgressIndicator());
            }

            if (calc.error != null && calc.saleItems.isEmpty) {
              return Center(
                child: Padding(
                  padding: const EdgeInsets.all(32),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.error_outline,
                          size: 48,
                          color: theme.colorScheme.error),
                      const SizedBox(height: 16),
                      Text(
                        'Could not load data',
                        style: theme.textTheme.titleMedium,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        calc.error!,
                        style: theme.textTheme.bodyMedium,
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
              );
            }

            return SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // ── Live Total Card ──────────────────────────────
                    _buildTotalCard(calc, theme),
                    const SizedBox(height: 28),

                    // ── Section: Sale Details ────────────────────────
                    Text(
                      // TODO: Implement i18n
                      'Sale Details',
                      style: theme.textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 20),

                    // Item selection
                    _buildItemSelector(calc, theme),
                    const SizedBox(height: 16),

                    // Customer selection
                    _buildCustomerSelector(calc, theme),
                    const SizedBox(height: 16),

                    // Quantity + Date row
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: AppTextField(
                            label: 'Quantity',
                            icon: Icons.numbers_rounded,
                            controller: _quantityController,
                            keyboardType: const TextInputType.numberWithOptions(
                              decimal: true,
                            ),
                            hintText: '1',
                            onChanged: (val) {
                              final qty = double.tryParse(val);
                              if (qty != null) calc.setQuantity(qty);
                            },
                            validator: (val) {
                              if (val == null || val.isEmpty) return 'Required';
                              final qty = double.tryParse(val);
                              if (qty == null || qty <= 0) return 'Invalid';
                              return null;
                            },
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: _buildDateField(calc, theme),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),

                    // Payment mode
                    CustomPremiumDropdown<String>(
                      label: 'Payment Mode',
                      value: calc.paymentMode,
                      items: CustomDropdownBuilder.fromMap(
                        LhdnConstants.paymentModes,
                        icon: Icons.payment_rounded,
                      ),
                      onChanged: (val) {
                        if (val != null) calc.setPaymentMode(val);
                      },
                      fillColor: theme.colorScheme.surfaceContainerHighest
                          .withValues(alpha: 0.3),
                    ),
                    const SizedBox(height: 24),

                    // ── Advanced Toggle ──────────────────────────────
                    _buildAdvancedToggle(theme),

                    if (_showAdvanced) ...[
                      const SizedBox(height: 20),
                      _buildAdvancedSection(calc, theme),
                    ],

                    const SizedBox(height: 32),

                    // ── Submit ───────────────────────────────────────
                    AppButton(
                      // TODO: Implement i18n
                      text: 'Review & Submit',
                      onPressed: (_isSaving || !calc.canSubmit)
                          ? null
                          : _showPreviewSheet,
                      isLoading: _isSaving,
                      icon: const Icon(Icons.receipt_long_rounded),
                    ),
                    const SizedBox(height: 32),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  // ══════════════════════════════════════════════════════════════════════════
  //  WIDGET BUILDERS
  // ══════════════════════════════════════════════════════════════════════════

  /// The live-updating total card at the top of the form.
  Widget _buildTotalCard(SaleCalculatorProvider calc, ThemeData theme) {
    final accentColor = theme.brightness == Brightness.dark
        ? AppTheme.neonGreenDark
        : AppTheme.neonGreenLight;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppTheme.primary.withValues(alpha: 0.15),
            AppTheme.primary.withValues(alpha: 0.05),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(AppTheme.radiusXLarge),
        border: Border.all(
          color: AppTheme.primary.withValues(alpha: 0.25),
          width: 1.5,
        ),
      ),
      child: Column(
        children: [
          // Total Payable
          Text(
            // TODO: Implement i18n
            'Total Payable',
            style: theme.textTheme.labelMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 8),
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 200),
            child: Text(
              'RM ${calc.totalPayable.toStringAsFixed(2)}',
              key: ValueKey(calc.totalPayable),
              style: theme.textTheme.displayMedium?.copyWith(
                fontWeight: FontWeight.w800,
                color: accentColor,
                letterSpacing: -1,
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Breakdown row
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _buildBreakdownChip(
                'Subtotal',
                'RM ${calc.subtotal.toStringAsFixed(2)}',
                theme,
              ),
              if (calc.discountAmount > 0)
                _buildBreakdownChip(
                  'Discount',
                  '- RM ${calc.discountAmount.toStringAsFixed(2)}',
                  theme,
                  color: Colors.orange,
                ),
              if (calc.taxAmount > 0)
                _buildBreakdownChip(
                  'Tax',
                  '+ RM ${calc.taxAmount.toStringAsFixed(2)}',
                  theme,
                ),
              if (calc.roundingAmount != 0)
                _buildBreakdownChip(
                  'Round',
                  '${calc.roundingAmount >= 0 ? '+' : ''}${calc.roundingAmount.toStringAsFixed(2)}',
                  theme,
                  color: theme.colorScheme.onSurfaceVariant,
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildBreakdownChip(
    String label,
    String value,
    ThemeData theme, {
    Color? color,
  }) {
    return Column(
      children: [
        Text(
          label,
          style: theme.textTheme.labelMedium?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
            fontSize: 12,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: theme.textTheme.bodyLarge?.copyWith(
            fontWeight: FontWeight.w600,
            color: color,
            fontSize: 14,
          ),
        ),
      ],
    );
  }

  /// Item selection dropdown, searchable from the SaleItem catalog.
  Widget _buildItemSelector(SaleCalculatorProvider calc, ThemeData theme) {
    final items = calc.saleItems
        .map(
          (item) => CustomDropdownItem<String>(
            label: '${item.name}  •  RM ${item.unitPrice.toStringAsFixed(2)}',
            value: item.id,
            icon: Icons.inventory_2_rounded,
          ),
        )
        .toList();

    return CustomPremiumDropdown<String>(
      label: 'Item / Service',
      value: calc.selectedItem?.id,
      hint: 'Select from catalog',
      items: items,
      isSearchable: true,
      onChanged: (val) {
        if (val != null) {
          final item = calc.saleItems.firstWhere((i) => i.id == val);
          calc.selectItem(item);
        }
      },
      validator: (val) => val == null ? 'Please select an item' : null,
      fillColor:
          theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
    );
  }

  /// Customer selection dropdown with Walk-in as default option.
  Widget _buildCustomerSelector(
      SaleCalculatorProvider calc, ThemeData theme) {
    // Build customer dropdown items: Walk-in first, then saved customers
    final customerItems = <CustomDropdownItem<String>>[
      CustomDropdownItem<String>(
        label: 'Walk-in Customer (B2C)',
        value: Customer.walkIn.id,
        icon: Icons.person_rounded,
      ),
      ...calc.customers.map(
        (c) => CustomDropdownItem<String>(
          label: '${c.name}  •  ${c.customerType.name.toUpperCase()}',
          value: c.id,
          icon: c.customerType == CustomerType.b2b
              ? Icons.business_rounded
              : Icons.person_outline_rounded,
        ),
      ),
    ];

    return CustomPremiumDropdown<String>(
      label: 'Customer',
      value: calc.selectedCustomer?.id,
      hint: 'Select customer',
      items: customerItems,
      isSearchable: true,
      onChanged: (val) {
        if (val == Customer.walkIn.id) {
          calc.selectCustomer(Customer.walkIn);
        } else if (val != null) {
          final customer = calc.customers.firstWhere((c) => c.id == val);
          calc.selectCustomer(customer);
        }
      },
      validator: (val) => val == null ? 'Please select a customer' : null,
      fillColor:
          theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
    );
  }

  /// Date field with tap-to-pick.
  Widget _buildDateField(SaleCalculatorProvider calc, ThemeData theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Icons.calendar_month_rounded,
                size: 16, color: theme.colorScheme.onSurfaceVariant),
            const SizedBox(width: 8),
            Text(
              'Date',
              style: theme.textTheme.labelMedium?.copyWith(
                fontWeight: FontWeight.w600,
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        InkWell(
          onTap: () => _selectDate(context),
          borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(
              color: theme.colorScheme.surfaceContainerHighest
                  .withValues(alpha: 0.3),
              borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
            ),
            child: Text(
              DateFormat('yyyy-MM-dd').format(calc.saleDate),
              style: theme.textTheme.bodyLarge?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ),
      ],
    );
  }

  /// The expandable advanced section toggle.
  Widget _buildAdvancedToggle(ThemeData theme) {
    return GestureDetector(
      onTap: () => setState(() => _showAdvanced = !_showAdvanced),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.2),
          borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
          border: Border.all(
            color: theme.colorScheme.surfaceContainerHighest,
          ),
        ),
        child: Row(
          children: [
            Icon(
              Icons.tune_rounded,
              size: 20,
              color: theme.colorScheme.onSurfaceVariant,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                // TODO: Implement i18n
                'Discount, Tax & Notes',
                style: theme.textTheme.bodyLarge?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            AnimatedRotation(
              turns: _showAdvanced ? 0.5 : 0.0,
              duration: const Duration(milliseconds: 200),
              child: Icon(
                Icons.keyboard_arrow_down_rounded,
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// The advanced fields section (discount, tax, notes).
  Widget _buildAdvancedSection(
      SaleCalculatorProvider calc, ThemeData theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Discount
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: AppTextField(
                label: 'Discount (RM)',
                icon: Icons.discount_rounded,
                controller: _discountController,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                hintText: '0.00',
                onChanged: (val) {
                  final d = double.tryParse(val) ?? 0.0;
                  calc.setDiscountAmount(d);
                },
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: AppTextField(
                label: 'Reason (Optional)',
                icon: Icons.description_rounded,
                controller: _discountDescController,
                hintText: 'e.g., Loyalty',
                onChanged: (val) => calc.setDiscountDescription(val),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),

        // Tax
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              flex: 3,
              child: CustomPremiumDropdown<String>(
                label: 'Tax Type',
                value: calc.taxType,
                items: CustomDropdownBuilder.fromMap(
                  LhdnConstants.taxTypes,
                  icon: Icons.account_balance_rounded,
                ),
                onChanged: (val) {
                  if (val != null) {
                    calc.setTaxType(val);
                    // Clear rate controller if N/A
                    if (val == '06' || val == 'E') {
                      _taxRateController.clear();
                    }
                  }
                },
                fillColor: theme.colorScheme.surfaceContainerHighest
                    .withValues(alpha: 0.3),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              flex: 2,
              child: AppTextField(
                label: 'Rate (%)',
                icon: Icons.percent_rounded,
                controller: _taxRateController,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                hintText: '0',
                enabled: calc.taxType != '06' && calc.taxType != 'E',
                onChanged: (val) {
                  final rate = double.tryParse(val) ?? 0.0;
                  calc.setTaxRate(rate);
                },
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),

        // Notes
        AppTextField(
          label: 'Notes (Optional)',
          icon: Icons.notes_rounded,
          controller: _notesController,
          hintText: 'Add extra details...',
          maxLines: 3,
          onChanged: (val) => calc.setNotes(val),
        ),
      ],
    );
  }
}
