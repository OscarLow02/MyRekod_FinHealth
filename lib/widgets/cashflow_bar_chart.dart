import 'dart:math';
import 'package:flutter/material.dart';

/// A highly accessible native Bar Chart for comparing Sales vs. Expenses.
/// Built using Row, Column, and Container for performance and consistency.
class CashflowBarChart extends StatelessWidget {
  final double totalSales;
  final double totalExpenses;

  const CashflowBarChart({
    super.key,
    required this.totalSales,
    required this.totalExpenses,
  });

  @override
  Widget build(BuildContext context) {
    // Business logic for chart scaling
    final double netProfit = totalSales - totalExpenses;
    final double maxValue = max(totalSales, totalExpenses);
    
    // UI Constants
    const double chartHeight = 220.0; // Increased to accommodate labels
    const double barWidth = 48.0; // Meets accessibility standards (min 40dp requested)
    
    // Status colors from Luminescent Vault palette
    // Note: We use neonGreenDark (0xFF00FF85) and RedAccent for high visibility
    const Color salesColor = Color(0xFF00FF85);
    final Color expensesColor = Theme.of(context).colorScheme.error;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).cardTheme.color,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // The Bar Chart Area
          SizedBox(
            height: chartHeight,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                _BarComponent(
                  label: "Sales",
                  value: totalSales,
                  maxValue: maxValue,
                  color: salesColor,
                  width: barWidth,
                  maxChartHeight: chartHeight - 70, // Reserve more space for labels
                ),
                _BarComponent(
                  label: "Expenses",
                  value: totalExpenses,
                  maxValue: maxValue,
                  color: expensesColor,
                  width: barWidth,
                  maxChartHeight: chartHeight - 70, // Reserve more space for labels
                ),
              ],
            ),
          ),
          
          const SizedBox(height: 24),
          
          // Net Profit Display (Bold, 20sp)
          // TODO: Implement i18n
          Text(
            "Net Profit: RM ${netProfit.toStringAsFixed(2)}",
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.bold,
              color: Theme.of(context).colorScheme.onSurface,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

class _BarComponent extends StatelessWidget {
  final String label;
  final double value;
  final double maxValue;
  final Color color;
  final double width;
  final double maxChartHeight;

  const _BarComponent({
    required this.label,
    required this.value,
    required this.maxValue,
    required this.color,
    required this.width,
    required this.maxChartHeight,
  });

  @override
  Widget build(BuildContext context) {
    // Calculate percentage height
    final double percentageHeight = maxValue > 0 ? (value / maxValue) * maxChartHeight : 0;
    
    return Column(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        // The Data Bar
        AnimatedContainer(
          duration: const Duration(milliseconds: 500),
          curve: Curves.easeOutCubic,
          width: width,
          height: max(percentageHeight, 4.0), // Minimum height for visibility
          decoration: BoxDecoration(
            color: color,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(8)),
            boxShadow: [
              BoxShadow(
                color: color.withValues(alpha: 0.3),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
        ),
        
        const SizedBox(height: 12),
        
        // Label & Value
        Text(
          label,
          style: Theme.of(context).textTheme.labelMedium?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        Text(
          "RM ${value.toStringAsFixed(0)}",
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
            fontSize: 12,
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }
}
