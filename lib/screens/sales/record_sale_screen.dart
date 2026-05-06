import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../core/app_theme.dart';
import '../../core/lhdn_constants.dart';
import '../../models/customer.dart';
import '../../models/sale_line_item.dart';
import '../../providers/sale_calculator_provider.dart';
import '../../widgets/custom_widgets.dart';
import '../../widgets/custom_dropdown.dart';
import '../../widgets/app_dialogs.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../services/firestore_service.dart';
import '../../models/sale_item.dart';
import '../profile/widgets/add_item_bottom_sheet.dart';

/// Redesigned Record Sale form following the A-B-C hierarchy.
/// Section A: Customer Type (Individual vs Business)
/// Section B: Item Details
/// Section C: Advanced Options
/// Includes a frozen bottom summary bar.
enum SaleCustomerType { individual, business }

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

  SaleCustomerType _selectedType = SaleCustomerType.individual;
  bool _isWalkIn = false;
  bool _showAdvanced = false;
  bool _isSaving = false;
  final _fs = FirestoreService();

  Future<void> _openAddItemSheet(SaleCalculatorProvider calc) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final result = await showModalBottomSheet<SaleItem>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const AddItemBottomSheet(),
    );

    if (result != null && mounted) {
      try {
        await _fs.addSaleItem(user.uid, result);
        // Note: The provider's stream will automatically pick up the new item.
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Failed to add item: $e'),
              backgroundColor: Colors.redAccent,
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      }
    }
  }

  bool _isItemAlreadyAdded(SaleCalculatorProvider calc, String itemId, {int? excludeIndex}) {
    for (int i = 0; i < calc.lineItems.length; i++) {
      if (i == excludeIndex) continue;
      if (calc.lineItems[i].item.id == itemId) return true;
    }
    return false;
  }

  void _showDuplicateError() {
    AppDialogs.showActionModal(
      context,
      title: 'Already Added',
      body: 'You have already added this item to the current sale.',
      primaryButtonText: 'Got it',
      onPrimaryPressed: () {},
      icon: Icons.info_outline_rounded,
      iconColor: AppTheme.primary,
      primaryButtonColor: AppTheme.primary,
    );
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final calc = context.read<SaleCalculatorProvider>();
      calc.initialize();
      // Default to walk-in individual
      _selectWalkIn(calc);
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

  void _onTypeChanged(SaleCustomerType type, SaleCalculatorProvider provider) {
    setState(() {
      _selectedType = type;
      _isWalkIn = false;
      provider.selectCustomer(null);
    });
  }

  void _selectWalkIn(SaleCalculatorProvider provider) {
    setState(() {
      _isWalkIn = true;
      _selectedType = SaleCustomerType.individual;
    });
    provider.selectCustomer(Customer.walkIn);
  }

  // ── Back Press / Discard Guard ──────────────────────────────────────────

  void _handleBackPress() {
    final calc = context.read<SaleCalculatorProvider>();
    if (!calc.canSubmit && calc.selectedItem == null) {
      Navigator.pop(context);
      return;
    }

    AppDialogs.showActionModal(
      context,
      title: 'Discard Changes?',
      body: 'You have unsaved changes. Are you sure you want to go back?',
      primaryButtonText: 'Discard',
      onPrimaryPressed: () => Navigator.pop(context),
      secondaryButtonText: 'Cancel',
      icon: Icons.warning_amber_rounded,
      iconColor: Colors.orange,
    );
  }

  // ── Submission Logic ──────────────────────────────────────────────────

  Future<void> _submitSale() async {
    final calc = context.read<SaleCalculatorProvider>();
    if (!calc.canSubmit) return;

    setState(() => _isSaving = true);

    try {
      final record = await calc.submitSale(saveNewCustomer: false);

      if (!mounted) return;
      setState(() => _isSaving = false);

      if (record != null) {
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
      );
    }
  }

  void _showSuccessReview(String invoiceNumber, double total) {
    final theme = Theme.of(context);
    AppDialogs.showActionModal(
      context,
      title: 'Sale Recorded',
      body: '$invoiceNumber • RM ${total.toStringAsFixed(2)}',
      primaryButtonText: 'Record Another',
      onPrimaryPressed: () {
        context.read<SaleCalculatorProvider>().resetForm();
        _quantityController.text = '1';
        _discountController.clear();
        _discountDescController.clear();
        _notesController.clear();
        _taxRateController.clear();
        setState(() {
          _showAdvanced = false;
        });
        _selectWalkIn(context.read<SaleCalculatorProvider>());
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
    try {
      final formState = _formKey.currentState;
      if (formState != null && !formState.validate()) return;

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
            ...calc.lineItems.map((line) => Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _reviewRow('Item', line.item.name, theme),
                _reviewRow(
                  'Qty × Price',
                  '${line.quantity.toStringAsFixed(line.quantity == line.quantity.roundToDouble() ? 0 : 2)} × RM ${line.unitPrice.toStringAsFixed(2)}',
                  theme,
                ),
                const SizedBox(height: 4),
              ],
            )),
            _reviewRow('Customer', calc.selectedCustomer?.name ?? '-', theme),
            _reviewDivider(theme),
            _reviewRow('Subtotal', 'RM ${calc.subtotal.toStringAsFixed(2)}', theme),
            if (calc.discountAmount > 0)
              _reviewRow('Discount', '- RM ${calc.discountAmount.toStringAsFixed(2)}', theme, valueColor: Colors.orange),
            if (calc.taxAmount > 0)
              _reviewRow('Tax (${calc.taxRate.toStringAsFixed(1)}%)', '+ RM ${calc.taxAmount.toStringAsFixed(2)}', theme),
            if (calc.roundingAmount != 0)
              _reviewRow('Rounding', '${calc.roundingAmount >= 0 ? '+' : ''} RM ${calc.roundingAmount.toStringAsFixed(2)}', theme, valueColor: theme.colorScheme.onSurfaceVariant),
            _reviewDivider(theme),
            _reviewRow(
              'Total Payable',
              'RM ${calc.totalPayable.toStringAsFixed(2)}',
              theme,
              isBold: true,
              valueColor: theme.brightness == Brightness.dark ? AppTheme.neonGreenDark : AppTheme.neonGreenLight,
            ),
          ],
        ),
      ),
    );
  } catch (e) {
      debugPrint('Preview sheet error: $e');
      AppDialogs.showActionModal(
        context,
        title: 'Review Error',
        body: 'Could not open the review sheet. Please ensure all items are selected correctly.\n\nDetails: $e',
        primaryButtonText: 'OK',
        onPrimaryPressed: () {},
        icon: Icons.error_outline_rounded,
        iconColor: Colors.redAccent,
      );
    }
  }

  Widget _reviewRow(String label, String value, ThemeData theme, {bool isBold = false, Color? valueColor}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: theme.textTheme.bodyLarge?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
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
      child: Container(height: 1, color: theme.colorScheme.surfaceContainerHighest),
    );
  }

  // ── Build ─────────────────────────────────────────────────────────────

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
            if (calc.isLoading) return const Center(child: CircularProgressIndicator());

            return Column(
              children: [
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                    child: Form(
                      key: _formKey,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildCustomerTypeSection(calc, theme),
                          const SizedBox(height: 28),

                          _buildItemDetailsSection(calc, theme),
                          const SizedBox(height: 28),

                          Text('Additional Details', style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
                          const SizedBox(height: 20),

                          Row(
                            children: [
                              Expanded(
                                child: CustomPremiumDropdown<String>(
                                  label: 'Payment Mode',
                                  value: calc.paymentMode,
                                  items: CustomDropdownBuilder.fromMap(LhdnConstants.paymentModes, icon: Icons.payment_rounded),
                                  onChanged: (val) => val != null ? calc.setPaymentMode(val) : null,
                                  fillColor: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
                                ),
                              ),
                              const SizedBox(width: 16),
                              Expanded(child: _buildDateField(calc, theme)),
                            ],
                          ),
                          const SizedBox(height: 24),

                          _buildAdvancedToggle(theme),
                          if (_showAdvanced) ...[
                            const SizedBox(height: 20),
                            _buildAdvancedSection(calc, theme),
                          ],
                          const SizedBox(height: 32),
                        ],
                      ),
                    ),
                  ),
                ),
                _buildBottomSummary(calc, theme),
              ],
            );
          },
        ),
      ),
    );
  }

  // ── Widgets ──────────────────────────────────────────────────────────

  Widget _buildCustomerTypeSection(SaleCalculatorProvider calc, ThemeData theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'CUSTOMER TYPE',
          style: theme.textTheme.labelMedium?.copyWith(fontWeight: FontWeight.w700, letterSpacing: 1.2, color: theme.colorScheme.onSurfaceVariant),
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(child: _buildTypeCard(label: 'Individual', icon: Icons.person_rounded, isSelected: _selectedType == SaleCustomerType.individual, onTap: () => _onTypeChanged(SaleCustomerType.individual, calc), theme: theme)),
            const SizedBox(width: 12),
            Expanded(child: _buildTypeCard(label: 'Business', icon: Icons.store_rounded, isSelected: _selectedType == SaleCustomerType.business, onTap: () => _onTypeChanged(SaleCustomerType.business, calc), theme: theme)),
          ],
        ),
        const SizedBox(height: 24),
        CustomPremiumDropdown<String>(
          label: '',
          value: _isWalkIn ? null : calc.selectedCustomer?.id,
          hint: 'Select/Search Customer',
          isSearchable: true,
          items: calc.customers
              .where((c) => _selectedType == SaleCustomerType.individual ? c.customerType == CustomerType.b2c : c.customerType == CustomerType.b2b)
              .map((c) => CustomDropdownItem<String>(label: c.name, value: c.id, icon: Icons.person_outline_rounded))
              .toList(),
          onChanged: (val) {
            if (val != null) {
              setState(() => _isWalkIn = false);
              final customer = calc.customers.firstWhere((c) => c.id == val);
              calc.selectCustomer(customer);
            }
          },
          fillColor: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
        ),
        if (_selectedType == SaleCustomerType.individual) ...[
          const SizedBox(height: 12),
          AppButton(
            text: 'Walk-in Customer',
            isPrimary: false,
            onPressed: () => _selectWalkIn(calc),
            icon: Icon(Icons.person_add_alt_1_rounded, size: 20, color: _isWalkIn ? AppTheme.neonGreenDark : theme.colorScheme.onSurface),
          ),
        ],
      ],
    );
  }

  Widget _buildTypeCard({required String label, required IconData icon, required bool isSelected, required VoidCallback onTap, required ThemeData theme}) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppTheme.radiusLarge),
      child: Container(
        height: 100,
        decoration: BoxDecoration(
          color: isSelected ? AppTheme.primary : theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
          borderRadius: BorderRadius.circular(AppTheme.radiusLarge),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 32, color: isSelected ? Colors.white : theme.colorScheme.onSurfaceVariant),
            const SizedBox(height: 8),
            Text(label, style: theme.textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.w600, color: isSelected ? Colors.white : theme.colorScheme.onSurfaceVariant)),
          ],
        ),
      ),
    );
  }

  Widget _buildItemDetailsSection(SaleCalculatorProvider calc, ThemeData theme) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(AppTheme.radiusLarge),
        border: Border.all(color: theme.colorScheme.surfaceContainerHighest),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Item Details',
            style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 20),
          ...calc.lineItems.asMap().entries.map((entry) {
            final idx = entry.key;
            final line = entry.value;
            return Padding(
              padding: const EdgeInsets.only(bottom: 16.0),
              child: _buildItemBlock(calc, theme, idx, line),
            );
          }),
          if (calc.lineItems.isEmpty) _buildItemPlaceholder(calc, theme),
          const SizedBox(height: 12),
          _buildAddAnotherItemButton(calc, theme),
        ],
      ),
    );
  }

  Widget _buildItemBlock(SaleCalculatorProvider calc, ThemeData theme, int index, SaleLineItem line) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('Select Item', style: theme.textTheme.labelMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
            if (calc.lineItems.length > 1)
              IconButton(
                icon: const Icon(Icons.remove_circle_outline, color: Colors.redAccent, size: 20),
                onPressed: () => calc.removeLineItem(index),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
              ),
          ],
        ),
        const SizedBox(height: 8),
        CustomPremiumDropdown<String>(
          label: '',
          value: line.item.id,
          hint: 'Select from catalog',
          items: calc.saleItems.map((item) => CustomDropdownItem<String>(label: item.name, value: item.id, icon: Icons.inventory_2_rounded)).toList(),
          isSearchable: true,
          onChanged: (val) {
            if (val != null) {
              if (_isItemAlreadyAdded(calc, val, excludeIndex: index)) {
                _showDuplicateError();
                return;
              }
              final newItem = calc.saleItems.firstWhere((i) => i.id == val);
              calc.updateLineItem(index, newItem);
            }
          },
          onActionPressed: () => _openAddItemSheet(calc),
          fillColor: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              flex: 3,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Quantity', style: theme.textTheme.labelMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
                  const SizedBox(height: 8),
                  Container(
                    height: 56,
                    decoration: BoxDecoration(
                      color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
                      borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.remove, size: 20),
                          onPressed: () => calc.updateLineItemQuantity(index, line.quantity - 1),
                        ),
                        Text(
                          line.quantity.toStringAsFixed(0),
                          style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
                        ),
                        IconButton(
                          icon: const Icon(Icons.add, size: 20),
                          onPressed: () => calc.updateLineItemQuantity(index, line.quantity + 1),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              flex: 4,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Unit Price (RM)', style: theme.textTheme.labelMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
                  const SizedBox(height: 8),
                  Container(
                    height: 56,
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
                      borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          line.unitPrice.toStringAsFixed(2),
                          style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
                        ),
                        IconButton(
                          icon: const Icon(Icons.edit_outlined, size: 20, color: AppTheme.secondaryDark),
                          onPressed: () => _showPriceOverrideDialog(calc, index, line),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildItemPlaceholder(SaleCalculatorProvider calc, ThemeData theme) {
    return CustomPremiumDropdown<String>(
      label: 'Select Item',
      value: null,
      hint: 'Select from catalog',
      items: calc.saleItems.map((item) => CustomDropdownItem<String>(label: item.name, value: item.id, icon: Icons.inventory_2_rounded)).toList(),
      isSearchable: true,
      onChanged: (val) {
        if (val != null) {
          if (_isItemAlreadyAdded(calc, val)) {
            _showDuplicateError();
            return;
          }
          final item = calc.saleItems.firstWhere((i) => i.id == val);
          calc.addLineItem(item);
        }
      },
      onActionPressed: () => _openAddItemSheet(calc),
      fillColor: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
    );
  }

  Widget _buildAddAnotherItemButton(SaleCalculatorProvider calc, ThemeData theme) {
    return InkWell(
      onTap: () => _showItemPicker(calc, theme),
      child: Container(
        width: double.infinity,
        height: 56,
        decoration: BoxDecoration(
          border: Border.all(color: AppTheme.secondaryDark.withValues(alpha: 0.5), style: BorderStyle.solid),
          borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.add_circle_outline, size: 20, color: AppTheme.secondaryDark),
            const SizedBox(width: 8),
            Text(
              'Add Another Item',
              style: theme.textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.w600, color: AppTheme.secondaryDark),
            ),
          ],
        ),
      ),
    );
  }

  void _showItemPicker(SaleCalculatorProvider calc, ThemeData theme) {
    CustomPremiumDropdown.showPicker<String>(
      context: context,
      title: 'Select Item',
      isSearchable: true,
      items: calc.saleItems
          .map((item) => CustomDropdownItem<String>(
                label: item.name,
                value: item.id,
                icon: Icons.inventory_2_rounded,
              ))
          .toList(),
      onActionPressed: () => _openAddItemSheet(calc),
    ).then((val) {
      if (val != null) {
        if (_isItemAlreadyAdded(calc, val)) {
          _showDuplicateError();
          return;
        }
        final item = calc.saleItems.firstWhere((i) => i.id == val);
        calc.addLineItem(item);
      }
    });
  }

  void _showPriceOverrideDialog(SaleCalculatorProvider calc, int index, SaleLineItem line) {
    final controller = TextEditingController(text: line.unitPrice.toStringAsFixed(2));
    AppDialogs.showFormModal(
      context,
      title: 'Edit Unit Price',
      formBody: AppTextField(
        controller: controller,
        label: 'New Unit Price (RM)',
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
      ),
      primaryButtonText: 'Apply',
      onPrimaryPressed: () async {
        final price = double.tryParse(controller.text);
        if (price != null) {
          calc.updateLineItemPrice(index, price);
        }
        return true;
      },
      secondaryButtonText: 'Cancel',
      onSecondaryPressed: () {},
    );
  }

  Widget _buildBottomSummary(SaleCalculatorProvider calc, ThemeData theme) {
    return Container(
      padding: const EdgeInsets.fromLTRB(24, 20, 24, 40),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.3), blurRadius: 20, offset: const Offset(0, -5))],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Total Payable', style: theme.textTheme.titleMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
              Text('RM ${calc.totalPayable.toStringAsFixed(2)}', style: theme.textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.w800, color: theme.colorScheme.onSurface)),
            ],
          ),
          const SizedBox(height: 20),
          InkWell(
            onTap: (_isSaving || !calc.canSubmit) ? null : _showPreviewSheet,
            borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
            child: Container(
              height: 56,
              decoration: BoxDecoration(
                gradient: LinearGradient(colors: [AppTheme.primaryContainer, AppTheme.primary], begin: Alignment.centerLeft, end: Alignment.centerRight),
                borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
                boxShadow: [BoxShadow(color: AppTheme.primary.withValues(alpha: 0.3), blurRadius: 12, offset: const Offset(0, 4))],
              ),
              child: Center(
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text('Review Sale', style: theme.textTheme.titleMedium?.copyWith(color: Colors.white, fontWeight: FontWeight.w700)),
                    const SizedBox(width: 8),
                    const Icon(Icons.arrow_forward_rounded, color: Colors.white, size: 20),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDateField(SaleCalculatorProvider calc, ThemeData theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(children: [Icon(Icons.calendar_month_rounded, size: 16, color: theme.colorScheme.onSurfaceVariant), const SizedBox(width: 8), Text('Date', style: theme.textTheme.labelMedium?.copyWith(fontWeight: FontWeight.w600, color: theme.colorScheme.onSurfaceVariant))]),
        const SizedBox(height: 8),
        InkWell(
          onTap: () async {
            final picked = await showDatePicker(context: context, initialDate: calc.saleDate, firstDate: DateTime(2020), lastDate: DateTime(2100));
            if (picked != null) calc.setSaleDate(picked);
          },
          borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.3), borderRadius: BorderRadius.circular(AppTheme.radiusMedium)),
            child: Text(DateFormat('yyyy-MM-dd').format(calc.saleDate), style: theme.textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.w600)),
          ),
        ),
      ],
    );
  }

  Widget _buildAdvancedToggle(ThemeData theme) {
    return GestureDetector(
      onTap: () => setState(() => _showAdvanced = !_showAdvanced),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.2), borderRadius: BorderRadius.circular(AppTheme.radiusMedium), border: Border.all(color: theme.colorScheme.surfaceContainerHighest)),
        child: Row(
          children: [
            Icon(Icons.tune_rounded, size: 20, color: theme.colorScheme.onSurfaceVariant),
            const SizedBox(width: 12),
            Expanded(child: Text('Discount, Tax & Notes', style: theme.textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.w600))),
            AnimatedRotation(turns: _showAdvanced ? 0.5 : 0.0, duration: const Duration(milliseconds: 200), child: Icon(Icons.keyboard_arrow_down_rounded, color: theme.colorScheme.onSurfaceVariant)),
          ],
        ),
      ),
    );
  }

  Widget _buildAdvancedSection(SaleCalculatorProvider calc, ThemeData theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: AppTextField(
                label: 'Discount (RM)',
                icon: Icons.discount_rounded,
                controller: _discountController,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                onChanged: (val) => calc.setDiscountAmount(double.tryParse(val) ?? 0.0),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(child: AppTextField(label: 'Reason', icon: Icons.description_rounded, controller: _discountDescController, onChanged: (val) => calc.setDiscountDescription(val))),
          ],
        ),
        const SizedBox(height: 16),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              flex: 3,
              child: CustomPremiumDropdown<String>(
                label: 'Tax Type',
                value: calc.taxType,
                items: CustomDropdownBuilder.fromMap(LhdnConstants.taxTypes, icon: Icons.account_balance_rounded),
                onChanged: (val) {
                  if (val != null) {
                    calc.setTaxType(val);
                    if (val == '06' || val == 'E') _taxRateController.clear();
                  }
                },
                fillColor: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              flex: 2,
              child: AppTextField(
                label: 'Rate (%)',
                icon: Icons.percent_rounded,
                controller: _taxRateController,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                enabled: calc.taxType != '06' && calc.taxType != 'E',
                onChanged: (val) => calc.setTaxRate(double.tryParse(val) ?? 0.0),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        AppTextField(label: 'Notes', icon: Icons.notes_rounded, controller: _notesController, maxLines: 3, onChanged: (val) => calc.setNotes(val)),
      ],
    );
  }
}

