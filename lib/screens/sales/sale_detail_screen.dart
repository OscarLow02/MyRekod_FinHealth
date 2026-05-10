import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../core/app_theme.dart';
import '../../core/lhdn_constants.dart';
import '../../models/sale_record.dart';
import '../../models/customer.dart';
import '../../models/business_profile.dart';
import '../../providers/sales_provider.dart';
import '../../services/firestore_service.dart';
import '../../services/lhdn_submission_service.dart';
import '../../widgets/app_dialogs.dart';
import '../../widgets/custom_widgets.dart';
import '../../services/csv_export_service.dart';

/// Detailed view of a completed sale record.
///
/// Features:
/// - Hero amount card with LHDN compliance status badge
/// - Full transaction breakdown (item, customer, pricing, tax)
/// - LHDN e-Invoice submission trigger (mock)
/// - JSON payload preview
/// - Export to CSV
/// - Delete with confirmation
class SaleDetailScreen extends StatefulWidget {
  final SaleRecord sale;

  const SaleDetailScreen({super.key, required this.sale});

  @override
  State<SaleDetailScreen> createState() => _SaleDetailScreenState();
}

class _SaleDetailScreenState extends State<SaleDetailScreen> {
  late SaleRecord _currentSale;
  bool _isSubmitting = false;
  final LhdnSubmissionService _lhdnService = LhdnSubmissionService();
  final FirestoreService _firestoreService = FirestoreService();

  @override
  void initState() {
    super.initState();
    _currentSale = widget.sale;
  }

  // ── LHDN Submission ────────────────────────────────────────────────────

  Future<void> _submitToLhdn() async {
    // Fetch the seller's business profile
    final profile = await _getSellerProfile();
    if (profile == null) {
      if (!mounted) return;
      AppDialogs.showActionModal(
        context,
        title: 'Profile Required',
        body: 'Please complete your Business Profile before submitting e-Invoices. '
            'Your TIN, BRN, and business address are required by LHDN.',
        primaryButtonText: 'OK',
        onPrimaryPressed: () {},
        icon: Icons.business_rounded,
        iconColor: AppTheme.primary,
        primaryButtonColor: AppTheme.primary,
      );
      return;
    }

    // Confirm submission
    AppDialogs.showActionModal(
      context,
      // TODO: Implement i18n
      title: 'Confirm & Submit?',
      body: 'This will submit invoice ${_currentSale.invoiceNumber} to LHDN for validation and mark it as Paid.\n\n'
          'Amount: RM ${_currentSale.totalPayable.toStringAsFixed(2)}\n'
          'Customer: ${_currentSale.customerName}',
      primaryButtonText: 'Confirm & Submit',
      primaryButtonColor: AppTheme.primary,
      onPrimaryPressed: () => _performSubmission(profile),
      secondaryButtonText: 'Cancel',
      icon: Icons.send_rounded,
      iconColor: AppTheme.primary,
    );
  }

  Future<void> _performSubmission(BusinessProfile profile) async {
    setState(() => _isSubmitting = true);

    final result = await _lhdnService.submitInvoice(
      record: _currentSale,
      sellerProfile: profile,
    );

    if (!mounted) return;
    setState(() => _isSubmitting = false);

    if (result.success) {
      // Update local state
      setState(() {
        _currentSale = _currentSale.copyWith(
          lhdnUuid: result.uuid,
          lhdnLongId: result.longId,
          lhdnValidatedAt: result.validatedAt,
          complianceStatus: ComplianceStatus.valid,
          commercialStatus: CommercialStatus.paid,
        );
      });

      final theme = Theme.of(context);
      // TODO: Implement i18n
      AppDialogs.showActionModal(
        context,
        title: 'e-Invoice Validated ✓',
        body: 'LHDN has accepted your invoice.\n\n'
            'UUID: ${result.uuid}\n'
            'Long ID: ${result.longId}',
        primaryButtonText: 'Copy UUID',
        primaryButtonColor: theme.brightness == Brightness.dark
            ? AppTheme.neonGreenDark
            : AppTheme.neonGreenLight,
        onPrimaryPressed: () {
          Clipboard.setData(ClipboardData(text: result.uuid ?? ''));
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('UUID copied to clipboard')),
            );
          }
        },
        secondaryButtonText: 'Done',
        icon: Icons.verified_rounded,
        iconColor: theme.brightness == Brightness.dark
            ? AppTheme.neonGreenDark
            : AppTheme.neonGreenLight,
      );
    } else {
      // TODO: Implement i18n
      AppDialogs.showActionModal(
        context,
        title: 'Submission Failed',
        body: result.errorMessage ?? 'Unknown error occurred.',
        primaryButtonText: 'Retry',
        primaryButtonColor: Colors.redAccent,
        onPrimaryPressed: () => _performSubmission(profile),
        secondaryButtonText: 'Cancel',
        icon: Icons.error_outline_rounded,
        iconColor: Colors.redAccent,
      );
    }
  }

  Future<BusinessProfile?> _getSellerProfile() async {
    try {
      final userId = FirebaseAuth.instance.currentUser?.uid;
      if (userId == null) return null;
      return await _firestoreService.getBusinessProfile(userId);
    } catch (e) {
      debugPrint('Failed to load profile: $e');
      return null;
    }
  }

  // ── JSON Preview ───────────────────────────────────────────────────────

  Future<void> _showJsonPreview() async {
    final profile = await _getSellerProfile();
    if (profile == null) {
      if (!mounted) return;
      // TODO: Implement i18n
      AppDialogs.showActionModal(
        context,
        title: 'Profile Required',
        body: 'Complete your Business Profile first.',
        primaryButtonText: 'OK',
        onPrimaryPressed: () {},
        icon: Icons.info_outline_rounded,
        iconColor: AppTheme.primary,
        primaryButtonColor: AppTheme.primary,
      );
      return;
    }

    final jsonString = _lhdnService.generatePreviewString(
      record: _currentSale,
      sellerProfile: profile,
    );

    if (!mounted) return;
    final theme = Theme.of(context);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: theme.colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(AppTheme.radiusXLarge),
        ),
      ),
      builder: (ctx) {
        return DraggableScrollableSheet(
          initialChildSize: 0.8,
          minChildSize: 0.4,
          maxChildSize: 0.95,
          expand: false,
          builder: (_, controller) {
            return Column(
              children: [
                // Drag handle
                Padding(
                  padding: const EdgeInsets.only(top: 12),
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: theme.colorScheme.onSurfaceVariant
                          .withValues(alpha: 0.3),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      // TODO: Implement i18n
                      Text(
                        'UBL 2.1 JSON Preview',
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.copy_rounded),
                        tooltip: 'Copy to Clipboard',
                        onPressed: () {
                          Clipboard.setData(ClipboardData(text: jsonString));
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('JSON copied to clipboard'),
                            ),
                          );
                          Navigator.pop(ctx);
                        },
                      ),
                    ],
                  ),
                ),
                const Divider(height: 1),
                Expanded(
                  child: SingleChildScrollView(
                    controller: controller,
                    padding: const EdgeInsets.all(16),
                    child: SelectableText(
                      jsonString,
                      style: theme.textTheme.bodySmall?.copyWith(
                        fontFamily: 'monospace',
                        fontSize: 11,
                        height: 1.5,
                        color: theme.colorScheme.onSurface,
                      ),
                    ),
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  // ── Delete ─────────────────────────────────────────────────────────────

  void _deleteSale() {
    // TODO: Implement i18n
    AppDialogs.showActionModal(
      context,
      title: 'Delete Sale Record',
      body:
          'Are you sure you want to delete invoice ${_currentSale.invoiceNumber}? '
          'This action cannot be undone.',
      primaryButtonText: 'Delete',
      primaryButtonColor: Colors.redAccent,
      icon: Icons.warning_rounded,
      iconColor: Colors.redAccent,
      onPrimaryPressed: () async {
        try {
          await context.read<SalesProvider>().deleteSaleRecord(_currentSale.id);
          if (mounted) Navigator.pop(context);
        } catch (e) {
          if (mounted) {
            AppDialogs.showActionModal(
              context,
              title: 'Delete Failed',
              body: 'Error: $e',
              primaryButtonText: 'OK',
              onPrimaryPressed: () {},
              icon: Icons.error_outline_rounded,
              iconColor: Colors.redAccent,
              primaryButtonColor: Colors.redAccent,
            );
          }
        }
      },
      secondaryButtonText: 'Cancel',
    );
  }


  // ── UI Detail Card Builder ─────────────────────────────────────────────

  Widget _buildDetailCard(
    ThemeData theme, {
    required IconData icon,
    required String label,
    required String value,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color:
            theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(AppTheme.radiusLarge),
        border: Border.all(
          color: theme.colorScheme.outlineVariant.withValues(alpha: 0.5),
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: theme.colorScheme.onSurface.withValues(alpha: 0.05),
              borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
            ),
            child: Icon(icon,
                size: 20, color: theme.colorScheme.onSurfaceVariant),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  value,
                  style: theme.textTheme.bodyLarge?.copyWith(
                    fontWeight: FontWeight.w700,
                    letterSpacing: -0.2,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── Build ──────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final dateStr = DateFormat('dd MMM yyyy').format(_currentSale.saleDate);
    final timeStr = DateFormat('hh:mm a').format(_currentSale.saleDate);

    // Compliance status theming
    final statusColor = switch (_currentSale.complianceStatus) {
      ComplianceStatus.valid => theme.brightness == Brightness.dark
          ? AppTheme.neonGreenDark
          : AppTheme.neonGreenLight,
      ComplianceStatus.invalid => Colors.redAccent,
      ComplianceStatus.pendingSubmission => Colors.orange,
      ComplianceStatus.pendingConsolidation =>
        theme.colorScheme.onSurfaceVariant,
    };

    // Payment status theming
    final paymentColor = switch (_currentSale.commercialStatus) {
      CommercialStatus.paid => theme.brightness == Brightness.dark
          ? AppTheme.neonGreenDark
          : AppTheme.neonGreenLight,
      CommercialStatus.pendingPayment => Colors.orange,
    };

    return Scaffold(
      appBar: AppBar(
        title: Text(
          // TODO: Implement i18n
          'Invoice Details',
          style: TextStyle(
            color: theme.colorScheme.primary,
            fontWeight: FontWeight.w700,
          ),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          if (_currentSale.consolidatedInvoiceRef == null && _currentSale.lastGeneratedPayload != null)
            IconButton(
              icon: const Icon(Icons.code_rounded, size: 22),
              onPressed: _showJsonPreview,
              tooltip: 'View JSON',
            ),
          IconButton(
            icon: const Icon(Icons.delete_outline_rounded,
                color: Colors.redAccent, size: 22),
            onPressed: _deleteSale,
            tooltip: 'Delete',
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Hero Amount Card ───────────────────────────────────────
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 32),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    AppTheme.primary.withValues(alpha: 0.12),
                    AppTheme.primary.withValues(alpha: 0.04),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius:
                    BorderRadius.circular(AppTheme.radiusLarge * 2),
                border: Border.all(
                  color: AppTheme.primary.withValues(alpha: 0.25),
                  width: 1.5,
                ),
              ),
              child: Column(
                children: [
                  // Invoice number badge
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color:
                          theme.colorScheme.surface.withValues(alpha: 0.7),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: AppTheme.primary.withValues(alpha: 0.3),
                      ),
                    ),
                    child: Text(
                      _currentSale.invoiceNumber,
                      style: theme.textTheme.labelLarge?.copyWith(
                        color: AppTheme.primary,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 1.2,
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  // Amount
                  Text(
                    'RM ${_currentSale.totalPayable.toStringAsFixed(2)}',
                    style: theme.textTheme.displayMedium?.copyWith(
                      fontWeight: FontWeight.w900,
                      color: theme.colorScheme.onSurface,
                      letterSpacing: -1.0,
                    ),
                  ),
                  const SizedBox(height: 20),
                  // Status chips row
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      _buildStatusChip(
                        theme,
                        label: _currentSale.complianceStatus.label,
                        color: statusColor,
                        icon: _currentSale.complianceStatus ==
                                ComplianceStatus.valid
                            ? Icons.verified_rounded
                            : Icons.pending_rounded,
                      ),
                      const SizedBox(width: 8),
                      _buildStatusChip(
                        theme,
                        label: _currentSale.commercialStatus.label,
                        color: paymentColor,
                        icon: _currentSale.commercialStatus ==
                                CommercialStatus.paid
                            ? Icons.check_circle_rounded
                            : Icons.schedule_rounded,
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 32),

            // ── LHDN Submission Button ────────────────────────────────
            if (_currentSale.complianceStatus != ComplianceStatus.valid &&
                _currentSale.complianceStatus != ComplianceStatus.pendingConsolidation)
              Padding(
                padding: const EdgeInsets.only(bottom: 24),
                child: AppButton(
                  // TODO: Implement i18n
                  text: _isSubmitting
                      ? 'Submitting to LHDN...'
                      : 'Confirm & Submit e-Invoice to LHDN',
                  icon: _isSubmitting
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Icon(Icons.send_rounded,
                          size: 20, color: Colors.white),
                  onPressed: _isSubmitting ? null : _submitToLhdn,
                ),
              ),

            // ── LHDN Response Section ─────────────────────────────────
            if (_currentSale.consolidatedInvoiceRef != null) ...[
              Container(
                padding: const EdgeInsets.all(16),
                margin: const EdgeInsets.only(bottom: 24),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.errorContainer.withValues(alpha: 0.5),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Theme.of(context).colorScheme.error.withValues(alpha: 0.5)),
                ),
                child: Row(
                  children: [
                    Icon(Icons.info_outline_rounded, color: Theme.of(context).colorScheme.error),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'This receipt was consolidated under Master Invoice:\n${_currentSale.consolidatedInvoiceRef}\n\nIndividual payload generation is disabled.',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: Theme.of(context).colorScheme.onErrorContainer,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ] else if (_currentSale.lhdnUuid != null) ...[
              // TODO: Implement i18n
              _buildSectionHeader(theme, 'LHDN Validation'),
              const SizedBox(height: 12),
              _buildDetailCard(
                theme,
                icon: Icons.fingerprint_rounded,
                label: 'UUID',
                value: _currentSale.lhdnUuid!,
              ),
              if (_currentSale.lhdnLongId != null)
                _buildDetailCard(
                  theme,
                  icon: Icons.key_rounded,
                  label: 'Long ID',
                  value: _currentSale.lhdnLongId!,
                ),
              if (_currentSale.lhdnValidatedAt != null)
                _buildDetailCard(
                  theme,
                  icon: Icons.access_time_rounded,
                  label: 'Validated At',
                  value: DateFormat('dd MMM yyyy, hh:mm a')
                      .format(_currentSale.lhdnValidatedAt!),
                ),
              const SizedBox(height: 24),
            ],

            // ── Transaction Info ──────────────────────────────────────
            // TODO: Implement i18n
            _buildSectionHeader(theme, 'Transaction Info'),
            const SizedBox(height: 12),
            _buildDetailCard(theme,
                icon: Icons.calendar_today_rounded,
                label: 'Date',
                value: '$dateStr at $timeStr'),
            _buildDetailCard(theme,
                icon: Icons.person_outline_rounded,
                label: 'Customer',
                value: _currentSale.customerName),
            _buildDetailCard(theme,
                icon: Icons.badge_outlined,
                label: 'Customer Type',
                value: _currentSale.customerType == CustomerType.b2b
                    ? 'Business (B2B)'
                    : 'Consumer (B2C)'),
            _buildDetailCard(theme,
                icon: Icons.payment_rounded,
                label: 'Payment Method',
                value:
                    LhdnConstants.paymentModes[_currentSale.paymentMode] ??
                        _currentSale.paymentMode ?? '01'),
            if (_currentSale.paymentTerms != null && _currentSale.paymentTerms!.isNotEmpty)
              _buildDetailCard(theme,
                  icon: Icons.handshake_rounded,
                  label: 'Payment Terms',
                  value: _currentSale.paymentTerms!),
            if (_currentSale.supplierBankAccount != null && _currentSale.supplierBankAccount!.isNotEmpty)
              _buildDetailCard(theme,
                  icon: Icons.account_balance_rounded,
                  label: 'Supplier Bank Account',
                  value: _currentSale.supplierBankAccount!),
            if (_currentSale.billReference != null && _currentSale.billReference!.isNotEmpty)
              _buildDetailCard(theme,
                  icon: Icons.receipt_long_rounded,
                  label: 'Bill Reference',
                  value: _currentSale.billReference!),
            
            // Prepayment Details
            if ((_currentSale.prepaymentAmount ?? 0) > 0) ...[
              const SizedBox(height: 12),
              _buildSectionHeader(theme, 'Prepayment Details'),
              const SizedBox(height: 12),
              _buildDetailCard(theme,
                  icon: Icons.payments_rounded,
                  label: 'Prepayment Amount',
                  value: 'RM ${_currentSale.prepaymentAmount!.toStringAsFixed(2)}'),
              if (_currentSale.prepaymentDate != null)
                _buildDetailCard(theme,
                    icon: Icons.event_available_rounded,
                    label: 'Prepayment Date',
                    value: DateFormat('dd MMM yyyy').format(_currentSale.prepaymentDate!)),
              if (_currentSale.prepaymentReference != null && _currentSale.prepaymentReference!.isNotEmpty)
                _buildDetailCard(theme,
                    icon: Icons.tag_rounded,
                    label: 'Prepayment Reference',
                    value: _currentSale.prepaymentReference!),
            ],

            // Billing
            if (_currentSale.billingFrequency != null || _currentSale.billingStartDate != null) ...[
              const SizedBox(height: 12),
              _buildSectionHeader(theme, 'Billing'),
              const SizedBox(height: 12),
              if (_currentSale.billingFrequency != null && _currentSale.billingFrequency!.isNotEmpty)
                _buildDetailCard(theme,
                    icon: Icons.update_rounded,
                    label: 'Billing Frequency',
                    value: _currentSale.billingFrequency!),
              if (_currentSale.billingStartDate != null && _currentSale.billingEndDate != null)
                _buildDetailCard(theme,
                    icon: Icons.date_range_rounded,
                    label: 'Billing Period',
                    value: '${DateFormat('dd MMM yyyy').format(_currentSale.billingStartDate!)} - ${DateFormat('dd MMM yyyy').format(_currentSale.billingEndDate!)}'),
            ],

            const SizedBox(height: 24),

            // TODO: Implement i18n
            _buildSectionHeader(theme, 'Item Breakdown'),
            const SizedBox(height: 12),
            ..._currentSale.lineItems.map((line) => Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  child: _buildDetailCard(theme,
                      icon: Icons.inventory_2_outlined,
                      label: line.item.name,
                      value: '${line.quantity.toStringAsFixed(line.quantity == line.quantity.roundToDouble() ? 0 : 2)} ${line.item.measurementUnit} × RM ${line.unitPrice.toStringAsFixed(2)}'),
                )),
            const SizedBox(height: 24),

            // ── Pricing Breakdown ─────────────────────────────────────
            // TODO: Implement i18n
            _buildSectionHeader(theme, 'Pricing'),
            const SizedBox(height: 12),
            _buildPricingRow(theme, 'Subtotal',
                'RM ${_currentSale.subtotal.toStringAsFixed(2)}'),
            if ((_currentSale.discountAmount ?? 0) > 0)
              _buildPricingRow(
                  theme,
                  (_currentSale.discountRate ?? 0) > 0
                      ? 'Discount (${(_currentSale.discountRate ?? 0).toStringAsFixed(0)}%)'
                      : 'Discount',
                  '- RM ${(_currentSale.discountAmount ?? 0).toStringAsFixed(2)}',
                  isNegative: true),
            if ((_currentSale.feeAmount ?? 0) > 0)
              _buildPricingRow(
                  theme,
                  (_currentSale.feeRate ?? 0) > 0
                      ? 'Fee/Charge (${(_currentSale.feeRate ?? 0).toStringAsFixed(0)}%)'
                      : 'Fee/Charge',
                  '+ RM ${(_currentSale.feeAmount ?? 0).toStringAsFixed(2)}'),
            _buildPricingRow(theme, 'Tax (${_currentSale.taxRate.toStringAsFixed(0)}%)',
                'RM ${_currentSale.taxAmount.toStringAsFixed(2)}'),
            if (_currentSale.roundingAmount != 0)
              _buildPricingRow(
                theme,
                'Rounding (5-sen)',
                '${_currentSale.roundingAmount >= 0 ? '+' : ''}RM ${_currentSale.roundingAmount.toStringAsFixed(2)}',
              ),
            const Divider(height: 24),
            _buildPricingRow(theme, 'Total Payable',
                'RM ${_currentSale.totalPayable.toStringAsFixed(2)}',
                isBold: true),
            const SizedBox(height: 24),

            // ── Notes ─────────────────────────────────────────────────
            if (_currentSale.notes.isNotEmpty) ...[
              _buildDetailCard(theme,
                  icon: Icons.notes_rounded,
                  label: 'Notes',
                  value: _currentSale.notes),
              const SizedBox(height: 24),
            ],

            // ── Bottom Actions ────────────────────────────────────────
            AppButton(
              // TODO: Implement i18n
              text: 'Export to CSV',
              icon: const Icon(Icons.download_rounded, size: 20),
              onPressed: () async => await CsvExportService.exportSingleSaleToCSV(context, _currentSale),
            ),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  // ── Helper Widgets ─────────────────────────────────────────────────────

  Widget _buildSectionHeader(ThemeData theme, String title) {
    return Text(
      title,
      style: theme.textTheme.titleLarge?.copyWith(
        fontWeight: FontWeight.w800,
        letterSpacing: -0.5,
      ),
    );
  }

  Widget _buildStatusChip(
    ThemeData theme, {
    required String label,
    required Color color,
    required IconData icon,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 6),
          Text(
            label,
            style: theme.textTheme.labelSmall?.copyWith(
              color: color,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPricingRow(
    ThemeData theme,
    String label,
    String value, {
    bool isBold = false,
    bool isNegative = false,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: theme.textTheme.bodyMedium?.copyWith(
              fontWeight: isBold ? FontWeight.w800 : FontWeight.w500,
              color: isBold
                  ? theme.colorScheme.onSurface
                  : theme.colorScheme.onSurfaceVariant,
            ),
          ),
          Text(
            value,
            style: theme.textTheme.bodyMedium?.copyWith(
              fontWeight: isBold ? FontWeight.w800 : FontWeight.w600,
              color: isNegative
                  ? Colors.redAccent
                  : isBold
                      ? AppTheme.primary
                      : theme.colorScheme.onSurface,
            ),
          ),
        ],
      ),
    );
  }
}
