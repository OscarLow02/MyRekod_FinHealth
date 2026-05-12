import 'package:flutter/material.dart';
import '../models/sale_record.dart';
import '../models/expense_record.dart';
import 'sales_provider.dart';
import 'expense_provider.dart';

/// Aggregates monthly financial data from [SalesProvider] and [ExpenseProvider]
/// for the Dashboard Hero Card and chart visualisations.
///
/// This provider does **not** own any Firestore streams itself — it reads
/// from the already-cached lists exposed by the two source providers and
/// recalculates totals for the current calendar month.
class DashboardProvider with ChangeNotifier {
  // ── Aggregated State ──────────────────────────────────────────────────────
  double _totalMonthlySales = 0.0;
  double _totalMonthlyExpenses = 0.0;
  int _monthlySaleCount = 0;
  int _monthlyExpenseCount = 0;
  bool _isLoading = false;

  // ── Public Getters ────────────────────────────────────────────────────────
  double get totalMonthlySales => _totalMonthlySales;
  double get totalMonthlyExpenses => _totalMonthlyExpenses;
  int get monthlySaleCount => _monthlySaleCount;
  int get monthlyExpenseCount => _monthlyExpenseCount;
  bool get isLoading => _isLoading;

  /// Net profit for the current month (sales − expenses).
  double get netProfit => _totalMonthlySales - _totalMonthlyExpenses;

  /// True when there is no data to display (for zero-state UI).
  bool get hasNoData =>
      _totalMonthlySales == 0.0 && _totalMonthlyExpenses == 0.0;

  // ── Credit Readiness Score ────────────────────────────────────────────────
  int _creditScore = 300;
  int get creditScore => _creditScore;

  /// Calculates a gamified Credit Readiness Score (0–1000) to help
  /// B40 hawkers track their micro-financing eligibility.
  ///
  /// **Scoring breakdown:**
  /// | Component            | Points                              | Max  |
  /// |----------------------|-------------------------------------|------|
  /// | Base                 | Flat                                | 300  |
  /// | Profile Completeness | 100 if [isProfileComplete] is true  | 100  |
  /// | Consistency          | 10 × [activeDaysThisMonth]          | 300  |
  /// | Cashflow Health      | [netProfit] × 0.1 (if positive)     | 300  |
  /// | **Total**            |                                     |**1000**|
  void calculateCreditScore({
    required bool isProfileComplete,
    required int activeDaysThisMonth,
    required double netProfit,
  }) {
    int newScore = 300; // Base score

    // 1. Profile Completeness — 100 points
    if (isProfileComplete) {
      newScore += 100;
    }

    // 2. Consistency — 10 pts per active day, capped at 300
    final int consistencyPoints = (activeDaysThisMonth * 10).clamp(0, 300);
    newScore += consistencyPoints;

    // 3. Cashflow Health — netProfit × 0.1, capped at 300 (0 if negative)
    if (netProfit > 0) {
      final int cashflowPoints = (netProfit * 0.1).round().clamp(0, 300);
      newScore += cashflowPoints;
    }

    // Hard ceiling at 1000
    _creditScore = newScore.clamp(0, 1000);
    notifyListeners();
  }

  // ── Convenience: Formatted Margin ─────────────────────────────────────────
  /// Returns the profit margin as a percentage string, or '—' when sales = 0.
  String get profitMarginLabel {
    if (_totalMonthlySales == 0) return '—';
    final margin = (netProfit / _totalMonthlySales) * 100;
    return '${margin.toStringAsFixed(1)}%';
  }

  // ── Core Aggregation ──────────────────────────────────────────────────────

  /// Call this whenever the upstream providers emit new data.
  ///
  /// Typically invoked inside a `Consumer2<SalesProvider, ExpenseProvider>`
  /// in the Dashboard widget tree, or via `addListener` on each provider.
  ///
  /// ```dart
  /// // Example usage in dashboard_screen.dart:
  /// Consumer2<SalesProvider, ExpenseProvider>(
  ///   builder: (context, salesProv, expProv, _) {
  ///     // Re-aggregate whenever either provider rebuilds.
  ///     context.read<DashboardProvider>().aggregateMonthlyData(
  ///       salesProv.saleRecords,
  ///       expProv.expenses,
  ///     );
  ///     ...
  ///   },
  /// )
  /// ```
  Future<void> aggregateMonthlyData(
    List<SaleRecord> sales,
    List<ExpenseRecord> expenses,
  ) async {
    _isLoading = true;
    notifyListeners();

    final now = DateTime.now();
    final currentMonth = now.month;
    final currentYear = now.year;

    // ── Filter & sum sales for the current month ────────────────────────
    final monthlySales = sales.where(
      (sale) =>
          sale.saleDate.month == currentMonth &&
          sale.saleDate.year == currentYear,
    );
    _totalMonthlySales = monthlySales.fold(
      0.0,
      (sum, sale) => sum + sale.totalPayable,
    );
    _monthlySaleCount = monthlySales.length;

    // ── Filter & sum expenses for the current month ─────────────────────
    final monthlyExpenses = expenses.where(
      (expense) =>
          expense.date.month == currentMonth &&
          expense.date.year == currentYear,
    );
    _totalMonthlyExpenses = monthlyExpenses.fold(
      0.0,
      (sum, expense) => sum + expense.amount,
    );
    _monthlyExpenseCount = monthlyExpenses.length;

    _isLoading = false;
    notifyListeners();
  }

  // ── Daily Breakdown (for Bar Chart) ───────────────────────────────────────

  /// Returns a map of { day-of-month → total sales } for the current month.
  /// Useful for feeding a bar chart widget.
  Map<int, double> getDailySalesBreakdown(List<SaleRecord> sales) {
    final now = DateTime.now();
    final breakdown = <int, double>{};

    for (final sale in sales) {
      if (sale.saleDate.month == now.month &&
          sale.saleDate.year == now.year) {
        final day = sale.saleDate.day;
        breakdown[day] = (breakdown[day] ?? 0.0) + sale.totalPayable;
      }
    }
    return breakdown;
  }

  /// Returns a map of { day-of-month → total expenses } for the current month.
  Map<int, double> getDailyExpensesBreakdown(List<ExpenseRecord> expenses) {
    final now = DateTime.now();
    final breakdown = <int, double>{};

    for (final expense in expenses) {
      if (expense.date.month == now.month &&
          expense.date.year == now.year) {
        final day = expense.date.day;
        breakdown[day] = (breakdown[day] ?? 0.0) + expense.amount;
      }
    }
    return breakdown;
  }

  // ── Category Breakdown (for Expense Pie Chart) ────────────────────────────

  /// Returns a map of { category → total amount } for the current month's
  /// expenses. Useful for a donut/pie chart.
  Map<String, double> getExpenseCategoryBreakdown(
    List<ExpenseRecord> expenses,
  ) {
    final now = DateTime.now();
    final breakdown = <String, double>{};

    for (final expense in expenses) {
      if (expense.date.month == now.month &&
          expense.date.year == now.year) {
        breakdown[expense.category] =
            (breakdown[expense.category] ?? 0.0) + expense.amount;
      }
    }
    return breakdown;
  }
}
