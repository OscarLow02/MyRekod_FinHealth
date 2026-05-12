import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:share_plus/share_plus.dart';
import 'package:intl/intl.dart';
import '../core/app_theme.dart';
import '../core/lhdn_constants.dart';
import '../models/sale_record.dart';
import '../models/business_profile.dart';

/// Centralized utility for presenting MyRekod "Interruption Architecture" popups.
class AppDialogs {
  AppDialogs._();

  // ───────────────────────────────────────────────────────────────────────────
  // 1. ACTION MODALS (Center)
  // Covers: Delete Record, Cancel Submission, Log Out, Camera Permission, Offline Mode
  // ───────────────────────────────────────────────────────────────────────────
  static Future<void> showActionModal(
    BuildContext context, {
    required String title,
    required String body,
    required String primaryButtonText,
    required VoidCallback onPrimaryPressed,
    String? secondaryButtonText,
    VoidCallback? onSecondaryPressed,
    IconData icon = Icons.warning_amber_rounded,
    Color? iconColor,
    Color? primaryButtonColor,
    Widget? customFooter, // e.g., small text like "Auto-sync enabled"
  }) {
    final theme = Theme.of(context);
    final activeIconColor = iconColor ?? Colors.redAccent;
    final activeBtnColor = primaryButtonColor ?? Colors.redAccent;

    return showDialog<void>(
      context: context,
      barrierDismissible: false, // Core requirement: Must explicitly dismiss/action
      builder: (ctx) {
        return Dialog(
          backgroundColor: theme.colorScheme.surface,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppTheme.radiusXLarge),
          ),
          elevation: 24,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 32.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                // Glowing Icon
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: activeIconColor.withValues(alpha: 0.15),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    icon,
                    size: 32,
                    color: activeIconColor,
                  ),
                ),
                const SizedBox(height: 24),
                // Title
                Text(
                  title,
                  textAlign: TextAlign.center,
                  style: theme.textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 12),
                // Body Text
                Text(
                  body,
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                    height: 1.5,
                  ),
                ),
                const SizedBox(height: 32),
                // Primary Action
                ElevatedButton(
                  onPressed: () {
                    Navigator.of(ctx).pop(); // Auto dismiss
                    onPrimaryPressed();
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: activeBtnColor,
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(primaryButtonText),
                    ],
                  ),
                ),
                // Secondary Action (Optional)
                if (secondaryButtonText != null) ...[
                  const SizedBox(height: 12),
                  OutlinedButton(
                    onPressed: () {
                      Navigator.of(ctx).pop();
                      if (onSecondaryPressed != null) {
                        onSecondaryPressed();
                      }
                    },
                    style: OutlinedButton.styleFrom(
                      side: BorderSide(
                        color: theme.colorScheme.surfaceContainerHighest,
                      ),
                    ),
                    child: Text(
                      secondaryButtonText,
                      style: theme.textTheme.labelLarge?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                ],
                // Custom subtle footer (like "Secure Permission")
                if (customFooter != null) ...[
                  const SizedBox(height: 24),
                  customFooter,
                ],
              ],
            ),
          ),
        );
      },
    );
  }

  /// ───────────────────────────────────────────────────────────────────────────
  /// 1a. SYSTEM ALERT (Center)
  /// For: Success messages, informative alerts (e.g., "Settings Saved")
  /// ───────────────────────────────────────────────────────────────────────────
  static Future<void> showSystemAlert(
    BuildContext context, {
    required String title,
    String? body,
    IconData icon = Icons.check_circle_rounded,
    Color? iconColor,
    String primaryButtonText = 'OK',
  }) {
    final theme = Theme.of(context);
    final activeIconColor = iconColor ?? AppTheme.neonGreenDark;

    return showDialog<void>(
      context: context,
      barrierDismissible: true,
      builder: (ctx) {
        return Dialog(
          backgroundColor: theme.colorScheme.surface,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppTheme.radiusXLarge),
          ),
          elevation: 24,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 32.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                // Success Icon
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: activeIconColor.withValues(alpha: 0.15),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    icon,
                    size: 40,
                    color: activeIconColor,
                  ),
                ),
                const SizedBox(height: 24),
                // Title
                Text(
                  title,
                  textAlign: TextAlign.center,
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                if (body != null) ...[
                  const SizedBox(height: 12),
                  Text(
                    body,
                    textAlign: TextAlign.center,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                      height: 1.5,
                    ),
                  ),
                ],
                const SizedBox(height: 32),
                // Dismiss Action
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () => Navigator.of(ctx).pop(),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: activeIconColor,
                    ),
                    child: Text(primaryButtonText),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  /// ───────────────────────────────────────────────────────────────────────────
  /// 1b. FORM MODAL (Center)
  /// For: Reset Password, Change Display Name, etc.
  /// ───────────────────────────────────────────────────────────────────────────
  /// Shows a form-based dialog.
  /// [onPrimaryPressed] is an async callback. Return `true` to confirm and
  /// dismiss the dialog, or `false` / throw to keep it open (e.g. validation
  /// failed).
  static Future<bool> showFormModal(
    BuildContext context, {
    required String title,
    required Widget formBody,
    required String primaryButtonText,
    required Future<bool> Function() onPrimaryPressed,
    String? secondaryButtonText,
    VoidCallback? onSecondaryPressed,
    IconData icon = Icons.edit_rounded,
    Color? iconColor,
  }) async {
    final theme = Theme.of(context);
    final activeIconColor = iconColor ?? AppTheme.primary;

    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        bool isBusy = false;
        return StatefulBuilder(
          builder: (ctx, setDialogState) {
            return Dialog(
              backgroundColor: theme.colorScheme.surface,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppTheme.radiusXLarge),
              ),
              elevation: 24,
              child: SingleChildScrollView(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 32.0),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      // Glowing Icon
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: activeIconColor.withValues(alpha: 0.15),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(icon, size: 32, color: activeIconColor),
                      ),
                      const SizedBox(height: 24),
                      // Title
                      Text(
                        title,
                        textAlign: TextAlign.center,
                        style: theme.textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 24),
                      // Form Content
                      formBody,
                      const SizedBox(height: 32),
                      // Primary Action
                      ElevatedButton(
                        onPressed: isBusy
                            ? null
                            : () async {
                                setDialogState(() => isBusy = true);
                                try {
                                  final shouldClose = await onPrimaryPressed();
                                  if (shouldClose && ctx.mounted) {
                                    Navigator.of(ctx).pop(true);
                                  }
                                } finally {
                                  if (ctx.mounted) {
                                    setDialogState(() => isBusy = false);
                                  }
                                }
                              },
                        child: isBusy
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : Text(primaryButtonText),
                      ),
                      if (secondaryButtonText != null) ...[
                        const SizedBox(height: 12),
                        OutlinedButton(
                          onPressed: isBusy
                              ? null
                              : () {
                                  Navigator.of(ctx).pop(false);
                                  if (onSecondaryPressed != null) onSecondaryPressed();
                                },
                          style: OutlinedButton.styleFrom(
                            side: BorderSide(
                              color: theme.colorScheme.surfaceContainerHighest,
                            ),
                          ),
                          child: Text(
                            secondaryButtonText,
                            style: theme.textTheme.labelLarge?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
    return result ?? false;
  }

  // ───────────────────────────────────────────────────────────────────────────
  // BOTTOM SHEET HELPER
  // ───────────────────────────────────────────────────────────────────────────
  static Future<void> _showBaseSheet(
    BuildContext context, {
    required Widget child,
    bool isDismissible = true,
  }) {
    final theme = Theme.of(context);
    return showModalBottomSheet(
      context: context,
      isDismissible: isDismissible,
      isScrollControlled: true, // allow height dynamically
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return Container(
          margin: const EdgeInsets.only(top: 64),
          decoration: BoxDecoration(
            color: theme.colorScheme.surface,
            borderRadius: const BorderRadius.vertical(
              top: Radius.circular(AppTheme.radiusXLarge),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.5),
                blurRadius: 24,
                offset: const Offset(0, -4),
              ),
            ],
          ),
          child: SafeArea(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Top drag handle
                const SizedBox(height: 12),
                Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: theme.colorScheme.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(height: 16),
                child,
              ],
            ),
          ),
        );
      },
    );
  }

  // ───────────────────────────────────────────────────────────────────────────
  // 2. EXIT INTENT SHEET (Bottom)
  // Covers: Unsaved Draft
  // ───────────────────────────────────────────────────────────────────────────
  static Future<void> showExitIntentSheet(
    BuildContext context, {
    required String title,
    required String body,
    required String primaryButtonText,
    required VoidCallback onPrimaryPressed,
    required String secondaryButtonText,
    required VoidCallback onSecondaryPressed,
  }) {
    final theme = Theme.of(context);
    return _showBaseSheet(
      context,
      isDismissible: true,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 8, 24, 32),
        child: Column(
          children: [
            // Floating danger Icon
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.redAccent.withValues(alpha: 0.15),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.warning_rounded, color: Colors.redAccent, size: 28),
            ),
            const SizedBox(height: 24),
            Text(
              title,
              textAlign: TextAlign.center,
              style: theme.textTheme.headlineMedium?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              body,
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyLarge?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 32),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(context);
                onPrimaryPressed();
              },
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.edit_rounded, size: 18),
                  const SizedBox(width: 8),
                  Text(primaryButtonText),
                ],
              ),
            ),
            const SizedBox(height: 12),
            OutlinedButton(
              onPressed: () {
                Navigator.pop(context);
                onSecondaryPressed();
              },
              style: OutlinedButton.styleFrom(
                side: BorderSide(
                  color: theme.colorScheme.surfaceContainerHighest,
                ),
              ),
              child: Text(
                secondaryButtonText,
                style: theme.textTheme.labelLarge?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ───────────────────────────────────────────────────────────────────────────
  // 3. TRANSACTION REVIEW SHEET (Bottom)
  // Covers: Review Sale (LHDN), Review Expense (OCR)
  // ───────────────────────────────────────────────────────────────────────────
  static Future<void> showTransactionReviewSheet(
    BuildContext context, {
    required String title,
    required Widget overviewCard, // Custom payload view mapping
    required String primaryButtonText,
    required VoidCallback onPrimaryPressed,
    IconData primaryIcon = Icons.document_scanner_rounded,
    String? secondaryButtonText,
    VoidCallback? onSecondaryPressed,
    Widget? footer,
  }) {
    final theme = Theme.of(context);
    return _showBaseSheet(
      context,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 0, 24, 32),
        child: Column(
          children: [
            // Header Row with optional close button
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Row(
                    children: [
                      // Sub-icon for Review
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: AppTheme.primary.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(AppTheme.radiusSmall),
                        ),
                        child: Icon(primaryIcon, size: 20, color: AppTheme.primary),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          title,
                          style: theme.textTheme.titleLarge,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close_rounded, size: 20),
                  style: IconButton.styleFrom(
                    backgroundColor: theme.colorScheme.surfaceContainerHighest,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            
            // The mapping representation
            overviewCard,
            
            if (footer != null) ...[
              const SizedBox(height: 16),
              footer,
            ],
            
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(context);
                onPrimaryPressed();
              },
              child: Text(primaryButtonText),
            ),
            if (secondaryButtonText != null) ...[
              const SizedBox(height: 16),
              GestureDetector(
                onTap: () {
                  Navigator.pop(context);
                  if (onSecondaryPressed != null) onSecondaryPressed();
                },
                child: Text(
                  secondaryButtonText,
                  style: theme.textTheme.labelMedium?.copyWith(
                     color: theme.colorScheme.onSurfaceVariant,
                     fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  // ───────────────────────────────────────────────────────────────────────────
  // 4. FEATURE DISCOVERY / GAMIFICATION SHEET (Bottom)
  // Covers: Streak Achieved, Health Score, Discover OCR, Discover Analytics
  // ───────────────────────────────────────────────────────────────────────────
  static Future<void> showFeatureDiscoverySheet(
    BuildContext context, {
    required String title,
    required String body,
    required String primaryButtonText,
    required VoidCallback onPrimaryPressed,
    required IconData heroIcon,
    Color? heroColor,
    String? secondaryButtonText,
    VoidCallback? onSecondaryPressed,
    Widget? customHeroContent, // E.g. "842" large score number 
  }) {
    final theme = Theme.of(context);
    final color = heroColor ?? AppTheme.primaryContainer;
    
    return _showBaseSheet(
      context,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 8, 24, 32),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // Big Hero Container
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 40),
              decoration: BoxDecoration(
                color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(AppTheme.radiusLarge),
                border: Border.all(
                  color: color.withValues(alpha: 0.1),
                ),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    width: 100,
                    height: 100,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: color.withValues(alpha: 0.2),
                      boxShadow: [
                        BoxShadow(
                          color: color.withValues(alpha: 0.4),
                          blurRadius: 40,
                          spreadRadius: 10,
                        ),
                      ],
                    ),
                    child: Icon(
                      heroIcon,
                      size: 48,
                      color: Colors.white,
                    ),
                  ),
                  if (customHeroContent != null) ...[
                    const SizedBox(height: 24),
                    customHeroContent,
                  ]
                ],
              ),
            ),
            const SizedBox(height: 32),
            Text(
              title,
              textAlign: TextAlign.center,
              style: theme.textTheme.headlineMedium?.copyWith(
                fontWeight: FontWeight.w800,
                letterSpacing: -0.5,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              body,
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyLarge?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 32),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(context);
                onPrimaryPressed();
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: color,
              ),
              child: Text(primaryButtonText),
            ),
            if (secondaryButtonText != null) ...[
              const SizedBox(height: 16),
              GestureDetector(
                onTap: () {
                  Navigator.pop(context);
                  if (onSecondaryPressed != null) onSecondaryPressed();
                },
                child: Text(
                  secondaryButtonText,
                  style: theme.textTheme.labelMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
            ]
          ],
        ),
      ),
    );
  }

  // ───────────────────────────────────────────────────────────────────────────
  // 5. NEW ENTRY MODAL (Bottom Sheet)
  // Covers: Record Sale, Record Expense
  // ───────────────────────────────────────────────────────────────────────────
  static Future<void> showNewEntryModal(
    BuildContext context, {
    required VoidCallback onRecordSale,
    required VoidCallback onRecordExpense,
  }) {
    final theme = Theme.of(context);
    return _showBaseSheet(
      context,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 8, 24, 32),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              // TODO: Implement i18n
              'New Entry',
              style: theme.textTheme.headlineMedium?.copyWith(
                fontWeight: FontWeight.w800,
                letterSpacing: -0.5,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              // TODO: Implement i18n
              'What would you like to record?',
              style: theme.textTheme.bodyLarge?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 32),
            IntrinsicHeight(
              child: Row(
                children: [
                  Expanded(
                    child: _buildEntryOption(
                      context,
                      title: 'Record Sale',
                      subtitle: 'Manual entry or e-Invoice',
                      icon: Icons.point_of_sale_rounded,
                      color: AppTheme.primary,
                      gradientColors: [
                        AppTheme.primary.withValues(alpha: 0.15),
                        AppTheme.primary.withValues(alpha: 0.05),
                      ],
                      onTap: () {
                        Navigator.pop(context);
                        onRecordSale();
                      },
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: _buildEntryOption(
                      context,
                      title: 'Record Expense',
                      subtitle: 'Scan receipt or manual',
                      icon: Icons.receipt_long_rounded,
                      color: Colors.orange.shade700,
                      gradientColors: [
                        Colors.orange.shade700.withValues(alpha: 0.15),
                        Colors.orange.shade700.withValues(alpha: 0.05),
                      ],
                      onTap: () {
                        Navigator.pop(context);
                        onRecordExpense();
                      },
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  static Widget _buildEntryOption(
    BuildContext context, {
    required String title,
    required String subtitle,
    required IconData icon,
    required Color color,
    required List<Color> gradientColors,
    required VoidCallback onTap,
  }) {
    final theme = Theme.of(context);
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: double.infinity,
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: gradientColors,
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(AppTheme.radiusXLarge),
          border: Border.all(
            color: color.withValues(alpha: 0.3),
            width: 1.5,
          ),
          boxShadow: [
            BoxShadow(
              color: color.withValues(alpha: 0.05),
              blurRadius: 15,
              spreadRadius: -5,
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: theme.colorScheme.surface,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: color.withValues(alpha: 0.2),
                    blurRadius: 8,
                    spreadRadius: 1,
                  ),
                ],
              ),
              child: Icon(icon, color: color, size: 32),
            ),
            const SizedBox(height: 32),
            Text(
              title,
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              subtitle,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
                height: 1.3,
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Generates a plaintext receipt for sharing via WhatsApp/SMS.
  static String generateReceiptText(SaleRecord sale, BusinessProfile profile) {
    final dateFormat = DateFormat('dd MMM yyyy, hh:mm a');
    final currencyFormat = NumberFormat.currency(symbol: 'RM ', decimalDigits: 2);
    
    final StringBuffer buffer = StringBuffer();
    buffer.writeln('🧾 RECEIPT');
    buffer.writeln('Business: ${profile.businessName}');
    buffer.writeln('Invoice No: ${sale.invoiceNumber}');
    buffer.writeln('Date: ${dateFormat.format(sale.saleDate)}');
    buffer.writeln('------------------------');
    
    for (final item in sale.lineItems) {
      final qty = item.quantity % 1 == 0 ? item.quantity.toInt().toString() : item.quantity.toString();
      buffer.writeln('${item.item.name} x $qty = ${currencyFormat.format(item.subtotal)}');
    }
    
    buffer.writeln('------------------------');
    buffer.writeln('Subtotal: ${currencyFormat.format(sale.subtotal)}');
    
    if (sale.discountAmount != null && sale.discountAmount! > 0) {
      buffer.writeln('Discount: -${currencyFormat.format(sale.discountAmount)}');
    }

    if (sale.feeAmount != null && sale.feeAmount! > 0) {
      buffer.writeln('Fees/Charges: ${currencyFormat.format(sale.feeAmount)}');
    }

    if (sale.taxAmount > 0) {
      buffer.writeln('Tax (${sale.taxRate}%): ${currencyFormat.format(sale.taxAmount)}');
    }

    if (sale.roundingAmount != 0) {
      buffer.writeln('Rounding: ${currencyFormat.format(sale.roundingAmount)}');
    }

    buffer.writeln('------------------------');
    buffer.writeln('TOTAL: ${currencyFormat.format(sale.totalPayable)}');
    
    if (sale.paymentMode != null) {
      final mode = LhdnConstants.paymentModes[sale.paymentMode] ?? sale.paymentMode;
      buffer.writeln('Payment: $mode');
    }
    
    buffer.writeln('------------------------');
    buffer.writeln('Thank you for your purchase!');
    
    return buffer.toString();
  }

  static void showMockLhdnSuccessDialog(
    BuildContext context, {
    required String invoiceNumber,
    required double totalAmount,
    required VoidCallback onDone,
    SaleRecord? saleRecord,
    BusinessProfile? businessProfile,
    bool isLhdnSubmitted = true,
  }) {
    final theme = Theme.of(context);
    final currencyFormat = NumberFormat.currency(symbol: 'RM ', decimalDigits: 2);
    final formattedAmount = currencyFormat.format(totalAmount);

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return Dialog(
          backgroundColor: theme.colorScheme.surface,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  isLhdnSubmitted ? Icons.check_circle_outline_rounded : Icons.cloud_done_rounded,
                  size: 64,
                  color: isLhdnSubmitted ? AppTheme.neonGreenLight : AppTheme.primary,
                ),
                const SizedBox(height: 16),
                Text(
                  isLhdnSubmitted ? 'LHDN Submission Successful' : 'Sale Recorded Successfully',
                  style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                Text(
                  'Invoice: $invoiceNumber',
                  style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                ),
                Text(
                  'Total: $formattedAmount',
                  style: theme.textTheme.titleMedium?.copyWith(color: theme.colorScheme.primary, fontWeight: FontWeight.bold),
                ),
                if (isLhdnSubmitted) ...[
                  const SizedBox(height: 24),
                  QrImageView(
                    data: 'https://myinvois.hasil.gov.my/mock-validation/$invoiceNumber',
                    version: QrVersions.auto,
                    size: 180.0,
                    backgroundColor: Colors.white,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Scan to Verify',
                    style: theme.textTheme.labelSmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                  ),
                ] else ...[
                  const SizedBox(height: 24),
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.info_outline_rounded, size: 20, color: theme.colorScheme.onSurfaceVariant),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            'This sale is saved as pending. You can submit it to LHDN later from the history.',
                            style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
                const SizedBox(height: 24),
                if (saleRecord != null && businessProfile != null) ...[
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton(
                      style: OutlinedButton.styleFrom(
                        minimumSize: const Size(double.infinity, AppTheme.minTouchTarget),
                        side: const BorderSide(color: AppTheme.primary, width: 1.5),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppTheme.radiusMedium)),
                      ),
                      onPressed: () {
                        final text = generateReceiptText(saleRecord, businessProfile);
                        Share.share(text);
                      },
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.share_rounded, size: 20, color: AppTheme.primary),
                          const SizedBox(width: 12),
                          const Text('Share Receipt', style: TextStyle(fontWeight: FontWeight.bold)),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                ],
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.primary,
                      foregroundColor: Colors.white,
                      minimumSize: const Size(double.infinity, AppTheme.minTouchTarget),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppTheme.radiusMedium)),
                    ),
                    onPressed: () {
                      onDone();
                    },
                    child: const Text('Done', style: TextStyle(fontWeight: FontWeight.bold)),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
