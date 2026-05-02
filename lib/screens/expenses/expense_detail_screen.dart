import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../core/app_theme.dart';
import '../../models/expense_record.dart';
import '../../providers/expense_provider.dart';
import '../../widgets/app_dialogs.dart';
import '../../widgets/custom_widgets.dart';
import 'record_expense_screen.dart';

class ExpenseDetailScreen extends StatefulWidget {
  final ExpenseRecord expense;

  const ExpenseDetailScreen({super.key, required this.expense});

  @override
  State<ExpenseDetailScreen> createState() => _ExpenseDetailScreenState();
}

class _ExpenseDetailScreenState extends State<ExpenseDetailScreen> {
  late ExpenseRecord _currentExpense;

  @override
  void initState() {
    super.initState();
    _currentExpense = widget.expense;
  }

  void _deleteExpense() {
    AppDialogs.showActionModal(
      context,
      title: 'Delete Expense',
      body: 'Are you sure you want to delete this expense? This action cannot be undone.',
      primaryButtonText: 'Delete',
      primaryButtonColor: Colors.redAccent,
      icon: Icons.warning_rounded,
      iconColor: Colors.redAccent,
      onPrimaryPressed: () async {
        Navigator.pop(context); // Close dialog
        try {
          await context.read<ExpenseProvider>().deleteExpense(_currentExpense.id);
          if (mounted) {
            Navigator.pop(context); // Go back to transactions
          }
        } catch (e) {
          if (mounted) {
            AppDialogs.showActionModal(
              context,
              title: 'Delete Failed',
              body: 'Error: $e',
              primaryButtonText: 'OK',
              onPrimaryPressed: () => Navigator.pop(context),
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

  Future<void> _editExpense() async {
    final updatedExpense = await Navigator.push<ExpenseRecord>(
      context,
      MaterialPageRoute(
        builder: (_) => RecordExpenseScreen(existingExpense: _currentExpense),
      ),
    );

    if (updatedExpense != null && mounted) {
      setState(() {
        _currentExpense = updatedExpense;
      });
    }
  }

  Widget _buildInfoRow({required String label, required Widget child}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 4),
          child,
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final dateStr = DateFormat('MMM dd, yyyy').format(_currentExpense.date);
    final timeStr = DateFormat('HH:mm').format(_currentExpense.createdAt);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Expense Details'),
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.delete_outline_rounded, color: Colors.redAccent),
            onPressed: _deleteExpense,
            tooltip: 'Delete',
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            // Big Amount Card
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 32),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    Colors.orange.shade700.withValues(alpha: 0.15),
                    Colors.orange.shade700.withValues(alpha: 0.05),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(AppTheme.radiusLarge),
                border: Border.all(
                  color: Colors.orange.shade700.withValues(alpha: 0.3),
                  width: 1.5,
                ),
              ),
              child: Column(
                children: [
                  Text(
                    'Amount',
                    style: theme.textTheme.labelLarge?.copyWith(
                      color: Colors.orange.shade700,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 1.2,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'RM ${_currentExpense.amount.toStringAsFixed(2)}',
                    style: theme.textTheme.headlineMedium?.copyWith(
                      fontWeight: FontWeight.w900,
                      color: theme.colorScheme.onSurface,
                      fontSize: 32,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Transaction Info Card
            Container(
              decoration: BoxDecoration(
                color: theme.colorScheme.surface,
                borderRadius: BorderRadius.circular(AppTheme.radiusLarge),
                border: Border.all(color: theme.colorScheme.outlineVariant),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Header
                  Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Row(
                      children: [
                        Icon(Icons.receipt_long_rounded, color: theme.colorScheme.primary, size: 20),
                        const SizedBox(width: 8),
                        Text(
                          'Transaction Info',
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const Spacer(),
                        InkWell(
                          onTap: _editExpense,
                          borderRadius: BorderRadius.circular(20),
                          child: Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: theme.colorScheme.onSurface.withValues(alpha: 0.05),
                              shape: BoxShape.circle,
                            ),
                            child: Icon(Icons.edit_rounded, size: 18, color: theme.colorScheme.onSurfaceVariant),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Divider(height: 1),
                  // Content
                  Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildInfoRow(
                          label: 'Merchant',
                          child: Text(
                            _currentExpense.vendor.isNotEmpty ? _currentExpense.vendor : 'Unknown Vendor',
                            style: theme.textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.bold),
                          ),
                        ),
                        _buildInfoRow(
                          label: 'Date & Time',
                          child: Text(
                            '$dateStr at $timeStr',
                            style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
                          ),
                        ),
                        _buildInfoRow(
                          label: 'Category',
                          child: Row(
                            children: [
                              Icon(Icons.folder_outlined, size: 16, color: theme.colorScheme.onSurface),
                              const SizedBox(width: 6),
                              Text(
                                _currentExpense.category,
                                style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
                              ),
                            ],
                          ),
                        ),
                        if (_currentExpense.notes != null && _currentExpense.notes!.isNotEmpty)
                          _buildInfoRow(
                            label: 'Notes',
                            child: Container(
                              width: double.infinity,
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: theme.colorScheme.onSurface.withValues(alpha: 0.05),
                                borderRadius: BorderRadius.circular(AppTheme.radiusSmall),
                              ),
                              child: Text(
                                '"${_currentExpense.notes}"',
                                style: theme.textTheme.bodyMedium?.copyWith(
                                  fontStyle: FontStyle.italic,
                                  color: theme.colorScheme.onSurfaceVariant,
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Attached Receipt Card
            Container(
              decoration: BoxDecoration(
                color: theme.colorScheme.surface,
                borderRadius: BorderRadius.circular(AppTheme.radiusLarge),
                border: Border.all(color: theme.colorScheme.outlineVariant),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Row(
                      children: [
                        Icon(Icons.image_outlined, color: theme.colorScheme.primary, size: 20),
                        const SizedBox(width: 8),
                        Text(
                          'Attached Receipt',
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Divider(height: 1),
                  Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: _currentExpense.imagePath != null && _currentExpense.imagePath!.isNotEmpty
                        ? ClipRRect(
                            borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
                            child: Image.file(
                              File(_currentExpense.imagePath!),
                              width: double.infinity,
                              fit: BoxFit.cover,
                              errorBuilder: (context, error, stackTrace) {
                                return Container(
                                  height: 150,
                                  color: theme.colorScheme.onSurface.withValues(alpha: 0.05),
                                  child: Center(
                                    child: Text(
                                      'Image file not found locally',
                                      style: theme.textTheme.bodyMedium?.copyWith(
                                        color: theme.colorScheme.onSurfaceVariant,
                                      ),
                                    ),
                                  ),
                                );
                              },
                            ),
                          )
                        : Container(
                            height: 100,
                            width: double.infinity,
                            decoration: BoxDecoration(
                              color: theme.colorScheme.onSurface.withValues(alpha: 0.05),
                              borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
                            ),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.image_not_supported_outlined, color: theme.colorScheme.onSurfaceVariant),
                                const SizedBox(height: 8),
                                Text(
                                  'No receipt attached',
                                  style: theme.textTheme.bodyMedium?.copyWith(
                                    color: theme.colorScheme.onSurfaceVariant,
                                  ),
                                ),
                              ],
                            ),
                          ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Bottom Buttons
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () {
                  // TODO: Implement Share Details logic
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: theme.colorScheme.onSurface.withValues(alpha: 0.1),
                  foregroundColor: theme.colorScheme.onSurface,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
                  ),
                  elevation: 0,
                ),
                icon: const Icon(Icons.share_rounded, size: 20),
                label: const Text('Share Details', style: TextStyle(fontWeight: FontWeight.w600)),
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: AppButton(
                text: 'Download CSV',
                onPressed: () {
                  // TODO: Implement single CSV export logic
                },
                icon: const Icon(Icons.download_rounded, size: 20),
              ),
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }
}
