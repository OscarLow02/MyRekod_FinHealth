import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:csv/csv.dart';
import 'package:share_plus/share_plus.dart';
import 'package:path_provider/path_provider.dart';
import '../../core/app_theme.dart';
import '../../models/expense_record.dart';
import '../../providers/expense_provider.dart';
import '../../widgets/app_dialogs.dart';
import '../../widgets/custom_widgets.dart';
import 'record_expense_screen.dart';
import '../../services/ocr_service.dart';

class ExpenseDetailScreen extends StatefulWidget {
  final ExpenseRecord expense;

  const ExpenseDetailScreen({super.key, required this.expense});

  @override
  State<ExpenseDetailScreen> createState() => _ExpenseDetailScreenState();
}

class _ExpenseDetailScreenState extends State<ExpenseDetailScreen> {
  late ExpenseRecord _currentExpense;
  File? _resolvedImage;

  @override
  void initState() {
    super.initState();
    _currentExpense = widget.expense;
    _resolveImagePath();
  }

  Future<void> _resolveImagePath() async {
    final resolvedPath = await OcrService.resolveImagePath(_currentExpense.imagePath);
    if (resolvedPath != null && mounted) {
      setState(() => _resolvedImage = File(resolvedPath));
    }
  }

  void _deleteExpense() {
    AppDialogs.showActionModal(
      context,
      title: 'Delete Expense',
      body:
          'Are you sure you want to delete this expense? This action cannot be undone.',
      primaryButtonText: 'Delete',
      primaryButtonColor: Colors.redAccent,
      icon: Icons.warning_rounded,
      iconColor: Colors.redAccent,
      onPrimaryPressed: () async {
        try {
          await context
              .read<ExpenseProvider>()
              .deleteExpense(_currentExpense.id);
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

  Future<void> _exportToCsv() async {
    try {
      final dateStr = DateFormat('yyyy-MM-dd').format(_currentExpense.date);
      final rows = [
        ['ID', 'Date', 'Vendor', 'Category', 'Amount', 'Notes', 'Receipt Path'],
        [
          _currentExpense.id,
          dateStr,
          _currentExpense.vendor,
          _currentExpense.category,
          _currentExpense.amount.toStringAsFixed(2),
          _currentExpense.notes ?? '',
          _currentExpense.imagePath ?? 'No Receipt',
        ]
      ];

      final csvData = const ListToCsvConverter().convert(rows);
      final directory = await getTemporaryDirectory();
      final fileName = 'Expense_${_currentExpense.vendor}_$dateStr.csv';
      final file = File('${directory.path}/$fileName');
      await file.writeAsString(csvData);

      final box = context.findRenderObject() as RenderBox?;

      await Share.shareXFiles(
        [XFile(file.path)],
        subject: 'MyRekod Expense - ${_currentExpense.vendor}',
        sharePositionOrigin:
            box != null ? box.localToGlobal(Offset.zero) & box.size : null,
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to export CSV: $e')),
        );
      }
    }
  }

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
        color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
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
            child:
                Icon(icon, size: 20, color: theme.colorScheme.onSurfaceVariant),
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

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final dateStr = DateFormat('dd MMM yyyy').format(_currentExpense.date);
    final createdStr = DateFormat('dd MMM yyyy, hh:mm a').format(_currentExpense.createdAt);
    final modifiedStr = DateFormat('yyyy/MM/dd').format(_currentExpense.updatedAt);

    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Expense Details',
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
          IconButton(
            icon: const Icon(Icons.edit_outlined, size: 22),
            onPressed: _editExpense,
            tooltip: 'Edit',
          ),
          IconButton(
            icon: const Icon(Icons.delete_outline_rounded,
                color: Colors.redAccent, size: 22),
            onPressed: _deleteExpense,
            tooltip: 'Delete',
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Big Amount Card (Keeps Orange Gradient as requested)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 40),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    Colors.orange.shade700.withValues(alpha: 0.15),
                    Colors.orange.shade700.withValues(alpha: 0.05),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(AppTheme.radiusLarge * 2),
                border: Border.all(
                  color: Colors.orange.shade700.withValues(alpha: 0.3),
                  width: 1.5,
                ),
              ),
              child: Column(
                children: [
                  Text(
                    'TOTAL AMOUNT',
                    style: theme.textTheme.labelMedium?.copyWith(
                      color: Colors.orange.shade700,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 1.5,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'RM ${_currentExpense.amount.toStringAsFixed(2)}',
                    style: theme.textTheme.displayMedium?.copyWith(
                      fontWeight: FontWeight.w900,
                      color: theme.colorScheme.onSurface,
                      letterSpacing: -1.0,
                    ),
                  ),
                  const SizedBox(height: 24),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.surface.withValues(alpha: 0.5),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: Colors.orange.shade700.withValues(alpha: 0.2),
                      ),
                    ),
                    child: Text(
                      'Category: ${_currentExpense.category}',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.onSurface,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 32),

            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Transaction Info',
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.5,
                  ),
                ),
                Text(
                  'Last modified: $modifiedStr',
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant.withOpacity(0.6),
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            _buildDetailCard(
              theme,
              icon: Icons.calendar_today_rounded,
              label: 'Date',
              value: dateStr,
            ),
            _buildDetailCard(
              theme,
              icon: Icons.history_rounded,
              label: 'Created Date & Time',
              value: createdStr,
            ),
            _buildDetailCard(
              theme,
              icon: Icons.storefront_rounded,
              label: 'Merchant',
              value: _currentExpense.vendor.isNotEmpty
                  ? _currentExpense.vendor
                  : 'Unknown Vendor',
            ),
            if (_currentExpense.notes != null &&
                _currentExpense.notes!.isNotEmpty)
              _buildDetailCard(
                theme,
                icon: Icons.notes_rounded,
                label: 'Notes',
                value: _currentExpense.notes!,
              ),

            const SizedBox(height: 32),

            // Receipt Attachment Section
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Receipt Attachment',
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.5,
                  ),
                ),
                TextButton(
                  onPressed: _editExpense, // Re-use edit flow to change photo
                  child: Text(
                    'REPLACE',
                    style: theme.textTheme.labelLarge?.copyWith(
                      color: theme.colorScheme.primary,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Image Container
            Container(
              width: double.infinity,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(AppTheme.radiusLarge),
                border: Border.all(
                  color: theme.colorScheme.outlineVariant,
                  width: 1,
                ),
              ),
              child: _resolvedImage != null
                  ? ClipRRect(
                      borderRadius:
                          BorderRadius.circular(AppTheme.radiusLarge - 1),
                      child: Image.file(
                        _resolvedImage!,
                        width: double.infinity,
                        fit: BoxFit.contain,
                      ),
                    )
                  : _buildEmptyImagePlaceholder(theme),
            ),
            const SizedBox(height: 40),

            // Bottom Actions
            AppButton(
              text: 'Export to CSV',
              icon: const Icon(Icons.download_rounded, size: 20),
              onPressed: _exportToCsv,
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyImagePlaceholder(ThemeData theme) {
    return Container(
      height: 200,
      width: double.infinity,
      color: theme.colorScheme.onSurface.withValues(alpha: 0.05),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.image_not_supported_outlined,
              color: theme.colorScheme.onSurfaceVariant, size: 40),
          const SizedBox(height: 12),
          Text(
            'No receipt attached',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}
