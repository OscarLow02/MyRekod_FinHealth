import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import '../../core/app_theme.dart';
import '../../core/lhdn_constants.dart';
import '../../models/expense_record.dart';
import '../../providers/expense_provider.dart';
import '../../widgets/custom_widgets.dart';
import '../../widgets/app_dialogs.dart';

class RecordExpenseScreen extends StatefulWidget {
  final double? scannedAmount;
  final String? scannedVendor;
  final String? scannedDate;
  final String? imagePath;

  const RecordExpenseScreen({
    super.key,
    this.scannedAmount,
    this.scannedVendor,
    this.scannedDate,
    this.imagePath,
  });

  @override
  State<RecordExpenseScreen> createState() => _RecordExpenseScreenState();
}

class _RecordExpenseScreenState extends State<RecordExpenseScreen> {
  final _formKey = GlobalKey<FormState>();
  final _vendorController = TextEditingController();
  final _amountController = TextEditingController();
  final _dateController = TextEditingController();
  String? _selectedCategory;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    // Auto-fill from OCR data if available
    if (widget.scannedAmount != null) {
      _amountController.text = widget.scannedAmount!.toStringAsFixed(2);
    }
    if (widget.scannedVendor != null && widget.scannedVendor!.isNotEmpty) {
      _vendorController.text = widget.scannedVendor!;
    }
    if (widget.scannedDate != null && widget.scannedDate!.isNotEmpty) {
      _dateController.text = widget.scannedDate!;
    } else {
      _dateController.text = DateTime.now().toIso8601String().split('T')[0];
    }
  }

  @override
  void dispose() {
    _vendorController.dispose();
    _amountController.dispose();
    _dateController.dispose();
    super.dispose();
  }

  // ── Image Persistence ───────────────────────────────────────────────────

  /// Copies the receipt image from its temporary cache location to the app's
  /// permanent documents directory. This ensures the image survives cache
  /// clears (critical for Offline-First).
  Future<String?> _persistImageLocally(String tempPath) async {
    try {
      final appDir = await getApplicationDocumentsDirectory();
      final receiptsDir = Directory(p.join(appDir.path, 'receipts'));
      if (!await receiptsDir.exists()) {
        await receiptsDir.create(recursive: true);
      }

      final fileName = 'receipt_${DateTime.now().millisecondsSinceEpoch}'
          '${p.extension(tempPath)}';
      final permanentPath = p.join(receiptsDir.path, fileName);

      await File(tempPath).copy(permanentPath);
      return permanentPath;
    } catch (e) {
      debugPrint('Failed to persist image: $e');
      return null;
    }
  }

  // ── Save Logic ──────────────────────────────────────────────────────────

  Future<void> _saveExpense() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSaving = true);

    try {
      // 1. Persist image to local documents directory
      String? permanentImagePath;
      if (widget.imagePath != null) {
        permanentImagePath = await _persistImageLocally(widget.imagePath!);
      }

      // 2. Parse the date from the text field
      final dateParts = _dateController.text.split('-');
      DateTime expenseDate;
      try {
        expenseDate = DateTime(
          int.parse(dateParts[0]),
          int.parse(dateParts[1]),
          int.parse(dateParts[2]),
        );
      } catch (_) {
        expenseDate = DateTime.now();
      }

      // 3. Construct the ExpenseRecord
      final expense = ExpenseRecord(
        id: '', // Firestore will auto-generate
        date: expenseDate,
        amount: double.tryParse(_amountController.text) ?? 0.0,
        vendor: _vendorController.text.trim(),
        category: _selectedCategory!,
        imagePath: permanentImagePath,
      );

      // 4. Save via ExpenseProvider (Firestore with offline optimistic concurrency)
      if (!mounted) return;
      await context.read<ExpenseProvider>().addExpense(expense);

      if (!mounted) return;
      setState(() => _isSaving = false);

      // 5. Show success confirmation
      AppDialogs.showActionModal(
        context,
        title: 'Expense Recorded',
        body: 'Your expense of RM ${_amountController.text} has been saved.',
        primaryButtonText: 'Done',
        onPrimaryPressed: () {
          Navigator.pop(context); // Pop back to previous screen
        },
        icon: Icons.check_circle_outline_rounded,
        iconColor: Colors.green,
        primaryButtonColor: Colors.green,
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _isSaving = false);

      // TODO: Implement i18n
      AppDialogs.showActionModal(
        context,
        title: 'Save Failed',
        body: 'Could not save expense. Please try again.\n\nError: $e',
        primaryButtonText: 'OK',
        onPrimaryPressed: () {},
        icon: Icons.error_outline_rounded,
        iconColor: Colors.redAccent,
        primaryButtonColor: Colors.redAccent,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final hasReceipt = widget.imagePath != null;
    
    return Scaffold(
      appBar: AppBar(
        title: const Text('Record Expense'),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Receipt Evidence
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 24),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      Colors.orange.shade700.withValues(alpha: 0.15),
                      Colors.orange.shade900.withValues(alpha: 0.05),
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  border: Border.all(color: Colors.orange.shade700.withValues(alpha: 0.3)),
                  borderRadius: BorderRadius.circular(AppTheme.radiusXLarge),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.orange.shade700.withValues(alpha: 0.05),
                      blurRadius: 20,
                      spreadRadius: -5,
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.surface,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: Colors.orange.shade700.withValues(alpha: 0.2),
                            blurRadius: 12,
                            spreadRadius: 2,
                          ),
                        ],
                      ),
                      child: Icon(
                        hasReceipt ? Icons.receipt_long_rounded : Icons.add_a_photo_rounded,
                        size: 36,
                        color: Colors.orange.shade700,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      // TODO: Implement i18n
                      hasReceipt ? 'Receipt Attached' : 'Manual Entry',
                      style: theme.textTheme.titleMedium?.copyWith(
                        color: theme.colorScheme.onSurface,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    if (hasReceipt) ...[
                      const SizedBox(height: 8),
                      Text(
                        // TODO: Implement i18n
                        'Scanned from camera',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: Colors.orange.shade700,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 32),

              AppTextField(
                labelText: 'Vendor Name',
                controller: _vendorController,
                prefixIcon: const Icon(Icons.storefront_rounded),
                validator: (val) => val == null || val.isEmpty ? 'Required' : null,
              ),
              const SizedBox(height: 20),

              AppTextField(
                labelText: 'Amount (RM)',
                controller: _amountController,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                prefixIcon: const Icon(Icons.payments_rounded),
                validator: (val) {
                  if (val == null || val.isEmpty) return 'Amount is required';
                  final amount = double.tryParse(val);
                  if (amount == null || amount <= 0) return 'Enter a valid amount';
                  return null;
                },
              ),
              const SizedBox(height: 20),

              AppTextField(
                labelText: 'Date (YYYY-MM-DD)',
                controller: _dateController,
                prefixIcon: const Icon(Icons.calendar_month_rounded),
                validator: (val) => val == null || val.isEmpty ? 'Required' : null,
              ),
              const SizedBox(height: 20),

              AppDropdown<String>(
                hintText: 'Select Category',
                value: _selectedCategory,
                items: LhdnConstants.expenseCategories
                    .map((cat) => DropdownMenuItem(value: cat, child: Text(cat)))
                    .toList(),
                onChanged: (val) => setState(() => _selectedCategory = val),
                validator: (val) => val == null ? 'Category is required' : null,
              ),
              const SizedBox(height: 40),

              AppButton(
                text: 'Save Expense',
                onPressed: _isSaving ? null : _saveExpense,
                isLoading: _isSaving,
                icon: const Icon(Icons.check_circle_rounded),
              ),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }
}
