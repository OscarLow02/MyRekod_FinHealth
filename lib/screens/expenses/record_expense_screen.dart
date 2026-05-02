import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:image_picker/image_picker.dart';
import '../../core/app_theme.dart';
import '../../models/expense_record.dart';
import '../../providers/expense_provider.dart';
import '../../widgets/custom_widgets.dart';
import '../../widgets/custom_dropdown.dart';
import '../../widgets/app_dialogs.dart';
import '../../services/ocr_service.dart';

class RecordExpenseScreen extends StatefulWidget {
  final double? scannedAmount;
  final String? scannedVendor;
  final String? scannedDate;
  final String? imagePath;
  final ExpenseRecord? existingExpense; // If provided, we are in Edit Mode

  const RecordExpenseScreen({
    super.key,
    this.scannedAmount,
    this.scannedVendor,
    this.scannedDate,
    this.imagePath,
    this.existingExpense,
  });

  @override
  State<RecordExpenseScreen> createState() => _RecordExpenseScreenState();
}

class _RecordExpenseScreenState extends State<RecordExpenseScreen> {
  final _formKey = GlobalKey<FormState>();
  final _vendorController = TextEditingController();
  final _amountController = TextEditingController();
  final _dateController = TextEditingController();
  final _notesController = TextEditingController();
  String? _selectedCategory;
  bool _isSaving = false;
  String? _currentImagePath;
  final ImagePicker _imagePicker = ImagePicker();
  DateTime _selectedDate = DateTime.now();

  @override
  void initState() {
    super.initState();

    if (widget.existingExpense != null) {
      // Edit Mode: Pre-fill from existing expense
      final e = widget.existingExpense!;
      _amountController.text = e.amount.toStringAsFixed(2);
      _vendorController.text = e.vendor;
      _dateController.text =
          '${e.date.year}-${e.date.month.toString().padLeft(2, '0')}-${e.date.day.toString().padLeft(2, '0')}';
      _selectedCategory = e.category;
      _notesController.text = e.notes ?? '';
      _currentImagePath = e.imagePath;

      // ADD THIS CALL FOR EDIT MODE
      _resolveImagePath(e.imagePath); 
    } else {
      // Create Mode: Auto-fill from OCR data if available
      _currentImagePath = widget.imagePath;
      if (widget.scannedAmount != null) {
        _amountController.text = widget.scannedAmount!.toStringAsFixed(2);
      }
      if (widget.scannedVendor != null) {
        _vendorController.text = widget.scannedVendor!;
      }
      if (widget.scannedDate != null) {
        _dateController.text = widget.scannedDate!;
        try {
          final parts = widget.scannedDate!.split('-');
          _selectedDate = DateTime(int.parse(parts[0]), int.parse(parts[1]), int.parse(parts[2]));
        } catch (_) {}
      } else {
        _dateController.text = DateFormat('yyyy-MM-dd').format(_selectedDate);
      }
    }
  }

  @override
  void dispose() {
    _vendorController.dispose();
    _amountController.dispose();
    _dateController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  // ── Image Persistence & Resolution ─────────────────────────────────────

  Future<void> _resolveImagePath(String? path) async {
    if (path == null || path.isEmpty) return;

    File file = File(path);
    if (!await file.exists()) {
      final fileName = path.split('/').last;
      final appDir = await getApplicationDocumentsDirectory();
      final newPath = '${appDir.path}/receipts/$fileName';

      if (await File(newPath).exists() && mounted) {
        setState(() => _currentImagePath = newPath);
      }
    }
  }

  Future<void> _selectDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
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

    if (picked != null && picked != _selectedDate) {
      setState(() {
        _selectedDate = picked;
        _dateController.text = DateFormat('yyyy-MM-dd').format(picked);
      });
    }
  }

  void _handleBackPress() {
    AppDialogs.showActionModal(
      context,
      title: 'Discard Changes?',
      body: 'If you go back now, all details entered will be discarded.',
      primaryButtonText: 'Discard',
      primaryButtonColor: Colors.redAccent,
      onPrimaryPressed: () {
        Navigator.of(context).pop(); // This pops the RecordExpenseScreen
      },
      secondaryButtonText: 'Keep Editing',
      icon: Icons.warning_amber_rounded,
      iconColor: Colors.orange,
    );
  }

  Future<String?> _persistImageLocally(String tempPath) async {
    return await OcrService.standardSecureCapturedImage(tempPath);
  }

  Future<void> _reuploadReceipt() async {
    final XFile? photo = await _imagePicker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 85,
    );

    if (photo != null) {
      setState(() {
        _currentImagePath = photo.path;
      });
    }
  }

  void _removeReceipt() {
    setState(() {
      _currentImagePath = null;
    });
  }

  // ── Save Logic ──────────────────────────────────────────────────────────

  Future<void> _saveExpense() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSaving = true);

    try {
      // 1. Persist new image if it changed and is temporary
      String? finalImagePath = _currentImagePath;
      if (_currentImagePath != null &&
          !_currentImagePath!.contains('Documents/receipts')) {
        finalImagePath = await _persistImageLocally(_currentImagePath!);
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

      final isEdit = widget.existingExpense != null;

      // 3. Construct the ExpenseRecord
      final expense = ExpenseRecord(
        id: isEdit ? widget.existingExpense!.id : '',
        date: expenseDate,
        amount: double.tryParse(_amountController.text) ?? 0.0,
        vendor: _vendorController.text.trim(),
        category: _selectedCategory!,
        imagePath: finalImagePath,
        notes: _notesController.text.trim().isNotEmpty
            ? _notesController.text.trim()
            : null,
        createdAt: isEdit ? widget.existingExpense!.createdAt : DateTime.now(),
        updatedAt: DateTime.now(),
      );

      // 4. Save via ExpenseProvider
      if (!mounted) return;
      if (isEdit) {
        await context.read<ExpenseProvider>().updateExpense(expense);
      } else {
        await context.read<ExpenseProvider>().addExpense(expense);
      }

      if (!mounted) return;
      setState(() => _isSaving = false);

      // 5. Show success confirmation
      AppDialogs.showActionModal(
        context,
        title: isEdit ? 'Expense Updated' : 'Expense Recorded',
        body: 'Your expense of RM ${_amountController.text} has been saved.',
        primaryButtonText: 'Done',
        onPrimaryPressed: () {
          // Dialog is auto-dismissed by showActionModal, just pop the screen
          Navigator.pop(context, expense);
        },
        icon: Icons.check_circle_outline_rounded,
        iconColor: Colors.green,
        primaryButtonColor: Colors.green,
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _isSaving = false);

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

  // ── Add New Category Dialog ──────────────────────────────────────────────────────────
  Future<void> _showAddCategoryDialog(
    BuildContext context,
    ExpenseProvider provider,
  ) async {
    final TextEditingController newCatController = TextEditingController();
    final theme = Theme.of(context);

    await showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          backgroundColor: theme.colorScheme.surface,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppTheme.radiusLarge),
          ),
          title: Text(
            'New Expense Category',
            style: theme.textTheme.titleLarge,
          ),
          content: AppTextField(
            controller: newCatController,
            hintText: 'e.g., Digital Ads, Maintenance',
            textCapitalization: TextCapitalization.words,
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text(
                'Cancel',
                style: TextStyle(color: theme.colorScheme.onSurfaceVariant),
              ),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primary,
                foregroundColor: Colors.white,
              ),
              onPressed: () async {
                final val = newCatController.text.trim();
                if (val.isNotEmpty) {
                  await provider.addCategory(val);
                  setState(
                    () => _selectedCategory = val,
                  ); // Auto-select the newly created category
                }
                Navigator.pop(ctx);
              },
              child: const Text('Add'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final hasReceipt = _currentImagePath != null;
    final isEdit = widget.existingExpense != null;
    final isAutoFilled =
        widget.scannedAmount != null || widget.scannedVendor != null;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        _handleBackPress();
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text(isEdit ? 'Edit Expense' : 'Record Expense'),
          backgroundColor: Colors.transparent,
          elevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: _handleBackPress,
          ),
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
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: theme.colorScheme.surface,
                  border: Border.all(
                    color: Colors.orange.shade700.withValues(alpha: 0.3),
                  ),
                  borderRadius: BorderRadius.circular(AppTheme.radiusXLarge),
                ),
                child: Column(
                  children: [
                    if (hasReceipt)
                      ClipRRect(
                        borderRadius: BorderRadius.circular(
                          AppTheme.radiusLarge,
                        ),
                        child: Image.file(
                          File(_currentImagePath!),
                          height: 180,
                          width: double.infinity,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => const Icon(
                            Icons.broken_image,
                            size: 50,
                            color: Colors.grey,
                          ),
                        ),
                      )
                    else
                      Container(
                        padding: const EdgeInsets.all(24),
                        decoration: BoxDecoration(
                          color: theme.colorScheme.onSurface.withValues(
                            alpha: 0.05,
                          ),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          Icons.add_a_photo_rounded,
                          size: 48,
                          color: Colors.orange.shade700,
                        ),
                      ),
                    const SizedBox(height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        TextButton.icon(
                          onPressed: _reuploadReceipt,
                          icon: Icon(
                            hasReceipt
                                ? Icons.edit_rounded
                                : Icons.upload_rounded,
                            color: Colors.orange.shade700,
                            size: 18,
                          ),
                          label: Text(
                            hasReceipt ? 'Change Image' : 'Upload Receipt',
                            style: TextStyle(
                              color: Colors.orange.shade700,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        if (hasReceipt) ...[
                          const SizedBox(width: 16),
                          TextButton.icon(
                            onPressed: _removeReceipt,
                            icon: const Icon(
                              Icons.delete_outline_rounded,
                              color: Colors.redAccent,
                              size: 18,
                            ),
                            label: const Text(
                              'Remove',
                              style: TextStyle(
                                color: Colors.redAccent,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 32),

              // Section Title with Badge
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Expense Details',
                    style: theme.textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  if (isAutoFilled && !isEdit)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: AppTheme.secondaryDark.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(
                          AppTheme.radiusMedium,
                        ),
                        border: Border.all(
                          color: AppTheme.secondaryDark.withValues(alpha: 0.3),
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.auto_awesome_rounded,
                            size: 14,
                            color: AppTheme.secondaryDark,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            'Auto-filled',
                            style: theme.textTheme.labelMedium?.copyWith(
                              color: AppTheme.secondaryDark,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 20),

              AppTextField(
                label: 'Vendor Name',
                icon: Icons.storefront_rounded,
                controller: _vendorController,
                hintText: 'Enter vendor name',
                validator: (val) =>
                    val == null || val.isEmpty ? 'Required' : null,
              ),
              const SizedBox(height: 16),

              AppTextField(
                label: 'Amount (RM)',
                icon: Icons.payments_rounded,
                controller: _amountController,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                hintText: '0.00',
                validator: (val) {
                  if (val == null || val.isEmpty) return 'Amount is required';
                  final amount = double.tryParse(val);
                  if (amount == null || amount <= 0)
                    return 'Enter a valid amount';
                  return null;
                },
              ),
              const SizedBox(height: 16),

              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: GestureDetector(
                      onTap: () => _selectDate(context),
                      child: AbsorbPointer(
                        child: AppTextField(
                          label: 'Date',
                          icon: Icons.calendar_month_rounded,
                          controller: _dateController,
                          hintText: 'YYYY-MM-DD',
                          validator: (val) =>
                              val == null || val.isEmpty ? 'Required' : null,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Consumer<ExpenseProvider>(
                      builder: (context, provider, _) {
                        // 1. Get categories from provider
                        final allCategories = List<String>.from(provider.categories);

                        // 2. Safe-check: If editing an old expense with a deleted category, keep it visible
                        if (_selectedCategory != null &&
                            !allCategories.contains(_selectedCategory)) {
                          allCategories.add(_selectedCategory!);
                        }

                        // 3. Map to CustomDropdownItems and append the "+ Add New Category" option
                        final dropdownItems =
                            allCategories
                                .map(
                                  (cat) => CustomDropdownItem<String>(
                                    label: cat,
                                    value: cat,
                                    icon: Icons.folder_outlined,
                                  ),
                                )
                                .toList()
                              ..add(
                                CustomDropdownItem<String>(
                                  label: '+ Add New Category',
                                  value: 'ADD_NEW',
                                  icon: Icons.add_circle_outline_rounded,
                                  isAction: true,
                                ),
                              );

                        return CustomPremiumDropdown<String>(
                          label: 'Category',
                          value: _selectedCategory,
                          items: dropdownItems,
                          isSearchable: true,
                          onChanged: (val) {
                            if (val == 'ADD_NEW') {
                              _showAddCategoryDialog(
                                context,
                                provider,
                              ); // Trigger the popup
                            } else {
                              setState(() => _selectedCategory = val);
                            }
                          },
                          validator: (val) => val == null ? 'Required' : null,
                          fillColor: theme.colorScheme.surfaceContainerHighest
                              .withValues(alpha: 0.3),
                        );
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              AppTextField(
                label: 'Notes (Optional)',
                icon: Icons.notes_rounded,
                controller: _notesController,
                hintText: 'Add extra details...',
                maxLines: 3,
              ),
              const SizedBox(height: 32),

              AppButton(
                text: isEdit ? 'Update Expense' : 'Save Expense',
                onPressed: _isSaving ? null : _saveExpense,
                isLoading: _isSaving,
                icon: const Icon(Icons.save_rounded),
              ),
              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    ),
    );
  }
}
