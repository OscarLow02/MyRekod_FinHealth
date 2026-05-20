import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import '../widgets/cashflow_chart.dart'; // To use ChartPeriod enum
import '../models/sale_record.dart';
import '../models/expense_record.dart';
import '../models/business_profile.dart';
import '../services/firestore_service.dart';

/// Aggregates monthly financial data directly from Firestore for the
/// Dashboard Hero Card and chart visualisations.
///
/// This provider executes independent queries to ensure all data for the
/// current month is captured, bypassing any pagination limits in the UI providers.
class DashboardProvider with ChangeNotifier {
  // ── Dependencies ────────────────────────────────────────────────────────
  final FirestoreService _firestoreService = FirestoreService();

  // ── Aggregated State ──────────────────────────────────────────────────────
  double _totalMonthlySales = 0.0;
  double _totalMonthlyExpenses = 0.0;
  int _monthlySaleCount = 0;
  int _monthlyExpenseCount = 0;
  bool _isLoading = false;

  // ── Month-over-Month Trend State ────────────────────────────────────────
  double _lastMonthNetProfit = 0.0;
  bool _hasLastMonthData = false;

  // Stored records for historical analysis
  List<SaleRecord> _allSales = [];
  List<ExpenseRecord> _allExpenses = [];

  // ── Chart Specific State ──────────────────────────────────────────────────
  bool _isChartLoading = false;
  List<SaleRecord> _chartSales = [];
  List<ExpenseRecord> _chartExpenses = [];
  
  bool get isChartLoading => _isChartLoading;

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

  // ── Month-over-Month Trend Getters ──────────────────────────────────────

  /// Whether we have last month's data to compare against.
  bool get hasLastMonthData => _hasLastMonthData;

  /// The month-over-month percentage change in net profit.
  /// Returns `null` when last month had no data (so the UI can show 'New!').
  /// Positive = improvement, negative = decline.
  double? get monthOverMonthPercent {
    if (!_hasLastMonthData) return null;
    if (_lastMonthNetProfit == 0.0) {
      // Went from zero to something – treat as infinite growth; cap at 100%.
      return netProfit > 0 ? 100.0 : (netProfit < 0 ? -100.0 : 0.0);
    }
    return ((netProfit - _lastMonthNetProfit) / _lastMonthNetProfit.abs()) * 100;
  }

  /// Convenience: is the trend positive, negative, or flat?
  /// Returns 1 for up, -1 for down, 0 for flat/no data.
  int get trendDirection {
    final pct = monthOverMonthPercent;
    if (pct == null || pct == 0.0) return 0;
    return pct > 0 ? 1 : -1;
  }

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

  /// Fetches and aggregates monthly data directly from Firestore to avoid
  /// pagination bugs from the UI-level providers.
  Future<void> aggregateMonthlyData(
    String userId, {
    BusinessProfile? profile,
  }) async {
    _isLoading = true;
    notifyListeners();

    try {
      final now = DateTime.now();
      final startOfMonth = DateTime(now.year, now.month, 1);
      final endOfMonth = DateTime(now.year, now.month + 1, 0, 23, 59, 59);

      // ── Last Month date range (for MoM trend) ──────────────────────────────
      final lastMonthEnd = startOfMonth.subtract(const Duration(seconds: 1));
      final startOfLastMonth = DateTime(lastMonthEnd.year, lastMonthEnd.month, 1);

      // ── Query Current Month & Last Month in parallel ───────────────────────
      final results = await Future.wait([
        _firestoreService.getSaleRecordsInDateRange(userId, startOfMonth, endOfMonth),
        _firestoreService.getExpensesInDateRange(userId, startOfMonth, endOfMonth),
        _firestoreService.getSaleRecordsInDateRange(userId, startOfLastMonth, lastMonthEnd),
        _firestoreService.getExpensesInDateRange(userId, startOfLastMonth, lastMonthEnd),
      ]);

      // ── Current Month ──────────────────────────────────────────────────────
      final sales = results[0] as List<SaleRecord>;
      final expenses = results[1] as List<ExpenseRecord>;

      _allSales = sales;
      _totalMonthlySales = sales.fold(
        0.0,
        (sum, sale) => sum + sale.totalPayable,
      );
      _monthlySaleCount = sales.length;

      _allExpenses = expenses;
      _totalMonthlyExpenses = expenses.fold(
        0.0,
        (sum, expense) => sum + expense.amount,
      );
      _monthlyExpenseCount = expenses.length;

      // ── Last Month (for MoM comparison) ────────────────────────────────────
      final lastMonthSales = results[2] as List<SaleRecord>;
      final lastMonthExpenses = results[3] as List<ExpenseRecord>;

      final lastMonthTotalSales = lastMonthSales.fold(
        0.0,
        (sum, sale) => sum + sale.totalPayable,
      );
      final lastMonthTotalExpenses = lastMonthExpenses.fold(
        0.0,
        (sum, expense) => sum + expense.amount,
      );

      _lastMonthNetProfit = lastMonthTotalSales - lastMonthTotalExpenses;
      _hasLastMonthData =
          lastMonthSales.isNotEmpty || lastMonthExpenses.isNotEmpty;

      // ── Compute Credit Readiness Score ─────────────────────────────────────
      final activeDays = _countActiveDays(sales, expenses);

      // Using the rubric: Base(300) + Profile(100) + Activity(300) + Cashflow(300)
      int newScore = 300;
      if (_isProfileComplete(profile)) newScore += 100;
      newScore += (activeDays * 10).clamp(0, 300);

      if (netProfit > 0) {
        newScore += (netProfit * 0.1).round().clamp(0, 300);
      }

      _creditScore = newScore.clamp(0, 1000);
    } catch (e) {
      debugPrint('Error aggregating monthly data: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Fetches historical data specifically for the Cashflow Analytics chart.
  /// Does not affect the core Dashboard summary states.
  Future<void> fetchChartData(
    String userId,
    ChartPeriod period,
    int month,
    int year,
  ) async {
    _isChartLoading = true;
    notifyListeners();

    try {
      DateTime startDate;
      DateTime endDate;

      if (period == ChartPeriod.monthly) {
        // Fetch full year
        startDate = DateTime(year, 1, 1);
        endDate = DateTime(year, 12, 31, 23, 59, 59);
      } else {
        // Fetch specific month
        startDate = DateTime(year, month, 1);
        endDate = DateTime(year, month + 1, 0, 23, 59, 59);
      }

      final futures = await Future.wait([
        _firestoreService.getSaleRecordsInDateRange(userId, startDate, endDate),
        _firestoreService.getExpensesInDateRange(userId, startDate, endDate),
      ]);

      _chartSales = futures[0] as List<SaleRecord>;
      _chartExpenses = futures[1] as List<ExpenseRecord>;
    } catch (e) {
      debugPrint('Error fetching chart data: $e');
    } finally {
      _isChartLoading = false;
      notifyListeners();
    }
  }

  // ── Credit Score Helpers ─────────────────────────────────────────────────

  /// A profile is "complete" when all LHDN-critical fields are filled.
  static bool _isProfileComplete(BusinessProfile? profile) {
    if (profile == null) return false;
    return profile.businessName.isNotEmpty &&
        profile.tinNumber.isNotEmpty &&
        profile.brnNumber.isNotEmpty &&
        profile.email.isNotEmpty &&
        profile.phoneNumber.isNotEmpty &&
        profile.msicCode.isNotEmpty;
  }

  /// Counts unique calendar days with at least one recorded transaction.
  static int _countActiveDays(
    List<SaleRecord> monthlySales,
    List<ExpenseRecord> monthlyExpenses,
  ) {
    final days = <int>{};
    for (final s in monthlySales) {
      days.add(s.saleDate.day);
    }
    for (final e in monthlyExpenses) {
      days.add(e.date.day);
    }
    return days.length;
  }

  // ── Daily Breakdown (for Bar Chart) ───────────────────────────────────────

  /// Returns a map of { day-of-month → total sales } for the current month.
  /// Useful for feeding a bar chart widget.
  Map<int, double> getDailySalesBreakdown(List<SaleRecord> sales) {
    final now = DateTime.now();
    final breakdown = <int, double>{};

    for (final sale in sales) {
      if (sale.saleDate.month == now.month && sale.saleDate.year == now.year) {
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
      if (expense.date.month == now.month && expense.date.year == now.year) {
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
      if (expense.date.month == now.month && expense.date.year == now.year) {
        breakdown[expense.category] =
            (breakdown[expense.category] ?? 0.0) + expense.amount;
      }
    }
    return breakdown;
  }

  // ── Chart Spot Generation ───────────────────────────────────────────────

  List<FlSpot> getChartSalesSpots(ChartPeriod period) {
    return _generateSpots(
      _chartSales,
      period,
      (s) => s.saleDate,
      (s) => s.totalPayable,
    );
  }

  List<FlSpot> getChartExpenseSpots(ChartPeriod period) {
    return _generateSpots(
      _chartExpenses,
      period,
      (e) => e.date,
      (e) => e.amount,
    );
  }

  List<FlSpot> getSalesSpots(ChartPeriod period) {
    return _generateSpots(
      _allSales,
      period,
      (s) => s.saleDate,
      (s) => s.totalPayable,
    );
  }

  List<FlSpot> getExpenseSpots(ChartPeriod period) {
    return _generateSpots(_allExpenses, period, (e) => e.date, (e) => e.amount);
  }

  List<FlSpot> _generateSpots<T>(
    List<T> records,
    ChartPeriod period,
    DateTime Function(T) getDate,
    double Function(T) getAmount,
  ) {
    if (records.isEmpty) return [const FlSpot(0, 0)];

    final Map<int, double> grouped = {};

    for (final record in records) {
      final date = getDate(record);
      int key = 0;

      if (period == ChartPeriod.daily) {
        key = date.day;
      } else if (period == ChartPeriod.weekly) {
        int weekOfMonth = 1;
        DateTime temp = DateTime(date.year, date.month, 1);
        while (temp.isBefore(date) || temp.isAtSameMomentAs(date)) {
          if (temp.weekday == DateTime.monday && temp.day > 1) {
            weekOfMonth++;
          }
          temp = temp.add(const Duration(days: 1));
        }
        key = weekOfMonth;
      } else {
        key = date.month;
      }

      grouped[key] = (grouped[key] ?? 0.0) + getAmount(record);
    }

    final List<FlSpot> spots = [];
    final sortedKeys = grouped.keys.toList()..sort();

    if (sortedKeys.isEmpty) return [const FlSpot(0, 0)];

    for (final key in sortedKeys) {
      spots.add(FlSpot(key.toDouble(), grouped[key]!));
    }

    return spots;
  }
}
