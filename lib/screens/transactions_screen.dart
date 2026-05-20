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
import '../widgets/custom_widgets.dart';
import '../widgets/glass_widgets.dart';

class TransactionsScreen extends StatefulWidget {
  const TransactionsScreen({super.key});

  @override
  State<TransactionsScreen> createState() => _TransactionsScreenState();
}

class _TransactionsScreenState extends State<TransactionsScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final bool _isExporting = false;
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _tabController.addListener(_handleTabSelection);
  }

  void _handleTabSelection() {
    if (_tabController.indexIsChanging) {
      _searchController.clear();
      // Reset providers when switching tabs
      context.read<SalesProvider>().resetFilters();
      context.read<ExpenseProvider>().resetFilters();
    }
    setState(() {});
  }

  @override
  void dispose() {
    _tabController.removeListener(_handleTabSelection);
    _tabController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  // ── Expenses Logic ──────────────────────────────────────────────────────


  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isExpenseTab = _tabController.index == 0;

    final String titleTransactions = 'Transactions';
    final String tooltipExport = 'Export CSV';
    final String tabExpenses = 'Expenses';
    final String tabSales = 'Sales';

    return Scaffold(
      appBar: AppBar(
        title: Text(titleTransactions),
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
            tooltip: tooltipExport,
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
      ),
      body: Column(
        children: [
          // Glass Segmented Tabs
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: GlassSegmentedTabs(
              labels: [tabExpenses, tabSales],
              icons: const [Icons.receipt_long_rounded, Icons.point_of_sale_rounded],
              selectedIndex: _tabController.index,
              onChanged: (index) {
                _tabController.animateTo(index);
              },
            ),
          ),

          // Tab Views
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                // 1. Expenses Tab
                Consumer<ExpenseProvider>(
                  builder: (context, provider, _) {
                    if (provider.isLoading) {
                      return const Center(child: CircularProgressIndicator());
                    }

                    final expenses = provider.expenseRecords;

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
                          provider.resetFilters();
                        },
                        child: CustomScrollView(
                          physics: const AlwaysScrollableScrollPhysics(),
                          slivers: [
                            // 1. Unified Hero Card
                            SliverToBoxAdapter(
                              child: _buildExpenseHeroCard(provider),
                            ),

                            // 2. Search & Filter Row
                            SliverToBoxAdapter(
                              child: _buildExpenseSearchAndFilter(provider),
                            ),

                            // 3. Header
                            SliverToBoxAdapter(
                              child: Padding(
                                padding: const EdgeInsets.fromLTRB(16, 24, 16, 8),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(
                                      'RECENT EXPENSES',
                                      style: theme.textTheme.labelLarge?.copyWith(
                                        fontWeight: FontWeight.bold,
                                        color: theme.colorScheme.onSurfaceVariant
                                            .withValues(alpha: 0.6),
                                        letterSpacing: 1.2,
                                      ),
                                    ),
                                    Text(
                                      '${provider.totalFilteredCount} EXPENSES',
                                      style: theme.textTheme.labelLarge?.copyWith(
                                        fontWeight: FontWeight.bold,
                                        color: Colors.orange.shade800,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),

                            // 4. List of Expenses
                            if (expenses.isEmpty)
                              SliverFillRemaining(
                                hasScrollBody: false,
                                child: buildEmptyState(
                                  context,
                                  icon: Icons.receipt_long_rounded,
                                  message: 'No expenses found matching filters',
                                  color: Colors.orange.shade700,
                                ),
                              )
                            else ...[
                              SliverPadding(
                                padding: const EdgeInsets.symmetric(horizontal: 16),
                                sliver: SliverList(
                                  delegate: SliverChildBuilderDelegate(
                                    (context, index) {
                                      return _buildExpenseCard(context, expenses[index]);
                                    },
                                    childCount: expenses.length,
                                  ),
                                ),
                              ),
                              SliverToBoxAdapter(
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(vertical: 32),
                                  child: Center(
                                    child: provider.hasMore
                                        ? const CircularProgressIndicator()
                                        : Text(
                                            'End of results',
                                            style: theme.textTheme.bodySmall?.copyWith(
                                              color: theme.colorScheme.onSurfaceVariant
                                                  .withValues(alpha: 0.5),
                                              letterSpacing: 1.1,
                                            ),
                                          ),
                                  ),
                                ),
                              ),
                              const SliverToBoxAdapter(
                                child: SizedBox(height: 100),
                              ),
                            ],
                          ],
                        ),
                      ),
                    );
                  },
                ),
                // 2. Sales Tab
                Consumer<SalesProvider>(
                  builder: (context, provider, _) {
                    if (provider.isLoading) {
                      return const Center(child: CircularProgressIndicator());
                    }

                    if (provider.error != null) {
                      final String errorMsg = 'Error fetching sales:\n${provider.error}';
                      return Center(
                        child: Padding(
                          padding: const EdgeInsets.all(24.0),
                          child: Text(
                            errorMsg,
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
                          provider.resetFilters();
                        },
                        child: CustomScrollView(
                          physics: const AlwaysScrollableScrollPhysics(),
                          slivers: [
                            // 1. Unified Hero Card
                            SliverToBoxAdapter(
                              child: _buildSalesHeroCard(provider),
                            ),

                            // 2. Pending Consolidation Action Button
                            SliverToBoxAdapter(
                              child: _buildConsolidationButton(
                                context,
                                provider,
                              ),
                            ),

                            // 3. Search & Filter Row
                            SliverToBoxAdapter(
                              child: _buildSalesSearchAndFilter(provider),
                            ),

                            // 4. Recent Sales Header
                            SliverToBoxAdapter(
                              child: Padding(
                                padding: const EdgeInsets.fromLTRB(
                                  16,
                                  24,
                                  16,
                                  8,
                                ),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(
                                      'RECENT SALES',
                                      style: theme.textTheme.labelLarge?.copyWith(
                                        fontWeight: FontWeight.bold,
                                        color: theme.colorScheme.onSurfaceVariant
                                            .withValues(alpha: 0.6),
                                        letterSpacing: 1.2,
                                      ),
                                    ),
                                    Text(
                                      '${provider.totalFilteredCount} SALES',
                                      style: theme.textTheme.labelLarge?.copyWith(
                                        fontWeight: FontWeight.bold,
                                        color: AppTheme.neonGreenDark,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),

                            // 6. List of Sales
                            if (sales.isEmpty)
                              SliverFillRemaining(
                                hasScrollBody: false,
                                child: buildEmptyState(
                                  context,
                                  icon: Icons.point_of_sale_rounded,
                                  message: 'No sales found matching filters',
                                  color: AppTheme.primary,
                                ),
                              )
                            else ...[
                              SliverPadding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                ),
                                sliver: SliverList(
                                  delegate: SliverChildBuilderDelegate((
                                    context,
                                    index,
                                  ) {
                                    return _buildSaleCard(
                                      context,
                                      sales[index],
                                    );
                                  }, childCount: sales.length),
                                ),
                              ),
                              SliverToBoxAdapter(
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 32,
                                  ),
                                  child: Center(
                                    child: provider.hasMore
                                        ? const CircularProgressIndicator()
                                        : Text(
                                            'End of results',
                                            style: theme.textTheme.bodySmall
                                                ?.copyWith(
                                                  color: theme
                                                      .colorScheme
                                                      .onSurfaceVariant
                                                      .withValues(alpha: 0.5),
                                                  letterSpacing: 1.1,
                                                ),
                                          ),
                                  ),
                                ),
                              ),
                              const SliverToBoxAdapter(
                                child: SizedBox(
                                  height: 100,
                                ), // Extra space for FAB
                              ),
                            ],
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

  // ── UI Components ───────────────────────────────────────────────────────

  Widget _buildExpenseCard(BuildContext context, ExpenseRecord expense) {
    final theme = Theme.of(context);
    final dateStr = DateFormat('yyyy-MM-dd').format(expense.date);

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppTheme.radiusLarge),
        side: BorderSide(
          color: theme.colorScheme.outlineVariant.withValues(alpha: 0.3),
        ),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.all(16),
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => ExpenseDetailScreen(expense: expense),
            ),
          );
        },
        leading: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: Colors.orange.shade700.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
          ),
          child: Icon(
            expense.imagePath != null
                ? Icons.receipt_long_rounded
                : Icons.edit_note_rounded,
            color: Colors.orange.shade700,
          ),
        ),
        title: Text(
          expense.vendor.isNotEmpty ? expense.vendor : 'Unknown Vendor',
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        subtitle: Text(
          '$dateStr • ${expense.category}',
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        trailing: Text(
          '-RM ${expense.amount.toStringAsFixed(2)}',
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.bold,
            color: Colors.redAccent,
          ),
        ),
      ),
    );
  }

  // ── Expenses Helpers ──────────────────────────────────────────────────

  Widget _buildExpenseHeroCard(ExpenseProvider provider) {
    final theme = Theme.of(context);
    final totalCount = provider.totalFilteredCount;
    final accentColor = Colors.orange.shade700;
    
    // Calculate category summary for badges
    final Map<String, int> categoryCounts = {};
    for (var exp in provider.allFilteredRecords) {
      categoryCounts[exp.category] = (categoryCounts[exp.category] ?? 0) + 1;
    }
    final sortedCategories = categoryCounts.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final topCategories = sortedCategories.take(3).toList();

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 16, 16, 16),
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            accentColor.withValues(alpha: 0.15),
            accentColor.withValues(alpha: 0.05),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(AppTheme.radiusXLarge),
        border: Border.all(
          color: accentColor.withValues(alpha: 0.3),
        ),
        boxShadow: [
          BoxShadow(
            color: accentColor.withValues(alpha: 0.05),
            blurRadius: 20,
            spreadRadius: -5,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      provider.startDate != null && provider.endDate != null
                          ? 'TOTAL EXPENSES (${DateFormat('d MMM').format(provider.startDate!)} - ${DateFormat('d MMM').format(provider.endDate!)})'
                          : 'TOTAL EXPENSES (THIS MONTH)',
                      style: theme.textTheme.labelMedium?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                        letterSpacing: 1.1,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'RM ${provider.filteredExpensesTotal.toStringAsFixed(2)}',
                      style: theme.textTheme.headlineLarge?.copyWith(
                        fontWeight: FontWeight.w800,
                        color: accentColor,
                        letterSpacing: -1,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: theme.colorScheme.surface,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: accentColor.withValues(alpha: 0.2),
                      blurRadius: 12,
                      spreadRadius: 2,
                    ),
                  ],
                ),
                child: Icon(
                  Icons.trending_down_rounded,
                  size: 28,
                  color: accentColor,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Divider(color: accentColor.withValues(alpha: 0.1), height: 1),
          const SizedBox(height: 16),
          Text(
            'CATEGORY SUMMARY',
            style: theme.textTheme.labelSmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.7),
              fontWeight: FontWeight.bold,
              letterSpacing: 1,
            ),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _buildSimpleBadge('$totalCount Transactions', accentColor),
              ...topCategories.map((cat) => _buildSimpleBadge('${cat.key}: ${cat.value}', Colors.grey.shade600)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildExpenseSearchAndFilter(ExpenseProvider provider) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          Expanded(
            child: GlassSearchBar(
              controller: _searchController,
              hintText: 'Search vendor or category',
              onChanged: (val) {
                provider.setSearchQuery(val);
                setState(() {});
              },
              onClear: () {
                _searchController.clear();
                provider.setSearchQuery('');
                setState(() {});
              },
            ),
          ),
          const SizedBox(width: 12),
          GlassContainer(
            borderRadius: AppTheme.radiusLarge,
            child: IconButton(
              icon: Icon(
                provider.startDate != null
                    ? Icons.date_range_rounded
                    : Icons.calendar_month_rounded,
                color: provider.startDate != null ? Colors.orange.shade700 : null,
              ),
              onPressed: () async {
                final range = await showDateRangePicker(
                  context: context,
                  firstDate: DateTime(2024),
                  lastDate: DateTime.now().add(const Duration(days: 365)),
                  initialDateRange:
                      provider.startDate != null && provider.endDate != null
                          ? DateTimeRange(
                              start: provider.startDate!,
                              end: provider.endDate!,
                            )
                          : null,
                );
                if (range != null) {
                  provider.setDateRange(range.start, range.end);
                }
              },
            ),
          ),
          if (provider.startDate != null) ...[
            const SizedBox(width: 8),
            GlassContainer(
              borderRadius: AppTheme.radiusLarge,
              tintColor: Colors.redAccent.withValues(alpha: 0.15),
              child: IconButton(
                icon: const Icon(Icons.clear_rounded, color: Colors.redAccent, size: 20),
                onPressed: () => provider.setDateRange(null, null),
                tooltip: 'Clear Date Filter',
              ),
            ),
          ],
        ],
      ),
    );
  }

  // ── Sales Helpers ───────────────────────────────────────────────────────

  Widget _buildSalesHeroCard(SalesProvider provider) {
    final theme = Theme.of(context);
    final accentColor = AppTheme.neonGreenDark;
    
    final pendingPayment = provider.getStatusCount(commStatus: CommercialStatus.pendingPayment);
    final paid = provider.getStatusCount(commStatus: CommercialStatus.paid);
    final pendingConsolidation = provider.getStatusCount(compStatus: ComplianceStatus.pendingConsolidation);
    final valid = provider.getStatusCount(compStatus: ComplianceStatus.valid);

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 16, 16, 16),
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            accentColor.withValues(alpha: 0.15),
            accentColor.withValues(alpha: 0.05),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(AppTheme.radiusXLarge),
        border: Border.all(
          color: accentColor.withValues(alpha: 0.3),
        ),
        boxShadow: [
          BoxShadow(
            color: accentColor.withValues(alpha: 0.05),
            blurRadius: 20,
            spreadRadius: -5,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      provider.startDate != null && provider.endDate != null
                          ? 'TOTAL SALES (${DateFormat('d MMM').format(provider.startDate!)} - ${DateFormat('d MMM').format(provider.endDate!)})'
                          : 'TOTAL SALES (THIS MONTH)',
                      style: theme.textTheme.labelMedium?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                        letterSpacing: 1.1,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'RM ${provider.filteredSalesTotal.toStringAsFixed(2)}',
                      style: theme.textTheme.headlineLarge?.copyWith(
                        fontWeight: FontWeight.w800,
                        color: accentColor,
                        letterSpacing: -1,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: theme.colorScheme.surface,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: accentColor.withValues(alpha: 0.2),
                      blurRadius: 12,
                      spreadRadius: 2,
                    ),
                  ],
                ),
                child: Icon(
                  Icons.auto_graph_rounded,
                  size: 28,
                  color: accentColor,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Divider(color: accentColor.withValues(alpha: 0.1), height: 1),
          const SizedBox(height: 16),
          Text(
            'STATUS BREAKDOWN',
            style: theme.textTheme.labelSmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.7),
              fontWeight: FontWeight.bold,
              letterSpacing: 1,
            ),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _buildSimpleBadge('$pendingPayment Pending Pay', Colors.orange),
              _buildSimpleBadge('$paid Paid', AppTheme.neonGreenDark),
              _buildSimpleBadge('$pendingConsolidation Unconsolidated', Colors.purple),
              _buildSimpleBadge('$valid Validated', AppTheme.neonGreenDark),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSimpleBadge(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(AppTheme.radiusLarge),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 11,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.2,
        ),
      ),
    );
  }

  Widget _buildConsolidationButton(
    BuildContext context,
    SalesProvider provider,
  ) {
    final count = provider.pendingConsolidationRecords.length;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
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
          label: Text('Process Consolidation ($count Items)'),
          style: ElevatedButton.styleFrom(
            backgroundColor: AppTheme.primary,
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppTheme.radiusLarge),
            ),
            elevation: 2,
          ),
        ),
      ),
    );
  }



  Widget _buildSalesSearchAndFilter(SalesProvider provider) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          Expanded(
            child: GlassSearchBar(
              controller: _searchController,
              hintText: 'Search by item or customer',
              onChanged: (val) {
                provider.setSearchQuery(val);
                setState(() {});
              },
              onClear: () {
                _searchController.clear();
                provider.setSearchQuery('');
                setState(() {});
              },
            ),
          ),
          const SizedBox(width: 12),
          GlassContainer(
            borderRadius: AppTheme.radiusLarge,
            child: IconButton(
              icon: Icon(
                provider.startDate != null
                    ? Icons.date_range_rounded
                    : Icons.calendar_month_rounded,
                color: provider.startDate != null ? AppTheme.primary : null,
              ),
              onPressed: () async {
                final range = await showDateRangePicker(
                  context: context,
                  firstDate: DateTime(2024),
                  lastDate: DateTime.now().add(const Duration(days: 365)),
                  initialDateRange:
                      provider.startDate != null && provider.endDate != null
                          ? DateTimeRange(
                            start: provider.startDate!,
                            end: provider.endDate!,
                          )
                          : null,
                );
                if (range != null) {
                  provider.setDateRange(range.start, range.end);
                }
              },
            ),
          ),
          if (provider.startDate != null) ...[
            const SizedBox(width: 8),
            GlassContainer(
              borderRadius: AppTheme.radiusLarge,
              tintColor: Colors.redAccent.withValues(alpha: 0.15),
              child: IconButton(
                icon: const Icon(Icons.clear_rounded, color: Colors.redAccent, size: 20),
                onPressed: () => provider.setDateRange(null, null),
                tooltip: 'Clear Date Filter',
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildSaleCard(BuildContext context, SaleRecord sale) {
    final theme = Theme.of(context);
    final dateStr = DateFormat('MMM dd, HH:mm').format(sale.saleDate);

    final commColor = sale.commercialStatus == CommercialStatus.paid
        ? AppTheme.neonGreenDark
        : Colors.orange;

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
        side: BorderSide(
          color: theme.colorScheme.outlineVariant.withValues(alpha: 0.3),
        ),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.all(16),
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => SaleDetailScreen(sale: sale)),
        ),
        leading: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: AppTheme.primary.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
          ),
          child: const Icon(Icons.restaurant_rounded, color: AppTheme.primary),
        ),
        title: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Text(
                sale.lineItems.isEmpty
                    ? 'Sale'
                    : sale.lineItems.first.item.name,
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            Text(
              'RM ${sale.totalPayable.toStringAsFixed(2)}',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 4),
            Text(
              '$dateStr • ${sale.customerName}',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                _buildMiniStatusBadge(
                  sale.commercialStatus.label.toUpperCase(),
                  commColor,
                ),
                const SizedBox(width: 8),
                _buildMiniStatusBadge(
                  sale.complianceStatus.label.toUpperCase(),
                  compColor,
                ),
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
        style: TextStyle(
          color: color,
          fontSize: 9,
          fontWeight: FontWeight.bold,
          letterSpacing: 0.5,
        ),
      ),
    );
  }
}
