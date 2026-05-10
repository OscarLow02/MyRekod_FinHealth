import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../core/app_theme.dart';
import '../models/expense_record.dart';
import '../models/sale_record.dart';
import '../providers/expense_provider.dart';
import '../providers/sales_provider.dart';
import 'transactions/widgets/export_filter_bottom_sheet.dart';
import 'expenses/expense_detail_screen.dart';
import 'sales/sale_detail_screen.dart';
import 'sales/consolidation_screen.dart';

class TransactionsScreen extends StatefulWidget {
  const TransactionsScreen({super.key});

  @override
  State<TransactionsScreen> createState() => _TransactionsScreenState();
}

class _TransactionsScreenState extends State<TransactionsScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  int _selectedFilterIndex = 0; // 0: All, 1: 7 Days, 2: 30 Days
  bool _isExporting = false;
  final TextEditingController _searchController = TextEditingController();

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


  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isExpenseTab = _tabController.index == 0;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Transactions'),
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
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
                    showModalBottomSheet(
                      context: context,
                      isScrollControlled: true,
                      builder: (context) => ExportFilterBottomSheet(
                        exportType: isExpenseTab
                            ? ExportType.expenses
                            : ExportType.sales,
                      ),
                    );
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
                : Consumer<SalesProvider>(
                    builder: (context, provider, _) {
                      final filteredSales = _applySalesFilter(provider.saleRecords);
                      final total = _calculateSalesTotal(filteredSales);
                      return _buildSummaryCard(
                        title: 'Total Sales',
                        amount: 'RM ${total.toStringAsFixed(2)}',
                        color: AppTheme.primary,
                        icon: Icons.trending_up_rounded,
                      );
                    },
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
                // Sales Tab — Refactored to match Monthly Summary Mockup
                Consumer<SalesProvider>(
                  builder: (context, provider, _) {
                    if (provider.isLoading) {
                      return const Center(child: CircularProgressIndicator());
                    }

                    if (provider.error != null) {
                      return Center(
                        child: Padding(
                          padding: const EdgeInsets.all(24.0),
                          child: Text(
                            'Error fetching sales:\n${provider.error}',
                            style: const TextStyle(color: Colors.red),
                            textAlign: TextAlign.center,
                          ),
                        ),
                      );
                    }

                    final sales = provider.saleRecords;

                    return NotificationListener<ScrollNotification>(
                      onNotification: (ScrollNotification scrollInfo) {
                        if (scrollInfo.metrics.pixels >=
                            scrollInfo.metrics.maxScrollExtent - 200) {
                          provider.loadMore();
                        }
                        return true;
                      },
                      child: RefreshIndicator(
                        onRefresh: () async {
                          // Handled by Firestore stream
                        },
                        child: CustomScrollView(
                          physics: const AlwaysScrollableScrollPhysics(),
                          slivers: [
                            // 1. Total Sales Summary (Mockup Style)
                            SliverToBoxAdapter(
                              child: _buildSalesMonthlySummary(provider),
                            ),

                            // 2. LHDN Consolidation Rules Info Box
                            SliverToBoxAdapter(
                              child: _buildConsolidationRulesInfo(),
                            ),

                            // 3. Pending Consolidation Button
                            SliverToBoxAdapter(
                              child: _buildConsolidationButton(context, provider),
                            ),

                            // 4. Search & Filter Row
                            SliverToBoxAdapter(
                              child: _buildSalesSearchAndFilter(provider),
                            ),

                            // 5. Recent Sales Header
                            SliverToBoxAdapter(
                              child: Padding(
                                padding:
                                    const EdgeInsets.fromLTRB(16, 24, 16, 8),
                                child: Text(
                                  'RECENT SALES',
                                  style: Theme.of(context)
                                      .textTheme
                                      .labelLarge
                                      ?.copyWith(
                                        fontWeight: FontWeight.bold,
                                        color: Theme.of(context)
                                            .colorScheme
                                            .onSurfaceVariant
                                            .withValues(alpha: 0.6),
                                        letterSpacing: 1.2,
                                      ),
                                ),
                              ),
                            ),

                            // 6. List of Sales
                            if (sales.isEmpty)
                              SliverFillRemaining(
                                hasScrollBody: false,
                                child: _buildEmptyState(
                                  icon: Icons.point_of_sale_rounded,
                                  message: 'No sales found matching filters',
                                  color: AppTheme.primary,
                                ),
                              )
                            else
                              SliverPadding(
                                padding: const EdgeInsets.fromLTRB(
                                    16, 0, 16, 100), // Extra space for FAB
                                sliver: SliverList(
                                  delegate: SliverChildBuilderDelegate(
                                    (context, index) {
                                      return _buildSaleCard(
                                          context, sales[index]);
                                    },
                                    childCount: sales.length,
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
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

  // ── Sales Refactored UI Helpers ──────────────────────────────────────────

  Widget _buildSalesMonthlySummary(SalesProvider provider) {
    final theme = Theme.of(context);
    final total = provider.totalSales; // Total this month
    final pendingCount = provider.pendingConsolidationRecords.length;
    final clearedCount = provider.saleRecords.where((s) => s.complianceStatus == ComplianceStatus.valid).length;

    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(AppTheme.radiusXLarge),
        border: Border.all(color: theme.colorScheme.outlineVariant.withValues(alpha: 0.5)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'TOTAL SALES THIS MONTH',
                    style: theme.textTheme.labelMedium?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                      letterSpacing: 1.1,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'RM ${total.toStringAsFixed(2)}',
                    style: theme.textTheme.headlineLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: AppTheme.primary,
                    ),
                  ),
                ],
              ),
              Icon(Icons.auto_graph_rounded, size: 48, color: AppTheme.primary.withValues(alpha: 0.2)),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              _buildSimpleBadge('• $pendingCount Un-invoiced', Colors.orange),
              const SizedBox(width: 8),
              _buildSimpleBadge('• $clearedCount Cleared', AppTheme.neonGreenDark),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSimpleBadge(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Text(
        label,
        style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.w600),
      ),
    );
  }

  Widget _buildConsolidationRulesInfo() {
    final theme = Theme.of(context);
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.blue.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(AppTheme.radiusLarge),
        border: const Border(left: BorderSide(color: Colors.blue, width: 4)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.info_outline_rounded, color: Colors.blue, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'LHDN Consolidation Rules',
                  style: TextStyle(fontWeight: FontWeight.bold, color: Colors.blue),
                ),
                const SizedBox(height: 4),
                Text(
                  'Ensure all sales above RM500 are individually invoiced. Smaller items can be consolidated monthly. Review un-invoiced items carefully.',
                  style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildConsolidationButton(BuildContext context, SalesProvider provider) {
    final count = provider.pendingConsolidationRecords.length;
    return Padding(
      padding: const EdgeInsets.all(16),
      child: SizedBox(
        width: double.infinity,
        height: 56,
        child: ElevatedButton.icon(
          onPressed: () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const ConsolidationScreen()),
            );
          },
          icon: const Icon(Icons.fact_check_rounded),
          label: Text('Pending Consolidation ($count Items)'),
          style: ElevatedButton.styleFrom(
            backgroundColor: AppTheme.primary,
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppTheme.radiusLarge)),
            elevation: 2,
          ),
        ),
      ),
    );
  }

  Widget _buildSalesSearchAndFilter(SalesProvider provider) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _searchController,
              onChanged: (val) => provider.setSearchQuery(val),
              decoration: InputDecoration(
                hintText: 'Search by item or customer',
                prefixIcon: const Icon(Icons.search_rounded),
                filled: true,
                fillColor: Theme.of(context).colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(AppTheme.radiusLarge),
                  borderSide: BorderSide.none,
                ),
                contentPadding: const EdgeInsets.symmetric(vertical: 0),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Container(
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
              borderRadius: BorderRadius.circular(AppTheme.radiusLarge),
            ),
            child: IconButton(
              icon: Icon(
                provider.filterDate != null ? Icons.calendar_today_rounded : Icons.calendar_month_rounded,
                color: provider.filterDate != null ? AppTheme.primary : null,
              ),
              onPressed: () async {
                final date = await showDatePicker(
                  context: context,
                  initialDate: provider.filterDate ?? DateTime.now(),
                  firstDate: DateTime(2023),
                  lastDate: DateTime.now(),
                );
                provider.setFilterDate(date);
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSaleCard(BuildContext context, SaleRecord sale) {
    final theme = Theme.of(context);
    final dateStr = DateFormat('MMM dd, HH:mm').format(sale.saleDate);

    // Commercial Status (Payment)
    final commColor = sale.commercialStatus == CommercialStatus.paid ? AppTheme.neonGreenDark : Colors.orange;
    
    // Compliance Status (LHDN)
    final compColor = switch (sale.complianceStatus) {
      ComplianceStatus.valid => AppTheme.neonGreenDark,
      ComplianceStatus.pendingSubmission => Colors.orange,
      ComplianceStatus.pendingConsolidation => Colors.purple,
      ComplianceStatus.invalid => Colors.red,
    };

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppTheme.radiusLarge),
        side: BorderSide(color: theme.colorScheme.outlineVariant.withValues(alpha: 0.3)),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.all(16),
        onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => SaleDetailScreen(sale: sale))),
        leading: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: AppTheme.primary.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
          ),
          child: const Icon(Icons.restaurant_rounded, color: AppTheme.primary), // Icon based on mockup
        ),
        title: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Text(
                sale.lineItems.isEmpty ? 'Sale' : sale.lineItems.first.item.name,
                style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            Text(
              'RM ${sale.totalPayable.toStringAsFixed(2)}',
              style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
            ),
          ],
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 4),
            Text(
              '$dateStr • ${sale.customerName}',
              style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                _buildMiniStatusBadge(sale.commercialStatus.label.toUpperCase(), commColor),
                const SizedBox(width: 8),
                _buildMiniStatusBadge(sale.complianceStatus.label.toUpperCase(), compColor),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMiniStatusBadge(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        label,
        style: TextStyle(color: color, fontSize: 9, fontWeight: FontWeight.bold, letterSpacing: 0.5),
      ),
    );
  }

  // ── Legacy Helpers (keep for Expenses or clean up if unused) ────────────────
  


  // ── Sales Filtering Logic ─────────────────────────────────────────────────

  List<SaleRecord> _applySalesFilter(List<SaleRecord> sales) {
    final now = DateTime.now();
    switch (_selectedFilterIndex) {
      case 1: // Last 7 Days
        final cutoff = now.subtract(const Duration(days: 7));
        return sales.where((s) => s.saleDate.isAfter(cutoff)).toList();
      case 2: // Last 30 Days
        final cutoff = now.subtract(const Duration(days: 30));
        return sales.where((s) => s.saleDate.isAfter(cutoff)).toList();
      default: // All Time
        return sales;
    }
  }

  double _calculateSalesTotal(List<SaleRecord> sales) {
    return sales.fold(0.0, (sum, r) => sum + r.totalPayable);
  }
}
