import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:provider/provider.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../core/app_theme.dart';
import '../models/sale_record.dart';
import '../models/expense_record.dart';
import '../providers/dashboard_provider.dart';
import '../widgets/cashflow_chart.dart'; // For ChartPeriod enum
import '../widgets/custom_dropdown.dart';

/// A premium analytics screen that displays cash flow trends using a
/// segmented toggle for time periods (Daily, Weekly, Monthly), a high-fidelity
/// [LineChart], and a recent transactions list.
///
/// Consumes [DashboardProvider] for all chart data and financial summaries.
class CashflowAnalysisScreen extends StatefulWidget {
  const CashflowAnalysisScreen({super.key});

  @override
  State<CashflowAnalysisScreen> createState() =>
      _CashflowAnalysisScreenState();
}

class _CashflowAnalysisScreenState extends State<CashflowAnalysisScreen> {
  ChartPeriod _selectedPeriod = ChartPeriod.daily;
  int _selectedMonth = DateTime.now().month;
  int _selectedYear = DateTime.now().year;
  final Set<String> _expandedPeriods = {};

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _fetchData();
    });
  }

  void _fetchData() {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      context.read<DashboardProvider>().fetchChartData(
            user.uid,
            _selectedPeriod,
            _selectedMonth,
            _selectedYear,
          );
    }
  }

  void _onPeriodChanged(ChartPeriod period) {
    if (_selectedPeriod == period) return;
    setState(() => _selectedPeriod = period);
    _fetchData();
  }

  void _onMonthChanged(int? month) {
    if (month == null || month == _selectedMonth) return;
    setState(() => _selectedMonth = month);
    _fetchData();
  }

  void _onYearChanged(int? year) {
    if (year == null || year == _selectedYear) return;
    setState(() => _selectedYear = year);
    _fetchData();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    const pageTitle = 'Cash Flow Analysis';

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text(pageTitle),
        centerTitle: true,
      ),
      body: Consumer<DashboardProvider>(
        builder: (context, dashProv, _) {
          return SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 40),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ── Segmented Period Selector ────────────────────────────
                _buildPeriodSelector(theme),
                const SizedBox(height: 16),

                // ── Date Filters ─────────────────────────────────────────
                _buildFilters(theme),
                const SizedBox(height: 24),

                // ── Summary Row ─────────────────────────────────────────
                _buildSummaryRow(theme, dashProv),
                const SizedBox(height: 24),

                // ── Line Chart ──────────────────────────────────────────
                _buildChartCard(theme, dashProv),
                const SizedBox(height: 28),

                // ── Recent Transactions ─────────────────────────────────
                _buildRecentTransactionsSection(theme, dashProv),
              ],
            ),
          );
        },
      ),
    );
  }

  // ── Period Toggle ─────────────────────────────────────────────────────────
  Widget _buildPeriodSelector(ThemeData theme) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: AppTheme.darkSurfaceContainer,
        borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
      ),
      child: Row(
        children: ChartPeriod.values.map((period) {
          final isActive = _selectedPeriod == period;
          final label = period.name[0].toUpperCase() + period.name.substring(1);
          return Expanded(
            child: GestureDetector(
              onTap: () => _onPeriodChanged(period),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                curve: Curves.easeInOut,
                height: AppTheme.minTouchTarget - 8,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: isActive
                      ? theme.colorScheme.primary
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(AppTheme.radiusSmall),
                  boxShadow: isActive
                      ? [
                          BoxShadow(
                            color: theme.colorScheme.primary
                                .withValues(alpha: 0.3),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ]
                      : null,
                ),
                child: Text(
                  label,
                  style: theme.textTheme.labelLarge?.copyWith(
                    color: isActive
                        ? theme.colorScheme.onPrimary
                        : theme.colorScheme.onSurfaceVariant,
                    fontWeight:
                        isActive ? FontWeight.w700 : FontWeight.w500,
                  ),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  // ── Filters Row ───────────────────────────────────────────────────────────
  Widget _buildFilters(ThemeData theme) {
    final isMonthly = _selectedPeriod == ChartPeriod.monthly;
    final currentYear = DateTime.now().year;
    final years = List.generate(5, (i) => currentYear - i);

    final months = [
      for (int i = 1; i <= 12; i++)
        CustomDropdownItem<int>(label: _monthAbbr(i), value: i)
    ];

    final yearItems = [
      for (final y in years)
        CustomDropdownItem<int>(label: y.toString(), value: y)
    ];

    return Row(
      children: [
        if (!isMonthly) ...[
          Expanded(
            child: CustomPremiumDropdown<int>(
              label: '',
              hint: 'Month',
              items: months,
              value: _selectedMonth,
              onChanged: _onMonthChanged,
              fillColor: AppTheme.darkSurfaceContainer,
            ),
          ),
          const SizedBox(width: 12),
        ],
        Expanded(
          child: CustomPremiumDropdown<int>(
            label: '',
            hint: 'Year',
            items: yearItems,
            value: _selectedYear,
            onChanged: _onYearChanged,
            fillColor: AppTheme.darkSurfaceContainer,
          ),
        ),
      ],
    );
  }

  // ── Summary Cards Row ─────────────────────────────────────────────────────
  Widget _buildSummaryRow(ThemeData theme, DashboardProvider dashProv) {
    // Calculate total from chart spots
    final salesSpots = dashProv.getChartSalesSpots(_selectedPeriod);
    final expenseSpots = dashProv.getChartExpenseSpots(_selectedPeriod);
    
    final totalSales = salesSpots.fold(0.0, (sum, spot) => sum + spot.y);
    final totalExpenses = expenseSpots.fold(0.0, (sum, spot) => sum + spot.y);

    return Row(
      children: [
        Expanded(
          child: _buildSummaryTile(
            theme,
            label: 'Total Sales',
            value: totalSales,
            color: AppTheme.neonGreenDark,
            icon: Icons.trending_up_rounded,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _buildSummaryTile(
            theme,
            label: 'Total Expenses',
            value: totalExpenses,
            color: Colors.redAccent,
            icon: Icons.trending_down_rounded,
          ),
        ),
      ],
    );
  }

  Widget _buildSummaryTile(
    ThemeData theme, {
    required String label,
    required double value,
    required Color color,
    required IconData icon,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.darkSurfaceContainer,
        borderRadius: BorderRadius.circular(AppTheme.radiusLarge),
        border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, color: color, size: 18),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  label,
                  style: theme.textTheme.labelMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            'RM ${value.toStringAsFixed(2)}',
            style: theme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.w700,
              color: Colors.white,
            ),
          ),
        ],
      ),
    );
  }

  // ── Chart Card ────────────────────────────────────────────────────────────
  Widget _buildChartCard(ThemeData theme, DashboardProvider dashProv) {
    if (dashProv.isChartLoading) {
      return Container(
        height: 300,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: AppTheme.darkSurfaceContainer,
          borderRadius: BorderRadius.circular(AppTheme.radiusXLarge),
        ),
        child: const CircularProgressIndicator(),
      );
    }

    final salesSpots = dashProv.getChartSalesSpots(_selectedPeriod);
    final expenseSpots = dashProv.getChartExpenseSpots(_selectedPeriod);
    final allSpots = [...salesSpots, ...expenseSpots];

    // Explicitly calculate axis limits to prevent fl_chart estimation glitches
    double minX = 1;
    double maxX = 1;
    if (_selectedPeriod == ChartPeriod.daily) {
      maxX = DateTime(_selectedYear, _selectedMonth + 1, 0).day.toDouble();
    } else if (_selectedPeriod == ChartPeriod.weekly) {
      DateTime lastDay = DateTime(_selectedYear, _selectedMonth + 1, 0);
      int weekOfMonth = 1;
      DateTime temp = DateTime(_selectedYear, _selectedMonth, 1);
      while (temp.isBefore(lastDay) || temp.isAtSameMomentAs(lastDay)) {
        if (temp.weekday == DateTime.monday && temp.day > 1) {
          weekOfMonth++;
        }
        temp = temp.add(const Duration(days: 1));
      }
      maxX = weekOfMonth.toDouble();
    } else {
      maxX = 12;
    }

    double minY = 0;
    double maxY = 100;
    if (allSpots.isNotEmpty) {
      final dataMaxY = allSpots.map((s) => s.y).reduce(math.max);
      maxY = dataMaxY > 0 ? dataMaxY * 1.2 : 100;
    }

    return Container(
      padding: const EdgeInsets.fromLTRB(12, 24, 16, 12),
      decoration: BoxDecoration(
        color: AppTheme.darkSurfaceContainer,
        borderRadius: BorderRadius.circular(AppTheme.radiusXLarge),
        border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.2),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Legend
          Padding(
            padding: const EdgeInsets.only(left: 8, bottom: 16),
            child: Row(
              children: [
                _buildLegendDot(AppTheme.neonGreenDark, 'Sales'),
                const SizedBox(width: 20),
                _buildLegendDot(Colors.redAccent, 'Expenses'),
              ],
            ),
          ),
          // Chart
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            child: SizedBox(
              height: 220,
              width: math.max(
                MediaQuery.of(context).size.width - 48,
                maxX * (_selectedPeriod == ChartPeriod.daily ? 50.0 : _selectedPeriod == ChartPeriod.weekly ? 80.0 : 60.0),
              ),
              child: LineChart(
                key: ValueKey('$_selectedPeriod-$_selectedMonth-$_selectedYear'),
                LineChartData(
                  minX: minX,
                  maxX: maxX,
                  minY: minY,
                  maxY: maxY,
                  gridData: FlGridData(
                    show: true,
                    drawVerticalLine: false,
                    horizontalInterval: _calcInterval(salesSpots, expenseSpots),
                    getDrawingHorizontalLine: (value) => FlLine(
                      color: Colors.white.withValues(alpha: 0.05),
                      strokeWidth: 1,
                    ),
                  ),
                  titlesData: FlTitlesData(
                    leftTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 44,
                        getTitlesWidget: (value, meta) {
                          if (value == meta.max || value == meta.min) {
                            return const SizedBox.shrink();
                          }
                          String text;
                          if (value >= 1000) {
                            text = '${(value / 1000).toStringAsFixed(0)}k';
                          } else {
                            text = value.toStringAsFixed(0);
                          }
                          return Padding(
                            padding: const EdgeInsets.only(right: 8),
                            child: Text(
                              text,
                              style: TextStyle(
                                color: theme.colorScheme.onSurfaceVariant
                                    .withValues(alpha: 0.6),
                                fontSize: 11,
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 28,
                        interval: 1,
                        getTitlesWidget: (value, meta) {
                          // Only show labels for integer values to avoid overlaps
                          if (value % 1 != 0) return const SizedBox.shrink();
                          
                          return Padding(
                            padding: const EdgeInsets.only(top: 8),
                            child: Text(
                              _periodLabel(value.toInt()),
                              style: TextStyle(
                                color: theme.colorScheme.onSurfaceVariant
                                    .withValues(alpha: 0.6),
                                fontSize: 11,
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                    rightTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false),
                    ),
                    topTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false),
                    ),
                  ),
                  borderData: FlBorderData(show: false),
                  lineBarsData: [
                    // Sales line (green)
                    LineChartBarData(
                      spots: salesSpots,
                      isCurved: true,
                      curveSmoothness: 0.35,
                      color: AppTheme.neonGreenDark,
                      barWidth: 3,
                      isStrokeCapRound: true,
                      dotData: FlDotData(
                        show: true,
                        getDotPainter: (spot, p, data, idx) =>
                            FlDotCirclePainter(
                          radius: 4,
                          color: AppTheme.neonGreenDark,
                          strokeWidth: 2,
                          strokeColor: AppTheme.darkSurfaceContainer,
                        ),
                      ),
                      belowBarData: BarAreaData(
                        show: true,
                        color: AppTheme.neonGreenDark.withValues(alpha: 0.08),
                      ),
                    ),
                    // Expenses line (red)
                    LineChartBarData(
                      spots: expenseSpots,
                      isCurved: true,
                      curveSmoothness: 0.35,
                      color: Colors.redAccent,
                      barWidth: 3,
                      isStrokeCapRound: true,
                      dotData: FlDotData(
                        show: true,
                        getDotPainter: (spot, p, data, idx) =>
                            FlDotCirclePainter(
                          radius: 4,
                          color: Colors.redAccent,
                          strokeWidth: 2,
                          strokeColor: AppTheme.darkSurfaceContainer,
                        ),
                      ),
                      belowBarData: BarAreaData(
                        show: true,
                        color: Colors.redAccent.withValues(alpha: 0.06),
                      ),
                    ),
                  ],
                  lineTouchData: LineTouchData(
                    handleBuiltInTouches: true,
                    touchTooltipData: LineTouchTooltipData(
                      getTooltipColor: (_) =>
                          AppTheme.darkSurfaceContainerHigh,
                      tooltipRoundedRadius: 8,
                      getTooltipItems: (touchedSpots) {
                        return touchedSpots.map((spot) {
                          final color = spot.bar.color ?? Colors.white;
                          return LineTooltipItem(
                            '${_periodLabel(spot.x.toInt())}\nRM ${spot.y.toStringAsFixed(0)}',
                            TextStyle(
                              color: color,
                              fontWeight: FontWeight.bold,
                              fontSize: 13,
                            ),
                          );
                        }).toList();
                      },
                    ),
                  ),
                ),
                duration: const Duration(milliseconds: 300),
                curve: Curves.easeInOut,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLegendDot(Color color, String label) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 6),
        Text(
          label,
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.6),
            fontSize: 12,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }

  // ── Period Breakdown — Expandable Drill-Down ────────────────────────────

  /// Groups raw records by period key for drill-down.
  int _periodKeyForDate(DateTime date) {
    switch (_selectedPeriod) {
      case ChartPeriod.daily:
        return date.day;
      case ChartPeriod.weekly:
        int weekOfMonth = 1;
        DateTime temp = DateTime(date.year, date.month, 1);
        while (temp.isBefore(date) || temp.isAtSameMomentAs(date)) {
          if (temp.weekday == DateTime.monday && temp.day > 1) weekOfMonth++;
          temp = temp.add(const Duration(days: 1));
        }
        return weekOfMonth;
      case ChartPeriod.monthly:
        return date.month;
    }
  }

  Widget _buildRecentTransactionsSection(
    ThemeData theme,
    DashboardProvider dashProv,
  ) {
    if (dashProv.isChartLoading) return const SizedBox.shrink();

    // Group actual records by period key
    final Map<int, List<dynamic>> grouped = {};
    for (final sale in dashProv.chartSales) {
      final key = _periodKeyForDate(sale.saleDate);
      grouped.putIfAbsent(key, () => []).add(sale);
    }
    for (final expense in dashProv.chartExpenses) {
      final key = _periodKeyForDate(expense.date);
      grouped.putIfAbsent(key, () => []).add(expense);
    }

    final sortedKeys = grouped.keys.toList()..sort();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Period Breakdown',
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          'Tap a period to see individual transactions',
          style: theme.textTheme.labelMedium?.copyWith(
            color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.5),
          ),
        ),
        const SizedBox(height: 12),
        if (sortedKeys.isEmpty)
          Container(
            padding: const EdgeInsets.all(24),
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: AppTheme.darkSurfaceContainer,
              borderRadius: BorderRadius.circular(AppTheme.radiusLarge),
            ),
            child: Text(
              'No transactions for this period.',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          )
        else
          ...sortedKeys.map((key) {
            final items = grouped[key]!;
            return _buildExpandablePeriodTile(theme, key, items);
          }),
      ],
    );
  }

  Widget _buildExpandablePeriodTile(
    ThemeData theme, int periodKey, List<dynamic> items,
  ) {
    final tileKey = '$_selectedPeriod-$periodKey';
    final isExpanded = _expandedPeriods.contains(tileKey);

    // Separate sales and expenses
    final sales = items.whereType<SaleRecord>().toList();
    final expenses = items.whereType<ExpenseRecord>().toList();
    final totalSales = sales.fold(0.0, (s, r) => s + r.totalPayable);
    final totalExpenses = expenses.fold(0.0, (s, r) => s + r.amount);
    final netAmount = totalSales - totalExpenses;
    final isPositive = netAmount >= 0;
    final label = _periodLabel(periodKey);

    // Period description based on period type
    String periodTitle;
    switch (_selectedPeriod) {
      case ChartPeriod.daily:
        periodTitle = 'Day $label';
        break;
      case ChartPeriod.weekly:
        periodTitle = 'Week of $label';
        break;
      case ChartPeriod.monthly:
        periodTitle = label;
        break;
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: AppTheme.darkSurfaceContainer,
        borderRadius: BorderRadius.circular(AppTheme.radiusLarge),
        border: Border.all(
          color: isExpanded
              ? AppTheme.primary.withValues(alpha: 0.3)
              : Colors.white.withValues(alpha: 0.04),
        ),
      ),
      child: Column(
        children: [
          // ── Header (always visible, tappable) ──────────────────────
          Material(
            color: Colors.transparent,
            borderRadius: BorderRadius.circular(AppTheme.radiusLarge),
            child: InkWell(
              borderRadius: BorderRadius.circular(AppTheme.radiusLarge),
              onTap: () => setState(() {
                if (isExpanded) {
                  _expandedPeriods.remove(tileKey);
                } else {
                  _expandedPeriods.add(tileKey);
                }
              }),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    // Net indicator icon
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: (isPositive ? AppTheme.neonGreenDark : Colors.redAccent)
                            .withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(
                        isPositive
                            ? Icons.arrow_downward_rounded
                            : Icons.arrow_upward_rounded,
                        color: isPositive ? AppTheme.neonGreenDark : Colors.redAccent,
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 12),
                    // Period info
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            periodTitle,
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            '${sales.length} sale${sales.length != 1 ? 's' : ''} · ${expenses.length} expense${expenses.length != 1 ? 's' : ''}',
                            style: theme.textTheme.labelMedium?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.6),
                            ),
                          ),
                        ],
                      ),
                    ),
                    // Net amount
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          '${isPositive ? '+' : '-'} RM ${netAmount.abs().toStringAsFixed(2)}',
                          style: theme.textTheme.bodyMedium?.copyWith(
                            fontWeight: FontWeight.w700,
                            color: isPositive ? AppTheme.neonGreenDark : Colors.redAccent,
                          ),
                        ),
                        Text(
                          'net',
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.4),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(width: 4),
                    AnimatedRotation(
                      turns: isExpanded ? 0.5 : 0,
                      duration: const Duration(milliseconds: 200),
                      child: Icon(
                        Icons.keyboard_arrow_down_rounded,
                        color: theme.colorScheme.onSurfaceVariant,
                        size: 22,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

          // ── Expanded detail list ───────────────────────────────────
          AnimatedCrossFade(
            firstChild: const SizedBox.shrink(),
            secondChild: _buildExpandedDetails(theme, sales, expenses),
            crossFadeState: isExpanded
                ? CrossFadeState.showSecond
                : CrossFadeState.showFirst,
            duration: const Duration(milliseconds: 250),
          ),
        ],
      ),
    );
  }

  Widget _buildExpandedDetails(
    ThemeData theme,
    List<SaleRecord> sales,
    List<ExpenseRecord> expenses,
  ) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Divider(color: Colors.white.withValues(alpha: 0.06), height: 1),
          const SizedBox(height: 12),
          // Sales
          if (sales.isNotEmpty) ...[
            _buildSubHeader(theme, 'SALES', AppTheme.neonGreenDark, sales.length),
            const SizedBox(height: 8),
            ...sales.map((s) => _buildSaleDetailRow(theme, s)),
          ],
          // Expenses
          if (expenses.isNotEmpty) ...[
            if (sales.isNotEmpty) const SizedBox(height: 14),
            _buildSubHeader(theme, 'EXPENSES', Colors.redAccent, expenses.length),
            const SizedBox(height: 8),
            ...expenses.map((e) => _buildExpenseDetailRow(theme, e)),
          ],
        ],
      ),
    );
  }

  Widget _buildSubHeader(ThemeData theme, String label, Color color, int count) {
    return Row(
      children: [
        Container(
          width: 4,
          height: 16,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 8),
        Text(
          '$label ($count)',
          style: theme.textTheme.labelMedium?.copyWith(
            color: color,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.8,
          ),
        ),
      ],
    );
  }

  Widget _buildSaleDetailRow(ThemeData theme, SaleRecord sale) {
    final itemName = sale.lineItems.isNotEmpty
        ? sale.lineItems.first.item.name
        : 'Sale';
    final dateStr = DateFormat('d MMM, HH:mm').format(sale.saleDate);

    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: AppTheme.neonGreenDark.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(AppTheme.radiusSmall),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  itemName,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  '$dateStr · ${sale.customerName}',
                  style: theme.textTheme.labelMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.5),
                    fontSize: 11,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          Text(
            '+ RM ${sale.totalPayable.toStringAsFixed(2)}',
            style: theme.textTheme.bodyMedium?.copyWith(
              fontWeight: FontWeight.w700,
              color: AppTheme.neonGreenDark,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildExpenseDetailRow(ThemeData theme, ExpenseRecord expense) {
    final dateStr = DateFormat('d MMM, HH:mm').format(expense.date);

    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.redAccent.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(AppTheme.radiusSmall),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  expense.vendor.isNotEmpty ? expense.vendor : 'Unknown Vendor',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  '$dateStr · ${expense.category}',
                  style: theme.textTheme.labelMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.5),
                    fontSize: 11,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          Text(
            '- RM ${expense.amount.toStringAsFixed(2)}',
            style: theme.textTheme.bodyMedium?.copyWith(
              fontWeight: FontWeight.w700,
              color: Colors.redAccent,
            ),
          ),
        ],
      ),
    );
  }

  // ── Helpers ───────────────────────────────────────────────────────────────

  /// Returns a label for the X-axis based on the selected period.
  String _periodLabel(int value) {
    switch (_selectedPeriod) {
      case ChartPeriod.daily:
        return value.toString();
      case ChartPeriod.weekly:
        DateTime firstOfMonth = DateTime(_selectedYear, _selectedMonth, 1);
        DateTime firstMondayOfThisWeek;
        if (firstOfMonth.weekday == DateTime.monday) {
           List<DateTime> mondays = _getMondaysOfMonth(_selectedYear, _selectedMonth);
           if (value >= 1 && value <= mondays.length) {
             firstMondayOfThisWeek = mondays[value - 1];
             return '${firstMondayOfThisWeek.day}/${firstMondayOfThisWeek.month}';
           }
        } else {
           if (value == 1) {
             firstMondayOfThisWeek = firstOfMonth.subtract(Duration(days: firstOfMonth.weekday - 1));
             return '${firstMondayOfThisWeek.day}/${firstMondayOfThisWeek.month}';
           } else {
             List<DateTime> mondays = _getMondaysOfMonth(_selectedYear, _selectedMonth);
             if (value >= 2 && value - 2 < mondays.length) {
               firstMondayOfThisWeek = mondays[value - 2];
               return '${firstMondayOfThisWeek.day}/${firstMondayOfThisWeek.month}';
             }
           }
        }
        return 'Wk $value';
      case ChartPeriod.monthly:
        return _monthAbbr(value);
    }
  }

  List<DateTime> _getMondaysOfMonth(int year, int month) {
    List<DateTime> mondays = [];
    DateTime date = DateTime(year, month, 1);
    while (date.month == month) {
      if (date.weekday == DateTime.monday) {
        mondays.add(date);
      }
      date = date.add(const Duration(days: 1));
    }
    return mondays;
  }

  String _monthAbbr(int month) {
    const months = [
      '', 'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
    ];
    return (month >= 1 && month <= 12) ? months[month] : '$month';
  }

  /// Calculates a sensible grid interval from the chart data.
  double _calcInterval(List<FlSpot> a, List<FlSpot> b) {
    double maxY = 0;
    for (final s in a) {
      if (s.y > maxY) maxY = s.y;
    }
    for (final s in b) {
      if (s.y > maxY) maxY = s.y;
    }
    if (maxY <= 0) return 100;
    return (maxY / 4).ceilToDouble().clamp(10, double.infinity);
  }
}
