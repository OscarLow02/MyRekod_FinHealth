import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:provider/provider.dart';
import '../core/app_theme.dart';
import '../providers/dashboard_provider.dart';
import '../widgets/cashflow_chart.dart'; // For ChartPeriod enum

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

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    // TODO: Implement i18n
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
              onTap: () => setState(() => _selectedPeriod = period),
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
                        ? Colors.white
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

  // ── Summary Cards Row ─────────────────────────────────────────────────────
  Widget _buildSummaryRow(ThemeData theme, DashboardProvider dashProv) {
    return Row(
      children: [
        Expanded(
          child: _buildSummaryTile(
            theme,
            label: 'Total Sales',
            value: dashProv.totalMonthlySales,
            color: AppTheme.neonGreenDark,
            icon: Icons.trending_up_rounded,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _buildSummaryTile(
            theme,
            label: 'Total Expenses',
            value: dashProv.totalMonthlyExpenses,
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
    final salesSpots = dashProv.getSalesSpots(_selectedPeriod);
    final expenseSpots = dashProv.getExpenseSpots(_selectedPeriod);

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
          SizedBox(
            height: 220,
            child: LineChart(
              LineChartData(
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
                      getTitlesWidget: (value, meta) {
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
                          'RM ${spot.y.toStringAsFixed(0)}',
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

  // ── Recent Transactions Section ───────────────────────────────────────────
  Widget _buildRecentTransactionsSection(
    ThemeData theme,
    DashboardProvider dashProv,
  ) {
    // Combine and sort recent transactions by date
    final recentItems = <_TransactionItem>[];

    for (final sale in dashProv.getSalesSpots(_selectedPeriod).take(10)) {
      // We show aggregated data per period key
      recentItems.add(_TransactionItem(
        title: '${_periodLabel(sale.x.toInt())} Sales',
        amount: sale.y,
        isIncome: true,
      ));
    }

    for (final expense in dashProv.getExpenseSpots(_selectedPeriod).take(10)) {
      recentItems.add(_TransactionItem(
        title: '${_periodLabel(expense.x.toInt())} Expenses',
        amount: expense.y,
        isIncome: false,
      ));
    }

    // Sort by amount descending for a more useful view
    recentItems.sort((a, b) => b.amount.compareTo(a.amount));

    // TODO: Implement i18n
    const sectionTitle = 'Period Breakdown';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          sectionTitle,
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 12),
        if (recentItems.isEmpty)
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
          ...recentItems.map(
            (item) => _buildTransactionTile(theme, item),
          ),
      ],
    );
  }

  Widget _buildTransactionTile(ThemeData theme, _TransactionItem item) {
    final color = item.isIncome ? AppTheme.neonGreenDark : Colors.redAccent;
    final prefix = item.isIncome ? '+' : '-';

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: AppTheme.darkSurfaceContainer,
        borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
        border: Border.all(color: Colors.white.withValues(alpha: 0.04)),
      ),
      child: Row(
        children: [
          // Icon
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              item.isIncome
                  ? Icons.arrow_downward_rounded
                  : Icons.arrow_upward_rounded,
              color: color,
              size: 20,
            ),
          ),
          const SizedBox(width: 12),
          // Title
          Expanded(
            child: Text(
              item.title,
              style: theme.textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          // Amount
          Text(
            '$prefix RM ${item.amount.toStringAsFixed(2)}',
            style: theme.textTheme.bodyMedium?.copyWith(
              fontWeight: FontWeight.w700,
              color: color,
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
        return 'Day $value';
      case ChartPeriod.weekly:
        return 'Wk $value';
      case ChartPeriod.monthly:
        return _monthAbbr(value);
    }
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

/// Internal model for a transaction row in the list.
class _TransactionItem {
  final String title;
  final double amount;
  final bool isIncome;

  const _TransactionItem({
    required this.title,
    required this.amount,
    required this.isIncome,
  });
}
