import 'package:flutter/material.dart';
import '../../core/app_theme.dart';
import '../../core/lhdn_constants.dart';
import '../../widgets/custom_widgets.dart';
import '../../widgets/app_dialogs.dart';

class RecordExpenseScreen extends StatefulWidget {
  final double? scannedAmount;

  const RecordExpenseScreen({super.key, this.scannedAmount});

  @override
  State<RecordExpenseScreen> createState() => _RecordExpenseScreenState();
}

class _RecordExpenseScreenState extends State<RecordExpenseScreen> {
  final _formKey = GlobalKey<FormState>();
  final _vendorController = TextEditingController();
  final _amountController = TextEditingController();
  final _dateController = TextEditingController();
  String? _selectedCategory;

  @override
  void initState() {
    super.initState();
    if (widget.scannedAmount != null) {
      _amountController.text = widget.scannedAmount!.toStringAsFixed(2);
      _vendorController.text = 'SCANNED VENDOR'; // Simulated OCR data
      _dateController.text = '2026-04-28';
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

  void _saveExpense() {
    if (_formKey.currentState!.validate()) {
      // TODO: Save to Firestore
      AppDialogs.showActionModal(
        context,
        title: 'Expense Recorded',
        body: 'Your expense has been saved successfully.',
        primaryButtonText: 'Done',
        onPrimaryPressed: () {
          Navigator.pop(context);
        },
        icon: Icons.check_circle_outline_rounded,
        iconColor: Colors.green,
        primaryButtonColor: Colors.green,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
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
                        color: Colors.white,
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
                        widget.scannedAmount != null ? Icons.receipt_long_rounded : Icons.add_a_photo_rounded,
                        size: 36,
                        color: Colors.orange.shade700,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      widget.scannedAmount != null ? 'Receipt Attached' : 'Attach Receipt',
                      style: theme.textTheme.titleMedium?.copyWith(
                        color: theme.colorScheme.onSurface,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    if (widget.scannedAmount != null) ...[
                      const SizedBox(height: 8),
                      Text(
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
                validator: (val) => val == null || val.isEmpty ? 'Required' : null,
              ),
              const SizedBox(height: 20),

              AppTextField(
                labelText: 'Date',
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
                validator: (val) => val == null ? 'Required' : null,
              ),
              const SizedBox(height: 40),

              AppButton(
                text: 'Save Expense',
                onPressed: _saveExpense,
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

