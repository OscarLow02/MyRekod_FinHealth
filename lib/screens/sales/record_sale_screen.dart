import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../widgets/app_dialogs.dart';
import '../../core/app_theme.dart';
import '../../core/lhdn_constants.dart';
import '../../models/customer.dart';
import '../../models/sale_line_item.dart';
import '../../providers/sale_calculator_provider.dart';
import '../../widgets/custom_widgets.dart';
import '../../widgets/custom_dropdown.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../services/firestore_service.dart';
import '../../models/sale_item.dart';
import '../../models/sale_record.dart';
import '../../core/validators.dart';
import '../profile/widgets/add_item_bottom_sheet.dart';
import '../customers/customer_list_screen.dart';

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
  bool _isSaving = false;
  final _fs = FirestoreService();

  // --- New Additional Details Controllers ---
  final _discountRateCtrl = TextEditingController();
  final _feeRateCtrl = TextEditingController();
  final _feeAmountCtrl = TextEditingController();
  final _paymentTermsCtrl = TextEditingController();
  final _billRefCtrl = TextEditingController();
  final _prepayAmountCtrl = TextEditingController();
  final _prepayRefCtrl = TextEditingController();
  final _bankAccountCtrl = TextEditingController();
  
  String? _billingFrequency;
  DateTime? _billingStartDate;
  DateTime? _billingEndDate;
  DateTime? _prepaymentDate;
  bool _isDiscountRate = true; // Added for Rate/Amount toggle

  // Checkboxes for Additional Details sections
  bool _enableDiscountCharges = false;
  bool _enablePaymentInfo = false;
  bool _enablePrepayment = false;
  bool _enableBillingExemption = false;

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
          AppDialogs.showSystemAlert(
            context,
            title: 'Failed to Add Item',
            body: e.toString(),
            icon: Icons.error_outline_rounded,
            iconColor: Colors.redAccent,
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

  void _showDuplicateError({
    required String title,
    required String body,
    required String buttonText,
  }) {
    AppDialogs.showActionModal(
      context,
      title: title,
      body: body,
      primaryButtonText: buttonText,
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
    });
  }

  @override
  void dispose() {
    _quantityController.dispose();
    _discountController.dispose();
    _discountDescController.dispose();
    _notesController.dispose();
    _taxRateController.dispose();
    _discountRateCtrl.dispose();
    _feeRateCtrl.dispose();
    _feeAmountCtrl.dispose();
    _paymentTermsCtrl.dispose();
    _billRefCtrl.dispose();
    _prepayAmountCtrl.dispose();
    _prepayRefCtrl.dispose();
    _bankAccountCtrl.dispose();
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

  void _handleBackPress({
    required String discardTitle,
    required String discardBody,
    required String discardButton,
    required String cancelButton,
  }) {
    final calc = context.read<SaleCalculatorProvider>();
    if (!calc.canSubmit && calc.selectedItem == null) {
      Navigator.pop(context);
      return;
    }

    AppDialogs.showActionModal(
      context,
      title: discardTitle,
      body: discardBody,
      primaryButtonText: discardButton,
      onPrimaryPressed: () => Navigator.pop(context),
      secondaryButtonText: cancelButton,
      icon: Icons.warning_amber_rounded,
      iconColor: Colors.orange,
    );
  }

  // ── Submission Logic ──────────────────────────────────────────────────





  // ── Preview Bottom Sheet ────────────────────────────────────────────────

  void _showPreviewSheet({
    required String title,
    required String subtitle,
    required String eInvoiceLabel,
    required String standardInvoiceLabel,
    required String subtotalLabel,
    required String discountLabel,
    required String feeChargeLabel,
    required String taxAmountLabel,
    required String taxAmountUnitLabel,
    required String roundingLabel,
    required String totalPayableLabel,
    required String recordReceiptLabel,
    required String confirmPaymentLabel,
    required String submitLhdnOnlyLabel,
    required String saveAsPendingLabel,
    required String incompleteFormTitle,
    required String incompleteFormBody,
  }) {
    try {
      final calc = context.read<SaleCalculatorProvider>();
      
      // 1. Sync all fields from controllers to provider
      _syncAllFields(calc);

      // 2. Form Validation
      final formState = _formKey.currentState;
      if (formState != null && !formState.validate()) {
        AppDialogs.showSystemAlert(
          context, 
          title: incompleteFormTitle, 
          body: incompleteFormBody,
          icon: Icons.warning_amber_rounded,
        );
        return;
      }

      if (!calc.canSubmit) return;

      final theme = Theme.of(context);

      showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (context) => Container(
          decoration: BoxDecoration(
            color: theme.colorScheme.surface,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
          ),
          padding: EdgeInsets.fromLTRB(24, 20, 24, MediaQuery.of(context).padding.bottom + 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(title, style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold, color: theme.colorScheme.onSurface)),
                      const SizedBox(height: 4),
                      Text(subtitle, style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
                    ],
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: Icon(Icons.close, color: theme.colorScheme.onSurfaceVariant),
                    style: IconButton.styleFrom(backgroundColor: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.5)),
                  ),
                ],
              ),
              const SizedBox(height: 32),

              // Summary Card
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: theme.colorScheme.onSurface.withValues(alpha: 0.05)),
                ),
                child: Column(
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(color: AppTheme.primary.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(12)),
                          child: Icon(Icons.receipt_long_rounded, color: AppTheme.primary),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(eInvoiceLabel, style: theme.textTheme.labelSmall?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
                              Text(calc.previewInvoiceNumber ?? 'INV-....', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold, color: theme.colorScheme.onSurface)),
                            ],
                          ),
                        ),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Row(
                              children: [
                                _buildBadge(theme, 'V 1.0'),
                                const SizedBox(width: 6),
                                _buildBadge(theme, 'T 01'),
                              ],
                            ),
                            const SizedBox(height: 4),
                            Text(standardInvoiceLabel, style: theme.textTheme.labelSmall?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
                          ],
                        ),
                      ],
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 20),
                      child: Divider(color: theme.colorScheme.onSurface.withValues(alpha: 0.1), height: 1),
                    ),
                    _buildSummaryRow(subtotalLabel, 'RM ${calc.subtotal.toStringAsFixed(2)}', theme),
                    if (calc.actualDiscountAmount > 0) ...[
                      const SizedBox(height: 12),
                      _buildSummaryRow(
                        calc.discountRate > 0 ? '$discountLabel (${calc.discountRate.toStringAsFixed(0)}%)' : discountLabel,
                        '-RM ${calc.actualDiscountAmount.toStringAsFixed(2)}', 
                        theme, 
                        isNegative: true,
                      ),
                    ],
                    if (calc.actualFeeAmount > 0) ...[
                      const SizedBox(height: 12),
                      _buildSummaryRow(
                        calc.feeRate > 0 ? '$feeChargeLabel (${calc.feeRate.toStringAsFixed(0)}%)' : feeChargeLabel,
                        '+RM ${calc.actualFeeAmount.toStringAsFixed(2)}', 
                        theme,
                      ),
                    ],
                    const SizedBox(height: 12),
                    _buildSummaryRow(
                      calc.taxConfig.numUnits != null && calc.taxConfig.ratePerUnit != null
                          ? taxAmountUnitLabel
                          : '$taxAmountLabel (${calc.taxRate.toStringAsFixed(0)}%)',
                      'RM ${calc.taxAmount.toStringAsFixed(2)}',
                      theme,
                    ),
                    const SizedBox(height: 12),
                    _buildSummaryRow(roundingLabel, '${calc.roundingAmount >= 0 ? '+' : '-'}RM ${calc.roundingAmount.abs().toStringAsFixed(2)}', theme, isNegative: calc.roundingAmount < 0),
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 20),
                      child: Divider(color: theme.colorScheme.onSurface.withValues(alpha: 0.1), height: 1),
                    ),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(totalPayableLabel, style: theme.textTheme.titleMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
                        Text('RM ${calc.totalPayable.toStringAsFixed(2)}', style: theme.textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.w900, color: theme.colorScheme.primary)),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 40),

              // Actions
              if (_isWalkIn || calc.selectedCustomer?.isWalkIn == true)
                Container(
                  width: double.infinity,
                  height: 60,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(colors: [Color(0xFFB55CFF), Color(0xFF8E24FA)]),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: ElevatedButton(
                    onPressed: () {
                      Navigator.pop(context);
                      _submitSaleWithParams(calc, CommercialStatus.paid, false);
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.transparent,
                      shadowColor: Colors.transparent,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.receipt_long_rounded, color: Colors.white, size: 20),
                        const SizedBox(width: 10),
                        Text(
                          recordReceiptLabel,
                          style: theme.textTheme.titleMedium?.copyWith(color: Colors.white, fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                  ),
                )
              else ...[
                Container(
                  width: double.infinity,
                  height: 60,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(colors: [Color(0xFF8B8FFF), Color(0xFF6B70FF)]),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: ElevatedButton(
                    onPressed: () {
                      Navigator.pop(context);
                      _submitSaleWithParams(calc, CommercialStatus.paid, true);
                    },
                    style: ElevatedButton.styleFrom(backgroundColor: Colors.transparent, shadowColor: Colors.transparent, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16))),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.check_circle, color: Colors.white, size: 20),
                        const SizedBox(width: 10),
                        Text(confirmPaymentLabel, style: theme.textTheme.titleMedium?.copyWith(color: Colors.white, fontWeight: FontWeight.bold)),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  height: 60,
                  child: ElevatedButton(
                    onPressed: () {
                      Navigator.pop(context);
                      _submitSaleWithParams(calc, CommercialStatus.pendingPayment, true);
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: BorderSide(color: theme.colorScheme.onSurface.withValues(alpha: 0.1))),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.cloud_upload, color: theme.colorScheme.onSurfaceVariant, size: 20),
                        const SizedBox(width: 10),
                        Text(submitLhdnOnlyLabel, style: theme.textTheme.titleMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                Center(
                  child: TextButton.icon(
                    onPressed: () {
                      Navigator.pop(context);
                      _submitSaleWithParams(calc, CommercialStatus.pendingPayment, false);
                    },
                    icon: Icon(Icons.save_rounded, color: theme.colorScheme.onSurfaceVariant, size: 18),
                    label: Text(saveAsPendingLabel, style: theme.textTheme.titleMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
                  ),
                ),
              ],
            ],
          ),
        ),
      );
    } catch (e) {
      debugPrint('Error showing review sheet: $e');
    }
  }

  Widget _buildBadge(ThemeData theme, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: theme.colorScheme.onSurface.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(label, style: theme.textTheme.labelSmall?.copyWith(color: theme.colorScheme.onSurface, fontWeight: FontWeight.bold)),
    );
  }

  Widget _buildSummaryRow(String label, String value, ThemeData theme, {bool isNegative = false}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: theme.textTheme.bodyLarge?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
        Text(value, style: theme.textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.w600, color: isNegative ? Colors.redAccent : theme.colorScheme.onSurface)),
      ],
    );
  }

  /// Synchronizes all UI controller values to the provider state.
  void _syncAllFields(SaleCalculatorProvider calc) {
    calc.setPaymentTerms(_paymentTermsCtrl.text);
    calc.setSupplierBankAccount(_bankAccountCtrl.text);
    calc.setBillReference(_billRefCtrl.text);
    calc.setPrepaymentAmount(double.tryParse(_prepayAmountCtrl.text) ?? 0.0);
    calc.setPrepaymentDate(_prepaymentDate);
    calc.setPrepaymentReference(_prepayRefCtrl.text);
    calc.setBillingFrequency(_billingFrequency ?? '');

    calc.setBillingPeriod(_billingStartDate, _billingEndDate);
  }

  Future<void> _submitSaleWithParams(SaleCalculatorProvider calc, CommercialStatus status, bool submitToLhdn) async {
    setState(() => _isSaving = true);
    
    // Ensure everything is synced one last time
    _syncAllFields(calc);

    final result = await calc.submitSale(
      statusOverride: status,
      submitToLhdnOverride: submitToLhdn,
    );
    if (mounted) {
      setState(() => _isSaving = false);
      if (result != null) {
        AppDialogs.showMockLhdnSuccessDialog(
          context,
          invoiceNumber: result.invoiceNumber,
          totalAmount: result.totalPayable,
          isLhdnSubmitted: submitToLhdn,
          saleRecord: result,
          businessProfile: calc.businessProfile,
          onDone: () {
            Navigator.of(context).pop(); // Pops the dialog
            Navigator.of(context).pop(); // Pops the screen
          },
        );
      } else if (calc.error != null) {
      if (mounted) {
        AppDialogs.showSystemAlert(
          context,
          title: 'Review Failed',
          body: calc.error!,
          icon: Icons.error_outline_rounded,
          iconColor: Colors.redAccent,
        );
      }
      }
    }
  }
  // ── Build ─────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    // --- UI Strings (Local Constants for i18n Readiness) ---
    // TODO: Implement i18n
    const String appBarTitle = 'Record Sale';
    const String sectionCustomerType = 'CUSTOMER TYPE';
    const String typeIndividual = 'Individual';
    const String typeBusiness = 'Business';
    const String selectFromContactList = 'Select Customer from Contact List';
    const String walkInCustomer = 'Walk-in Customer';
    
    // Walk-In Card
    const String walkInDetailsTitle = 'Walk-In Customer Details';
    const String labelCustomerName = 'Customer Name';
    const String valueGeneralPublic = 'General Public';
    const String labelTin = 'Tax Identification Number (TIN)';
    const String labelTinShort = 'TIN';
    
    // Selected Customer Card
    const String existingCustomer = 'Existing Customer';
    const String labelAddress = 'Address';

    // Item Details
    const String sectionItemDetails = 'Item Details';
    const String labelSelectItem = 'Select Item';
    const String hintSelectFromCatalog = 'Select from catalog';
    const String labelQuantity = 'Quantity';
    const String labelUnitPrice = 'Unit Price (RM)';
    const String buttonAddAnotherItem = 'Add Another Item';
    
    // Additional Details
    const String sectionAdditionalDetails = 'Additional Details (Optional)';
    const String subHeaderDiscounts = 'Discounts & Charges';
    const String tabRate = 'Rate (%)';
    const String tabAmount = 'Amount (RM)';
    const String labelDiscountRate = 'Discount Rate';
    const String labelFeeRate = 'Fee/Charge Rate';
    const String labelDiscountAmount = 'Discount Amount';
    const String labelFeeAmount = 'Fee/Charge Amount';
    
    const String subHeaderPaymentInfo = 'Payment Information';
    const String labelPaymentMode = 'Payment Mode';
    const String labelBankAccount = "Supplier's Bank Account Number";
    const String labelPaymentTerms = 'Payment Terms';
    const String labelBillRef = 'Bill Reference';
    
    const String subHeaderPrepayment = 'Prepayment Details';
    const String labelPrepayAmount = 'Amount (RM)';
    const String labelPrepayDate = 'Date';
    const String labelPrepayRef = 'Prepayment Reference No.';
    
    const String subHeaderBilling = 'Billing';
    const String labelFrequency = 'Frequency';
    const String labelBillingPeriod = 'Billing Period';
    const String hintSelectPeriod = 'Select Period';

    // Bottom Summary
    const String labelTotalPayable = 'Total Payable';
    const String totalPayableLabel = 'Total Payable';
    const String buttonReviewSale = 'Review Sale';

    // Preview Sheet
    const String previewTitle = 'Review & Submit';
    const String previewSubtitle = 'Verify details before LHDN submission';
    const String eInvoiceLabel = 'e-Invoice';
    const String standardInvoiceLabel = 'Standard Invoice';
    const String subtotalLabel = 'Subtotal';
    const String discountLabel = 'Discount';
    const String feeChargeLabel = 'Fee/Charge';
    const String taxAmountLabel = 'Tax Amount';
    const String taxAmountUnitLabel = 'Tax Amount (Unit-Based)';
    const String roundingLabel = 'Rounding Adjustment';
    const String recordReceiptLabel = 'Record Receipt (For Consolidation)';
    const String confirmPaymentLabel = 'Confirm Payment & Submit';
    const String submitLhdnOnlyLabel = 'Submit to LHDN Only';
    const String saveAsPendingLabel = 'Save as Pending';
    const String incompleteFormTitle = 'Incomplete Form';
    const String incompleteFormBody = 'Please correct the errors in the form before proceeding.';

    // Dialogs & Alerts
    const String discardTitle = 'Discard Changes?';
    const String discardBody = 'You have unsaved changes. Are you sure you want to go back?';
    const String discardButton = 'Discard';
    const String cancelButton = 'Cancel';
    const String applyButton = 'Apply';
    const String editQuantityTitle = 'Edit Quantity';
    const String editQuantityLabel = 'New Quantity';
    const String editPriceTitle = 'Edit Unit Price';
    const String editPriceLabel = 'New Unit Price (RM)';
    const String duplicateItemTitle = 'Already Added';
    const String duplicateItemBody = 'You have already added this item to the current sale.';
    const String duplicateItemButton = 'Got it';

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        _handleBackPress(
          discardTitle: discardTitle,
          discardBody: discardBody,
          discardButton: discardButton,
          cancelButton: cancelButton,
        );
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text(appBarTitle),
          backgroundColor: Colors.transparent,
          elevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () => _handleBackPress(
              discardTitle: discardTitle,
              discardBody: discardBody,
              discardButton: discardButton,
              cancelButton: cancelButton,
            ),
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
                          _buildCustomerTypeSection(
                            calc, 
                            theme,
                            sectionTitle: sectionCustomerType,
                            typeIndividual: typeIndividual,
                            typeBusiness: typeBusiness,
                            selectFromContactList: selectFromContactList,
                            walkInCustomer: walkInCustomer,
                            walkInDetailsTitle: walkInDetailsTitle,
                            labelCustomerName: labelCustomerName,
                            valueGeneralPublic: valueGeneralPublic,
                            labelTin: labelTin,
                            existingCustomer: existingCustomer,
                            labelTinShort: labelTinShort,
                            labelAddress: labelAddress,
                          ),
                          const SizedBox(height: 28),

                            _buildItemDetailsSection(
                              calc, 
                              theme,
                              title: sectionItemDetails,
                              labelSelectItem: labelSelectItem,
                              hintSelectFromCatalog: hintSelectFromCatalog,
                              labelQuantity: labelQuantity,
                              labelUnitPrice: labelUnitPrice,
                              buttonAddAnotherItem: buttonAddAnotherItem,
                              editQuantityTitle: editQuantityTitle,
                              editQuantityLabel: editQuantityLabel,
                              editPriceTitle: editPriceTitle,
                              editPriceLabel: editPriceLabel,
                              applyButton: applyButton,
                              cancelButton: cancelButton,
                              duplicateItemTitle: duplicateItemTitle,
                              duplicateItemBody: duplicateItemBody,
                              duplicateItemButton: duplicateItemButton,
                            ),
                          const SizedBox(height: 28),

                          _buildAdditionalDetails(
                            calc, 
                            theme,
                            title: sectionAdditionalDetails,
                            subHeaderDiscounts: subHeaderDiscounts,
                            tabRate: tabRate,
                            tabAmount: tabAmount,
                            labelDiscountRate: labelDiscountRate,
                            labelFeeRate: labelFeeRate,
                            labelDiscountAmount: labelDiscountAmount,
                            labelFeeAmount: labelFeeAmount,
                            subHeaderPaymentInfo: subHeaderPaymentInfo,
                            labelPaymentMode: labelPaymentMode,
                            labelBankAccount: labelBankAccount,
                            labelPaymentTerms: labelPaymentTerms,
                            labelBillRef: labelBillRef,
                            subHeaderPrepayment: subHeaderPrepayment,
                            labelPrepayAmount: labelPrepayAmount,
                            labelPrepayDate: labelPrepayDate,
                            labelPrepayRef: labelPrepayRef,
                            subHeaderBilling: subHeaderBilling,
                            labelFrequency: labelFrequency,
                            labelBillingPeriod: labelBillingPeriod,
                            hintSelectPeriod: hintSelectPeriod,
                          ),
                          const SizedBox(height: 32),
                        ],
                      ),
                    ),
                  ),
                ),
                _buildBottomSummary(
                  calc, 
                  theme,
                  labelTotalPayable: labelTotalPayable,
                  buttonReviewSale: buttonReviewSale,
                  previewTitle: previewTitle,
                  previewSubtitle: previewSubtitle,
                  eInvoiceLabel: eInvoiceLabel,
                  standardInvoiceLabel: standardInvoiceLabel,
                  subtotalLabel: subtotalLabel,
                  discountLabel: discountLabel,
                  feeChargeLabel: feeChargeLabel,
                  taxAmountLabel: taxAmountLabel,
                  taxAmountUnitLabel: taxAmountUnitLabel,
                  roundingLabel: roundingLabel,
                  totalPayableLabel: totalPayableLabel,
                  recordReceiptLabel: recordReceiptLabel,
                  confirmPaymentLabel: confirmPaymentLabel,
                  submitLhdnOnlyLabel: submitLhdnOnlyLabel,
                  saveAsPendingLabel: saveAsPendingLabel,
                  incompleteFormTitle: incompleteFormTitle,
                  incompleteFormBody: incompleteFormBody,
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  // ── Widgets ──────────────────────────────────────────────────────────

  Widget _buildCustomerTypeSection(
    SaleCalculatorProvider calc, 
    ThemeData theme, {
    required String sectionTitle,
    required String typeIndividual,
    required String typeBusiness,
    required String selectFromContactList,
    required String walkInCustomer,
    required String walkInDetailsTitle,
    required String labelCustomerName,
    required String valueGeneralPublic,
    required String labelTin,
    required String existingCustomer,
    required String labelTinShort,
    required String labelAddress,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          sectionTitle,
          style: theme.textTheme.labelMedium?.copyWith(fontWeight: FontWeight.w700, letterSpacing: 1.2, color: theme.colorScheme.onSurfaceVariant),
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(child: _buildTypeCard(label: typeIndividual, icon: Icons.person_rounded, isSelected: _selectedType == SaleCustomerType.individual, onTap: () => _onTypeChanged(SaleCustomerType.individual, calc), theme: theme)),
            const SizedBox(width: 12),
            Expanded(child: _buildTypeCard(label: typeBusiness, icon: Icons.store_rounded, isSelected: _selectedType == SaleCustomerType.business, onTap: () => _onTypeChanged(SaleCustomerType.business, calc), theme: theme)),
          ],
        ),
        const SizedBox(height: 24),
        if (_isWalkIn)
          _buildWalkInCard(
            calc, 
            theme,
            walkInDetailsTitle: walkInDetailsTitle,
            labelCustomerName: labelCustomerName,
            valueGeneralPublic: valueGeneralPublic,
            labelTin: labelTin,
          )
        else if (calc.selectedCustomer != null)
          _buildSelectedCustomerCard(
            calc, 
            theme,
            existingCustomer: existingCustomer,
            labelTinShort: labelTinShort,
            labelAddress: labelAddress,
          )
        else
          InkWell(
            onTap: () async {
              final selectedCustomer = await Navigator.push<Customer>(
                context,
                MaterialPageRoute(
                  builder: (_) => const CustomerListScreen(isPickerMode: true),
                ),
              );
              if (selectedCustomer != null) {
                calc.selectCustomer(selectedCustomer);
                if (selectedCustomer.customerType == CustomerType.b2b) {
                  setState(() => _selectedType = SaleCustomerType.business);
                } else {
                  setState(() => _selectedType = SaleCustomerType.individual);
                }
              }
            },
            borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
                border: Border.all(color: AppTheme.primary.withValues(alpha: 0.2)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.contact_page_rounded, color: AppTheme.primary),
                  const SizedBox(width: 12),
                  Text(
                    selectFromContactList,
                    style: theme.textTheme.bodyLarge?.copyWith(
                      color: AppTheme.primary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const Spacer(),
                  const Icon(Icons.chevron_right_rounded, color: AppTheme.primary),
                ],
              ),
            ),
          ),
        if (_selectedType == SaleCustomerType.individual && !_isWalkIn) ...[
          const SizedBox(height: 12),
          AppButton(
            text: walkInCustomer,
            isPrimary: false,
            onPressed: () => _selectWalkIn(calc),
            icon: Icon(Icons.person_add_alt_1_rounded, size: 20, color: theme.colorScheme.onSurface),
          ),
        ],
      ],
    );
  }

  Widget _buildWalkInCard(
    SaleCalculatorProvider calc, 
    ThemeData theme, {
    required String walkInDetailsTitle,
    required String labelCustomerName,
    required String valueGeneralPublic,
    required String labelTin,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(AppTheme.radiusLarge),
        border: Border.all(color: theme.colorScheme.surfaceContainerHighest),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Icon(Icons.storefront_rounded, color: AppTheme.primary, size: 20),
                  const SizedBox(width: 8),
                  Text(walkInDetailsTitle, style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold, color: AppTheme.primary)),
                ],
              ),
              IconButton(
                icon: Icon(Icons.edit_rounded, color: AppTheme.primary, size: 20),
                onPressed: () {
                  setState(() => _isWalkIn = false);
                  calc.selectCustomer(null);
                },
                constraints: const BoxConstraints(),
                padding: EdgeInsets.zero,
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(labelCustomerName, style: theme.textTheme.labelMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
          const SizedBox(height: 4),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
              borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
            ),
            child: Text(valueGeneralPublic, style: theme.textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.w600)),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Icon(Icons.badge_rounded, size: 16, color: theme.colorScheme.onSurfaceVariant),
              const SizedBox(width: 4),
              Text(labelTin, style: theme.textTheme.labelMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
              const Spacer(),
              Icon(Icons.lock_outline_rounded, size: 14, color: theme.colorScheme.onSurfaceVariant),
            ],
          ),
          const SizedBox(height: 4),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
              borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
            ),
            child: Text(Customer.walkIn.tinNumber, style: theme.textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.w600, color: theme.colorScheme.onSurfaceVariant)),
          ),
        ],
      ),
    );
  }

  Widget _buildSelectedCustomerCard(
    SaleCalculatorProvider calc, 
    ThemeData theme, {
    required String existingCustomer,
    required String labelTinShort,
    required String labelAddress,
  }) {
    final customer = calc.selectedCustomer!;
    
    // Fallbacks
    final initials = customer.name.isNotEmpty 
        ? customer.name.substring(0, math.min(2, customer.name.length)).toUpperCase() 
        : 'C';
        
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(AppTheme.radiusLarge),
        border: Border.all(color: theme.colorScheme.surfaceContainerHighest),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              CircleAvatar(
                radius: 24,
                backgroundColor: AppTheme.primary.withValues(alpha: 0.2),
                child: Text(
                  initials,
                  style: theme.textTheme.titleMedium?.copyWith(
                    color: AppTheme.primary,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      customer.name,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      existingCustomer,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                icon: const Icon(Icons.edit_rounded, color: AppTheme.primary, size: 20),
                onPressed: () => calc.selectCustomer(null),
                constraints: const BoxConstraints(),
                padding: EdgeInsets.zero,
              ),
            ],
          ),
          const SizedBox(height: 16),
          Divider(color: theme.colorScheme.surfaceContainerHighest),
          const SizedBox(height: 16),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                flex: 2,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      labelTinShort,
                      style: theme.textTheme.labelMedium?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      customer.tinNumber.isNotEmpty ? customer.tinNumber : '-',
                      style: theme.textTheme.bodyLarge?.copyWith(
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                flex: 3,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      labelAddress,
                      style: theme.textTheme.labelMedium?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      customer.city.isNotEmpty ? customer.city : '-',
                      style: theme.textTheme.bodyLarge?.copyWith(
                        fontWeight: FontWeight.w500,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
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

  Widget _buildItemDetailsSection(
    SaleCalculatorProvider calc, 
    ThemeData theme, {
    required String title,
    required String labelSelectItem,
    required String hintSelectFromCatalog,
    required String labelQuantity,
    required String labelUnitPrice,
    required String buttonAddAnotherItem,
    required String editQuantityTitle,
    required String editQuantityLabel,
    required String editPriceTitle,
    required String editPriceLabel,
    required String applyButton,
    required String cancelButton,
    required String duplicateItemTitle,
    required String duplicateItemBody,
    required String duplicateItemButton,
  }) {
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
            title,
            style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 20),
          ...calc.lineItems.asMap().entries.map((entry) {
            final idx = entry.key;
            final line = entry.value;
            return Padding(
              padding: const EdgeInsets.only(bottom: 16.0),
              child: _buildItemBlock(
                calc, 
                theme, 
                idx, 
                line,
                labelSelectItem: labelSelectItem,
                hintSelectFromCatalog: hintSelectFromCatalog,
                labelQuantity: labelQuantity,
                labelUnitPrice: labelUnitPrice,
                editQuantityTitle: editQuantityTitle,
                editQuantityLabel: editQuantityLabel,
                editPriceTitle: editPriceTitle,
                editPriceLabel: editPriceLabel,
                applyButton: applyButton,
                cancelButton: cancelButton,
                duplicateItemTitle: duplicateItemTitle,
                duplicateItemBody: duplicateItemBody,
                duplicateItemButton: duplicateItemButton,
              ),
            );
          }),
          if (calc.lineItems.isEmpty) _buildItemPlaceholder(
            calc, 
            theme,
            labelSelectItem: labelSelectItem,
            hintSelectFromCatalog: hintSelectFromCatalog,
            duplicateItemTitle: duplicateItemTitle,
            duplicateItemBody: duplicateItemBody,
            duplicateItemButton: duplicateItemButton,
          ),
          const SizedBox(height: 12),
          _buildAddAnotherItemButton(
            calc, 
            theme,
            buttonAddAnotherItem: buttonAddAnotherItem,
            labelSelectItem: labelSelectItem,
            duplicateItemTitle: duplicateItemTitle,
            duplicateItemBody: duplicateItemBody,
            duplicateItemButton: duplicateItemButton,
          ),
        ],
      ),
    );
  }

  Widget _buildItemBlock(
    SaleCalculatorProvider calc, 
    ThemeData theme, 
    int index, 
    SaleLineItem line, {
    required String labelSelectItem,
    required String hintSelectFromCatalog,
    required String labelQuantity,
    required String labelUnitPrice,
    required String editQuantityTitle,
    required String editQuantityLabel,
    required String editPriceTitle,
    required String editPriceLabel,
    required String applyButton,
    required String cancelButton,
    required String duplicateItemTitle,
    required String duplicateItemBody,
    required String duplicateItemButton,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(labelSelectItem, style: theme.textTheme.labelMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
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
          hint: hintSelectFromCatalog,
          items: calc.saleItems.map((item) => CustomDropdownItem<String>(label: item.name, value: item.id, icon: Icons.inventory_2_rounded)).toList(),
          isSearchable: true,
          onChanged: (val) {
            if (val != null) {
              if (_isItemAlreadyAdded(calc, val, excludeIndex: index)) {
                _showDuplicateError(
                  title: duplicateItemTitle,
                  body: duplicateItemBody,
                  buttonText: duplicateItemButton,
                );
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
                  Text(labelQuantity, style: theme.textTheme.labelMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
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
                        InkWell(
                          onTap: () => _showQuantityEditDialog(
                            calc, 
                            index, 
                            line,
                            title: editQuantityTitle,
                            label: editQuantityLabel,
                            applyButton: applyButton,
                            cancelButton: cancelButton,
                          ),
                          child: Text(
                            line.quantity.toStringAsFixed(0),
                            style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
                          ),
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
                  Text(labelUnitPrice, style: theme.textTheme.labelMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
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
                          onPressed: () => _showPriceOverrideDialog(
                            calc, 
                            index, 
                            line,
                            title: editPriceTitle,
                            label: editPriceLabel,
                            applyButton: applyButton,
                            cancelButton: cancelButton,
                          ),
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

  Widget _buildItemPlaceholder(
    SaleCalculatorProvider calc, 
    ThemeData theme, {
    required String labelSelectItem,
    required String hintSelectFromCatalog,
    required String duplicateItemTitle,
    required String duplicateItemBody,
    required String duplicateItemButton,
  }) {
    return CustomPremiumDropdown<String>(
      label: labelSelectItem,
      value: null,
      hint: hintSelectFromCatalog,
      items: calc.saleItems.map((item) => CustomDropdownItem<String>(label: item.name, value: item.id, icon: Icons.inventory_2_rounded)).toList(),
      isSearchable: true,
      onChanged: (val) {
        if (val != null) {
          if (_isItemAlreadyAdded(calc, val)) {
            _showDuplicateError(
              title: duplicateItemTitle,
              body: duplicateItemBody,
              buttonText: duplicateItemButton,
            );
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

  Widget _buildAddAnotherItemButton(
    SaleCalculatorProvider calc, 
    ThemeData theme, {
    required String buttonAddAnotherItem,
    required String labelSelectItem,
    required String duplicateItemTitle,
    required String duplicateItemBody,
    required String duplicateItemButton,
  }) {
    return InkWell(
      onTap: () => _showItemPicker(
        calc, 
        theme, 
        labelSelectItem: labelSelectItem,
        duplicateItemTitle: duplicateItemTitle,
        duplicateItemBody: duplicateItemBody,
        duplicateItemButton: duplicateItemButton,
      ),
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
              buttonAddAnotherItem,
              style: theme.textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.w600, color: AppTheme.secondaryDark),
            ),
          ],
        ),
      ),
    );
  }

  void _showItemPicker(
    SaleCalculatorProvider calc, 
    ThemeData theme, {
    required String labelSelectItem,
    required String duplicateItemTitle,
    required String duplicateItemBody,
    required String duplicateItemButton,
  }) {
    CustomPremiumDropdown.showPicker<String>(
      context: context,
      title: labelSelectItem,
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
          _showDuplicateError(
            title: duplicateItemTitle,
            body: duplicateItemBody,
            buttonText: duplicateItemButton,
          );
          return;
        }
        final item = calc.saleItems.firstWhere((i) => i.id == val);
        calc.addLineItem(item);
      }
    });
  }

  void _showQuantityEditDialog(
    SaleCalculatorProvider calc, 
    int index, 
    SaleLineItem line, {
    required String title,
    required String label,
    required String applyButton,
    required String cancelButton,
  }) {
    final controller = TextEditingController(text: line.quantity.toStringAsFixed(0));
    AppDialogs.showFormModal(
      context,
      title: title,
      formBody: AppTextField(
        controller: controller,
        label: label,
        keyboardType: const TextInputType.numberWithOptions(decimal: false),
      ),
      primaryButtonText: applyButton,
      onPrimaryPressed: () async {
        final qty = double.tryParse(controller.text);
        if (qty != null && qty >= 0) {
          calc.updateLineItemQuantity(index, qty);
        }
        return true;
      },
      secondaryButtonText: cancelButton,
      onSecondaryPressed: () {},
    );
  }

  void _showPriceOverrideDialog(
    SaleCalculatorProvider calc, 
    int index, 
    SaleLineItem line, {
    required String title,
    required String label,
    required String applyButton,
    required String cancelButton,
  }) {
    final controller = TextEditingController(text: line.unitPrice.toStringAsFixed(2));
    AppDialogs.showFormModal(
      context,
      title: title,
      formBody: AppTextField(
        controller: controller,
        label: label,
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
      ),
      primaryButtonText: applyButton,
      onPrimaryPressed: () async {
        final price = double.tryParse(controller.text);
        if (price != null) {
          calc.updateLineItemPrice(index, price);
        }
        return true;
      },
      secondaryButtonText: cancelButton,
      onSecondaryPressed: () {},
    );
  }

  Widget _buildBottomSummary(
    SaleCalculatorProvider calc, 
    ThemeData theme, {
    required String labelTotalPayable,
    required String buttonReviewSale,
    required String previewTitle,
    required String previewSubtitle,
    required String eInvoiceLabel,
    required String standardInvoiceLabel,
    required String subtotalLabel,
    required String discountLabel,
    required String feeChargeLabel,
    required String taxAmountLabel,
    required String taxAmountUnitLabel,
    required String roundingLabel,
    required String totalPayableLabel,
    required String recordReceiptLabel,
    required String confirmPaymentLabel,
    required String submitLhdnOnlyLabel,
    required String saveAsPendingLabel,
    required String incompleteFormTitle,
    required String incompleteFormBody,
  }) {
    return Container(
      padding: const EdgeInsets.fromLTRB(24, 20, 24, 40),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        boxShadow: [
          BoxShadow(
            color: theme.brightness == Brightness.dark ? Colors.black.withValues(alpha: 0.4) : Colors.black.withValues(alpha: 0.05),
            blurRadius: 24,
            offset: const Offset(0, -8),
          )
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                labelTotalPayable, 
                style: theme.textTheme.titleMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                  letterSpacing: 0.5,
                ),
              ),
              Text(
                'RM ${calc.totalPayable.toStringAsFixed(2)}', 
                style: theme.textTheme.headlineMedium?.copyWith(
                  fontWeight: FontWeight.w900, 
                  color: theme.colorScheme.onSurface,
                  letterSpacing: -0.5,
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          InkWell(
            onTap: (_isSaving || !calc.canSubmit) 
              ? null 
              : () async {
                  // Validate before showing loader/fetching invoice
                  _syncAllFields(calc);
                  if (!_formKey.currentState!.validate()) {
                    AppDialogs.showSystemAlert(
                      context, 
                      title: incompleteFormTitle, 
                      body: incompleteFormBody,
                      icon: Icons.warning_amber_rounded,
                    );
                    return;
                  }

                  setState(() => _isSaving = true);
                  await calc.fetchPreviewInvoiceNumber();
                  setState(() => _isSaving = false);
                  _showPreviewSheet(
                    title: previewTitle,
                    subtitle: previewSubtitle,
                    eInvoiceLabel: eInvoiceLabel,
                    standardInvoiceLabel: standardInvoiceLabel,
                    subtotalLabel: subtotalLabel,
                    discountLabel: discountLabel,
                    feeChargeLabel: feeChargeLabel,
                    taxAmountLabel: taxAmountLabel,
                    taxAmountUnitLabel: taxAmountUnitLabel,
                    roundingLabel: roundingLabel,
                    totalPayableLabel: totalPayableLabel,
                    recordReceiptLabel: recordReceiptLabel,
                    confirmPaymentLabel: confirmPaymentLabel,
                    submitLhdnOnlyLabel: submitLhdnOnlyLabel,
                    saveAsPendingLabel: saveAsPendingLabel,
                    incompleteFormTitle: incompleteFormTitle,
                    incompleteFormBody: incompleteFormBody,
                  );
                },
            borderRadius: BorderRadius.circular(20),
            child: Container(
              height: 64,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF8B8FFF), Color(0xFF6B70FF)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF6B70FF).withValues(alpha: 0.4),
                    blurRadius: 16,
                    offset: const Offset(0, 8),
                  )
                ],
              ),
              child: Center(
                child: _isSaving 
                  ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                  : Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          buttonReviewSale, 
                          style: theme.textTheme.titleMedium?.copyWith(
                            color: Colors.white, 
                            fontWeight: FontWeight.bold,
                            letterSpacing: 1,
                          ),
                        ),
                        const SizedBox(width: 12),
                        const Icon(Icons.arrow_forward_rounded, color: Colors.white, size: 22),
                      ],
                    ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSubHeader(String title, IconData icon, ThemeData theme, {bool? isChecked, ValueChanged<bool?>? onChanged}) {
    return Padding(
      padding: const EdgeInsets.only(top: 16.0, bottom: 8.0),
      child: Row(
        children: [
          if (isChecked != null && onChanged != null)
            Checkbox(
              value: isChecked,
              onChanged: onChanged,
              activeColor: theme.colorScheme.primary,
              materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
              visualDensity: VisualDensity.compact,
            ),
          if (isChecked != null && onChanged != null) const SizedBox(width: 8),
          Icon(icon, color: theme.colorScheme.primary, size: 18),
          const SizedBox(width: 8),
          Text(title, style: theme.textTheme.labelLarge?.copyWith(color: theme.colorScheme.primary, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  Widget _buildAdditionalDetails(
    SaleCalculatorProvider provider, 
    ThemeData theme, {
    required String title,
    required String subHeaderDiscounts,
    required String tabRate,
    required String tabAmount,
    required String labelDiscountRate,
    required String labelFeeRate,
    required String labelDiscountAmount,
    required String labelFeeAmount,
    required String subHeaderPaymentInfo,
    required String labelPaymentMode,
    required String labelBankAccount,
    required String labelPaymentTerms,
    required String labelBillRef,
    required String subHeaderPrepayment,
    required String labelPrepayAmount,
    required String labelPrepayDate,
    required String labelPrepayRef,
    required String subHeaderBilling,
    required String labelFrequency,
    required String labelBillingPeriod,
    required String hintSelectPeriod,
  }) {
    final isDark = theme.brightness == Brightness.dark;
    return Card(
      color: theme.colorScheme.surfaceContainerHighest,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppTheme.radiusMedium)),
      child: Theme(
        data: theme.copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          title: Text(
            title, 
            style: theme.textTheme.titleMedium?.copyWith(
              color: theme.colorScheme.onSurface,
              fontWeight: FontWeight.bold,
            )
          ),
          iconColor: isDark ? AppTheme.neonGreenDark : theme.colorScheme.primary,
          collapsedIconColor: theme.colorScheme.onSurfaceVariant,
          tilePadding: const EdgeInsets.symmetric(horizontal: 16),
          childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
          children: [
            // 1. Discounts & Charges
            _buildSubHeader(
              subHeaderDiscounts, 
              Icons.local_offer_rounded, 
              theme,
              isChecked: _enableDiscountCharges,
              onChanged: (val) {
                final enabled = val ?? false;
                setState(() => _enableDiscountCharges = enabled);
                provider.setEnableDiscountCharges(enabled);
                if (!_enableDiscountCharges) {
                  _discountRateCtrl.clear();
                  _feeRateCtrl.clear();
                  _discountController.clear();
                  _feeAmountCtrl.clear();
                  provider.setDiscountRate(0.0);
                  provider.setFeeRate(0.0);
                  provider.setDiscountAmount(0.0);
                  provider.setFeeAmount(0.0);
                }
              },
            ),
            const SizedBox(height: 8),
            if (_enableDiscountCharges) ...[
              // Rate / Amount Toggle
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: theme.colorScheme.surface,
                  borderRadius: BorderRadius.circular(AppTheme.radiusXLarge),
                ),
                child: Row(
                  children: [
                    _buildSegmentTab(
                      theme,
                      label: tabRate,
                      isActive: _isDiscountRate,
                      onTap: () {
                        setState(() => _isDiscountRate = true);
                        provider.setDiscountRateMode(true);
                      },
                    ),
                    _buildSegmentTab(
                      theme,
                      label: tabAmount,
                      isActive: !_isDiscountRate,
                      onTap: () {
                        setState(() => _isDiscountRate = false);
                        provider.setDiscountRateMode(false);
                      },
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              if (_isDiscountRate) ...[
                Row(
                  children: [
                    Expanded(
                      child: _buildLabeledField(
                        labelDiscountRate,
                        TextFormField(
                          controller: _discountRateCtrl,
                          keyboardType: TextInputType.number,
                          textInputAction: TextInputAction.done,
                          textAlign: TextAlign.end,
                          style: TextStyle(color: theme.colorScheme.onSurface),
                          onChanged: (val) {
                            final rate = double.tryParse(val) ?? 0.0;
                            provider.setDiscountRate(rate);
                          },
                          decoration: const InputDecoration(suffixText: '%', hintText: '0.00'),
                        ),
                        theme,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: _buildLabeledField(
                        labelFeeRate,
                        TextFormField(
                          controller: _feeRateCtrl,
                          keyboardType: TextInputType.number,
                          textInputAction: TextInputAction.done,
                          textAlign: TextAlign.end,
                          style: TextStyle(color: theme.colorScheme.onSurface),
                          onChanged: (val) {
                            final rate = double.tryParse(val) ?? 0.0;
                            provider.setFeeRate(rate);
                          },
                          decoration: const InputDecoration(suffixText: '%', hintText: '0.00'),
                        ),
                        theme,
                      ),
                    ),
                  ],
                ),
              ] else ...[
                Row(
                  children: [
                    Expanded(
                      child: _buildLabeledField(
                        labelDiscountAmount,
                        TextFormField(
                          controller: _discountController,
                          keyboardType: TextInputType.number,
                          textInputAction: TextInputAction.done,
                          textAlign: TextAlign.end,
                          style: TextStyle(color: theme.colorScheme.onSurface),
                          onChanged: (val) {
                            final amt = double.tryParse(val) ?? 0.0;
                            provider.setDiscountAmount(amt);
                          },
                          decoration: const InputDecoration(prefixText: 'RM ', hintText: '0.00'),
                        ),
                        theme,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: _buildLabeledField(
                        labelFeeAmount,
                        TextFormField(
                          controller: _feeAmountCtrl,
                          keyboardType: TextInputType.number,
                          textInputAction: TextInputAction.done,
                          textAlign: TextAlign.end,
                          style: TextStyle(color: theme.colorScheme.onSurface),
                          onChanged: (val) {
                            final amt = double.tryParse(val) ?? 0.0;
                            provider.setFeeAmount(amt);
                          },
                          decoration: const InputDecoration(prefixText: 'RM ', hintText: '0.00'),
                        ),
                        theme,
                      ),
                    ),
                  ],
                ),
              ],
              const SizedBox(height: 24),
            ],
            // 2. Payment Information
            _buildSubHeader(
              subHeaderPaymentInfo, 
              Icons.payment_rounded, 
              theme,
              isChecked: _enablePaymentInfo,
              onChanged: (val) {
                final enabled = val ?? false;
                setState(() => _enablePaymentInfo = enabled);
                provider.setEnablePaymentInfo(enabled);
                if (!_enablePaymentInfo) {
                  _bankAccountCtrl.clear();
                  _paymentTermsCtrl.clear();
                  _billRefCtrl.clear();
                  provider.setPaymentMode('01'); 
                  provider.setSupplierBankAccount('');
                  provider.setPaymentTerms('');
                  provider.setBillReference('');
                }
              },
            ),
            const SizedBox(height: 8),
            if (_enablePaymentInfo) ...[
              CustomPremiumDropdown<String>(
                label: labelPaymentMode,
                value: provider.paymentMode,
                items: CustomDropdownBuilder.fromMap(
                  LhdnConstants.paymentModes,
                  icon: Icons.payment_outlined,
                ),
                onChanged: (val) {
                  final mode = val ?? '01';
                  provider.setPaymentMode(mode);
                  if (mode == '03') {
                    // Sync the local controller with the provider's pre-filled value
                    _bankAccountCtrl.text = provider.supplierBankAccount;
                  }
                },
                validator: (v) => AppValidators.requiredField(v, labelPaymentMode),
                fillColor: theme.colorScheme.surface,
              ),
              
              // Conditional: Supplier Bank Account (only if Bank selected)
              if (provider.paymentMode == '03') ...[
                const SizedBox(height: 16),
                _buildLabeledField(
                  labelBankAccount,
                  TextFormField(
                    controller: _bankAccountCtrl,
                    style: TextStyle(color: theme.colorScheme.onSurface),
                    onChanged: (val) => provider.setSupplierBankAccount(val),
                    validator: (v) => AppValidators.numeric(v, 'Account Number'),
                    decoration: const InputDecoration(hintText: 'Account Number'),
                  ),
                  theme,
                ),
              ],

              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: _buildLabeledField(
                      labelPaymentTerms,
                      TextFormField(
                        controller: _paymentTermsCtrl,
                        style: TextStyle(color: theme.colorScheme.onSurface),
                        onChanged: (val) => provider.setPaymentTerms(val),
                        decoration: const InputDecoration(hintText: 'e.g. Net 30'),
                      ),
                      theme,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: _buildLabeledField(
                      labelBillRef,
                      TextFormField(
                        controller: _billRefCtrl,
                        style: TextStyle(color: theme.colorScheme.onSurface),
                        onChanged: (val) => provider.setBillReference(val),
                        decoration: const InputDecoration(hintText: 'Reference No.'),
                      ),
                      theme,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
            ],
            // 3. Prepayment Details
            _buildSubHeader(
              subHeaderPrepayment, 
              Icons.account_balance_wallet_rounded, 
              theme,
              isChecked: _enablePrepayment,
              onChanged: (val) {
                final enabled = val ?? false;
                setState(() => _enablePrepayment = enabled);
                provider.setEnablePrepayment(enabled);
                if (!_enablePrepayment) {
                  _prepayAmountCtrl.clear();
                  _prepayRefCtrl.clear();
                  setState(() => _prepaymentDate = null);
                  provider.setPrepaymentAmount(0.0);
                  provider.setPrepaymentDate(null);
                  provider.setPrepaymentReference('');
                }
              },
            ),
            const SizedBox(height: 8),
            if (_enablePrepayment) ...[
              Row(
                children: [
                  Expanded(
                    child: _buildLabeledField(
                      labelPrepayAmount,
                      TextFormField(
                        controller: _prepayAmountCtrl,
                        keyboardType: TextInputType.number,
                        textInputAction: TextInputAction.done,
                        textAlign: TextAlign.end,
                        style: TextStyle(color: theme.colorScheme.onSurface),
                        onChanged: (val) => provider.setPrepaymentAmount(double.tryParse(val) ?? 0.0),
                        validator: (v) => AppValidators.positiveNumber(v, labelPrepayAmount),
                        decoration: const InputDecoration(prefixText: 'RM ', hintText: '0.00'),
                      ),
                      theme,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: _buildLabeledField(
                      labelPrepayDate,
                      FormField<DateTime>(
                        initialValue: _prepaymentDate,
                        validator: (v) => v == null ? 'Please select a date' : null,
                        builder: (state) => Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            InkWell(
                              onTap: () async {
                                final picked = await showDatePicker(
                                  context: context,
                                  initialDate: _prepaymentDate ?? DateTime.now(),
                                  firstDate: DateTime(2020),
                                  lastDate: DateTime(2100),
                                );
                                if (picked != null) {
                                  setState(() => _prepaymentDate = picked);
                                  provider.setPrepaymentDate(picked);
                                  state.didChange(picked);
                                }
                              },
                              child: InputDecorator(
                                decoration: InputDecoration(
                                  suffixIcon: const Icon(Icons.calendar_today_rounded, size: 18),
                                  errorText: state.hasError ? state.errorText : null,
                                  border: state.hasError ? OutlineInputBorder(borderSide: BorderSide(color: theme.colorScheme.error)) : null,
                                ),
                                child: Text(
                                  _prepaymentDate != null ? DateFormat('yyyy-MM-dd').format(_prepaymentDate!) : 'Select Date', 
                                  style: TextStyle(color: theme.colorScheme.onSurface),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      theme,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              _buildLabeledField(
                labelPrepayRef,
                TextFormField(
                  controller: _prepayRefCtrl,
                  style: TextStyle(color: theme.colorScheme.onSurface),
                  onChanged: (val) => provider.setPrepaymentReference(val),
                  decoration: const InputDecoration(hintText: 'Reference No.'),
                ),
                theme,
              ),
              const SizedBox(height: 24),
            ],
            // 4. Billing
            _buildSubHeader(
              subHeaderBilling, 
              Icons.receipt_rounded, 
              theme,
              isChecked: _enableBillingExemption,
              onChanged: (val) {
                final enabled = val ?? false;
                setState(() => _enableBillingExemption = enabled);
                provider.setEnableBillingExemption(enabled);
                if (!_enableBillingExemption) {
                  setState(() {
                    _billingFrequency = null;
                    _billingStartDate = null;
                    _billingEndDate = null;
                  });
                  provider.setBillingFrequency('');
                  provider.setTaxExemptionAmount(0.0);
                  provider.setBillingPeriod(null, null);
                }
              },
            ),
            const SizedBox(height: 8),
            if (_enableBillingExemption) ...[
              CustomPremiumDropdown<String>(
                label: labelFrequency,
                value: _billingFrequency,
                items: CustomDropdownBuilder.fromList(
                  ['Daily', 'Weekly', 'Monthly', 'Quarterly', 'Annually'],
                  icon: Icons.repeat_rounded,
                ),
                onChanged: (val) {
                  setState(() => _billingFrequency = val);
                  provider.setBillingFrequency(val ?? '');
                },
                validator: (v) => AppValidators.requiredField(v, labelFrequency),
                fillColor: theme.colorScheme.surface,
              ),
              const SizedBox(height: 16),

              _buildLabeledField(
                labelBillingPeriod,
                FormField<DateTimeRange>(
                  initialValue: (_billingStartDate != null && _billingEndDate != null) 
                    ? DateTimeRange(start: _billingStartDate!, end: _billingEndDate!) 
                    : null,
                  validator: (v) => v == null ? 'Please select a billing period' : null,
                  builder: (state) => Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      InkWell(
                        onTap: () async {
                          final picked = await showDateRangePicker(
                            context: context,
                            firstDate: DateTime(2020),
                            lastDate: DateTime(2100),
                            initialDateRange: state.value,
                          );
                          if (picked != null) {
                            setState(() {
                              _billingStartDate = picked.start;
                              _billingEndDate = picked.end;
                            });
                            provider.setBillingPeriod(picked.start, picked.end);
                            state.didChange(picked);
                          }
                        },
                        child: InputDecorator(
                          decoration: InputDecoration(
                            suffixIcon: const Icon(Icons.date_range_rounded, size: 18),
                            errorText: state.hasError ? state.errorText : null,
                            border: state.hasError ? OutlineInputBorder(borderSide: BorderSide(color: theme.colorScheme.error)) : null,
                          ),
                          child: Text(
                            (_billingStartDate != null && _billingEndDate != null)
                                ? "${DateFormat('yyyy-MM-dd').format(_billingStartDate!)} to ${DateFormat('yyyy-MM-dd').format(_billingEndDate!)}"
                                : hintSelectPeriod,
                            style: TextStyle(color: theme.colorScheme.onSurface),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                theme,
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildLabeledField(String label, Widget field, ThemeData theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: theme.textTheme.labelMedium?.copyWith(
            fontWeight: FontWeight.w600,
            color: theme.colorScheme.onSurface,
          ),
        ),
        const SizedBox(height: 8),
        field,
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
          height: 36,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: isActive ? AppTheme.primary : Colors.transparent,
            borderRadius: BorderRadius.circular(AppTheme.radiusXLarge),
          ),
          child: Text(
            label,
            style: theme.textTheme.labelLarge?.copyWith(
              color: isActive ? Colors.white : theme.colorScheme.onSurfaceVariant,
              fontWeight: isActive ? FontWeight.w700 : FontWeight.w500,
              fontSize: 13,
            ),
          ),
        ),
      ),
    );
  }
}

