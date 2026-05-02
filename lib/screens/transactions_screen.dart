import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:csv/csv.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import '../core/app_theme.dart';
import '../models/expense_record.dart';
import '../providers/expense_provider.dart';
import '../widgets/app_dialogs.dart';
import 'expenses/expense_detail_screen.dart';

class TransactionsScreen extends StatefulWidget {
  const TransactionsScreen({super.key});

  @override
  State<TransactionsScreen> createState() => _TransactionsScreenState();
}

class _TransactionsScreenState extends State<TransactionsScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  int _selectedFilterIndex = 0; // 0: All, 1: 7 Days, 2: 30 Days
  bool _isExporting = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _tabController.addListener(_handleTabSelection);
  }

  void _handleTabSelection() {
    setState(() {});
  }

  @override
  void dispose() {
    _tabController.removeListener(_handleTabSelection);
    _tabController.dispose();
    super.dispose();
  }

  // ── Filtering Logic ─────────────────────────────────────────────────────

  List<ExpenseRecord> _applyFilter(List<ExpenseRecord> expenses) {
    final now = DateTime.now();
    switch (_selectedFilterIndex) {
      case 1: // Last 7 Days
        final cutoff = now.subtract(const Duration(days: 7));
        return expenses.where((e) => e.date.isAfter(cutoff)).toList();
      case 2: // Last 30 Days
        final cutoff = now.subtract(const Duration(days: 30));
        return expenses.where((e) => e.date.isAfter(cutoff)).toList();
      default: // All Time
        return expenses;
    }
  }

  double _calculateTotal(List<ExpenseRecord> expenses) {
    return expenses.fold(0.0, (sum, item) => sum + item.amount);
  }

  // ── CSV Export (Digital Shoebox) ─────────────────────────────────────────

  Future<void> _exportToCSV(List<ExpenseRecord> expenses) async {
    if (expenses.isEmpty) {
      AppDialogs.showActionModal(
        context,
        title: 'No Data to Export',
        body: 'There are no expense records to export. Add some expenses first.',
        primaryButtonText: 'OK',
        onPrimaryPressed: () {},
        icon: Icons.info_outline_rounded,
        iconColor: AppTheme.primary,
        primaryButtonColor: AppTheme.primary,
      );
      return;
    }

    setState(() => _isExporting = true);

    try {
      // 1. Build CSV rows (Improved the 'Receipt Attached' column)
      final List<List<dynamic>> rows = [
        ['Date', 'Vendor', 'Category', 'Amount (RM)', 'Receipt Path'],
        ...expenses.map((e) => [
          '${e.date.year}-${e.date.month.toString().padLeft(2, '0')}-${e.date.day.toString().padLeft(2, '0')}',
          e.vendor,
          e.category,
          e.amount.toStringAsFixed(2),
          e.imagePath ?? 'No Receipt', // Outputs the actual path instead of just 'Yes'
        ]),
        [],
        ['', '', 'TOTAL', _calculateTotal(expenses).toStringAsFixed(2), ''],
        // Cleaned up the generation timestamp using standard ISO 8601
        ['', '', 'Generated', DateTime.now().toIso8601String().split('T')[0], ''], 
      ];

      final csvString = const ListToCsvConverter().convert(rows);

      // 2. Better File Naming (e.g., MyRekod_Expenses_2026-05-02.csv)
      final appDir = await getApplicationDocumentsDirectory();
      // Using a human-readable date format for the filename
      final dateStr = DateTime.now().toIso8601String().split('T')[0]; 
      final fileName = 'MyRekod_Expenses_$dateStr.csv';
      final file = File('${appDir.path}/$fileName');
      await file.writeAsString(csvString);

      if (!mounted) return;
      setState(() => _isExporting = false);

      // 3. Fix the double-file export bug by removing the 'text:' parameter
      final box = context.findRenderObject() as RenderBox?;
      await Share.shareXFiles(
        [XFile(file.path)],
        subject: 'MyRekod Expense Report - $dateStr', // Used for email subject lines
        sharePositionOrigin: box != null ? box.localToGlobal(Offset.zero) & box.size : null,
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _isExporting = false);

      AppDialogs.showActionModal(
        context,
        title: 'Export Failed',
        body: 'Could not generate CSV file.\n\nError: $e',
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
    final isExpenseTab = _tabController.index == 0;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Transactions'),
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          if (isExpenseTab)
            IconButton(
              icon: _isExporting
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.file_download_outlined),
              tooltip: 'Export CSV',
              onPressed: _isExporting
                  ? null
                  : () {
                      final expenses = _applyFilter(
                        context.read<ExpenseProvider>().expenses,
                      );
                      _exportToCSV(expenses);
                    },
            ),
        ],
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: AppTheme.primary,
          labelColor: AppTheme.primary,
          unselectedLabelColor: theme.colorScheme.onSurfaceVariant,
          tabs: const [
            Tab(text: 'Expenses'),
            Tab(text: 'Sales'),
          ],
        ),
      ),
      body: Column(
        children: [
          // Filter Chips
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 16.0),
            child: Row(
              children: [
                _buildFilterChip('All Time', 0),
                const SizedBox(width: 8),
                _buildFilterChip('Last 7 Days', 1),
                const SizedBox(width: 8),
                _buildFilterChip('Last 30 Days', 2),
              ],
            ),
          ),
          
          // Summary Cards (uses real data for Expenses)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: isExpenseTab
                ? Consumer<ExpenseProvider>(
                    builder: (context, provider, _) {
                      final filteredExpenses = _applyFilter(provider.expenses);
                      final total = _calculateTotal(filteredExpenses);
                      return _buildSummaryCard(
                        title: 'Total Expenses',
                        amount: 'RM ${total.toStringAsFixed(2)}',
                        color: Colors.orange.shade700,
                        icon: Icons.trending_down_rounded,
                      );
                    },
                  )
                : _buildSummaryCard(
                    // TODO: Wire up SalesProvider when implemented
                    title: 'Total Sales',
                    amount: 'RM 0.00',
                    color: AppTheme.primary,
                    icon: Icons.trending_up_rounded,
                  ),
          ),
          const SizedBox(height: 16),

          // Tab Views
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                // Expenses Tab — real data
                Consumer<ExpenseProvider>(
                  builder: (context, provider, _) {
                    if (provider.isLoading) {
                      return const Center(child: CircularProgressIndicator());
                    }

                    final filteredExpenses = _applyFilter(provider.expenses);

                    if (filteredExpenses.isEmpty) {
                      return _buildEmptyState(
                        icon: Icons.receipt_long_rounded,
                        message: 'No expenses recorded yet',
                        color: Colors.orange.shade700,
                      );
                    }

                    return _buildExpenseList(filteredExpenses);
                  },
                ),
                // Sales Tab — placeholder
                _buildSalesList(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChip(String label, int index) {
    final isSelected = _selectedFilterIndex == index;
    return ChoiceChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (selected) {
        if (selected) {
          setState(() => _selectedFilterIndex = index);
        }
      },
      selectedColor: AppTheme.primary.withValues(alpha: 0.15),
      backgroundColor: Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppTheme.radiusLarge),
        side: BorderSide(
          color: isSelected ? AppTheme.primary : Theme.of(context).colorScheme.outlineVariant,
        ),
      ),
      labelStyle: TextStyle(
        color: isSelected ? AppTheme.primary : Theme.of(context).colorScheme.onSurfaceVariant,
        fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
      ),
    );
  }

  Widget _buildSummaryCard({
    required String title,
    required String amount,
    required Color color,
    required IconData icon,
  }) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            color.withValues(alpha: 0.15),
            color.withValues(alpha: 0.05),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(AppTheme.radiusXLarge),
        border: Border.all(color: color.withValues(alpha: 0.3)),
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: 0.05),
            blurRadius: 20,
            spreadRadius: -5,
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surface,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: color.withValues(alpha: 0.2),
                  blurRadius: 8,
                  spreadRadius: 1,
                ),
              ],
            ),
            child: Icon(icon, color: color, size: 28),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  amount,
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w800,
                    color: color,
                    letterSpacing: -0.5,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState({
    required IconData icon,
    required String message,
    required Color color,
  }) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(48.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, size: 48, color: color.withValues(alpha: 0.5)),
            ),
            const SizedBox(height: 20),
            Text(
              // TODO: Implement i18n
              message,
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildExpenseList(List<ExpenseRecord> expenses) {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: expenses.length,
      itemBuilder: (context, index) {
        final expense = expenses[index];
        final dateStr = '${expense.date.year}-'
            '${expense.date.month.toString().padLeft(2, '0')}-'
            '${expense.date.day.toString().padLeft(2, '0')}';
        
        return Card(
          margin: const EdgeInsets.only(bottom: 12),
          child: ListTile(
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => ExpenseDetailScreen(expense: expense),
                ),
              );
            },
            leading: CircleAvatar(
              backgroundColor: Colors.orange.shade700.withValues(alpha: 0.2),
              child: Icon(
                expense.imagePath != null
                    ? Icons.receipt_long_rounded
                    : Icons.edit_note_rounded,
                color: Colors.orange.shade700,
              ),
            ),
            title: Text(
              expense.vendor.isNotEmpty ? expense.vendor : 'Unknown Vendor',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            subtitle: Text(
              '$dateStr • ${expense.category}',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
            trailing: Text(
              '-RM ${expense.amount.toStringAsFixed(2)}',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
                color: Colors.redAccent,
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildSalesList() {
    // Placeholder until Sales module is implemented
    return _buildEmptyState(
      icon: Icons.point_of_sale_rounded,
      message: 'Sales tracking coming soon',
      color: AppTheme.primary,
    );
  }
}
