import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';

enum ChartPeriod { daily, weekly, monthly }

class CashflowChart extends StatelessWidget {
  final ChartPeriod period;
  final List<FlSpot> salesSpots;
  final List<FlSpot> expenseSpots;

  const CashflowChart({
    super.key,
    required this.period,
    required this.salesSpots,
    required this.expenseSpots,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    return Container(
      height: 250,
      padding: const EdgeInsets.only(right: 20, left: 10, top: 20, bottom: 10),
      child: LineChart(
        LineChartData(
          gridData: FlGridData(
            show: true,
            drawVerticalLine: false,
            horizontalInterval: 1000,
            getDrawingHorizontalLine: (value) {
              return FlLine(
                color: theme.dividerColor.withOpacity(0.1),
                strokeWidth: 1,
              );
            },
          ),
          titlesData: FlTitlesData(
            show: true,
            rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 30,
                interval: 1,
                getTitlesWidget: (value, meta) {
                  String text = '';
                  if (period == ChartPeriod.daily) {
                    if (value % 5 == 0) text = '${value.toInt()}';
                  } else if (period == ChartPeriod.weekly) {
                    text = 'W${value.toInt()}';
                  } else {
                    text = _getMonthLabel(value.toInt());
                  }
                  return SideTitleWidget(
                    meta: meta,
                    child: Text(text, style: theme.textTheme.labelSmall),
                  );
                },
              ),
            ),
            leftTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                interval: 5000,
                reservedSize: 42,
                getTitlesWidget: (value, meta) {
                  return Text(
                    '${(value/1000).toStringAsFixed(0)}k',
                    style: theme.textTheme.labelSmall,
                  );
                },
              ),
            ),
          ),
          borderData: FlBorderData(show: false),
          lineBarsData: [
            LineChartBarData(
              spots: salesSpots,
              isCurved: true,
              color: const Color(0xFF00FF85),
              barWidth: 3,
              isStrokeCapRound: true,
              dotData: const FlDotData(show: false),
              belowBarData: BarAreaData(
                show: true,
                color: const Color(0xFF00FF85).withOpacity(0.1),
              ),
            ),
            LineChartBarData(
              spots: expenseSpots,
              isCurved: true,
              color: theme.colorScheme.error,
              barWidth: 3,
              isStrokeCapRound: true,
              dotData: const FlDotData(show: false),
              belowBarData: BarAreaData(
                show: true,
                color: theme.colorScheme.error.withOpacity(0.1),
              ),
            ),
          ],
          lineTouchData: LineTouchData(
            touchTooltipData: LineTouchTooltipData(
              getTooltipColor: (touchedSpot) => theme.colorScheme.surfaceVariant,
              tooltipRoundedRadius: 8,
              getTooltipItems: (List<LineBarSpot> touchedBarSpots) {
                return touchedBarSpots.map((barSpot) {
                  final flLineBarData = barSpot.bar;
                  return LineTooltipItem(
                    'RM ${barSpot.y.toStringAsFixed(2)}',
                    TextStyle(
                      color: flLineBarData.color ?? Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  );
                }).toList();
              },
            ),
          ),
        ),
      ),
    );
  }

  String _getMonthLabel(int value) {
    const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    if (value >= 1 && value <= 12) return months[value - 1];
    return '';
  }
}
