import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../core/app_theme.dart';
import '../services/firestore_service.dart';
import '../models/business_profile.dart';
import '../providers/sales_provider.dart';
import '../providers/expense_provider.dart';
import '../providers/dashboard_provider.dart';
import '../providers/sale_calculator_provider.dart';
import '../widgets/app_dialogs.dart';
import '../widgets/credit_score_gauge.dart';
import '../widgets/credit_score_info_sheet.dart';
import '../widgets/dashboard_wave_header.dart';
import '../services/pdf_report_service.dart';
import 'profile/profile_menu_screen.dart';
import 'transactions_screen.dart';
import 'expenses/scanner_screen.dart';
import 'sales/record_sale_screen.dart';
import 'customers/customer_list_screen.dart';
import 'cashflow_analysis_screen.dart';
import '../widgets/report_filter_bottom_sheet.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  int _currentIndex = 0;
  BusinessProfile? _profile;
  bool _isLoading = true;
  bool _isGeneratingPdf = false;

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  Future<void> _loadProfile() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      final profile = await FirestoreService().getBusinessProfile(user.uid);
      if (mounted) {
        setState(() {
          _profile = profile;
          _isLoading = false;
        });
      }
    } else {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final user = FirebaseAuth.instance.currentUser;

    final String labelDefaultUser = 'User';

    final displayName =
        _profile?.businessName ?? user?.displayName ?? labelDefaultUser;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      extendBody: true,
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _buildCurrentPage(theme, displayName),
      bottomNavigationBar: _buildGlassBottomNav(theme),
    );
  }

  Widget _buildCurrentPage(ThemeData theme, String displayName) {
    switch (_currentIndex) {
      case 0:
        return _buildHomePage(theme, displayName);
      case 1:
        return const TransactionsScreen();
      case 2:
        return const CustomerListScreen(isPickerMode: false);
      case 3:
        return const ProfileMenuScreen();
      default:
        return _buildHomePage(theme, displayName);
    }
  }

  // ── The Overlapping Stack Dashboard ───────────────────────────────────────
  Widget _buildHomePage(ThemeData theme, String displayName) {
    final isHighContrast = theme.colorScheme.primary.toARGB32() == 0xFFFFFF00;
    return Consumer3<SalesProvider, ExpenseProvider, DashboardProvider>(
      builder: (context, salesProv, expProv, dashProv, _) {
        // Re-aggregate monthly data whenever upstream providers change
        WidgetsBinding.instance.addPostFrameCallback((_) {
          final currentUser = FirebaseAuth.instance.currentUser;
          if (currentUser != null) {
            dashProv.aggregateMonthlyData(currentUser.uid, profile: _profile);
          }
        });

        final hasData = !dashProv.hasNoData;

        final String welcomeLabel = 'Welcome back,';
        final String businessName = _profile?.businessName ?? "Oscar's Kitchen";
        const String zeroStateText =
            "No sales recorded today!\nTap the '+' to start your streak.";

        return Stack(
          children: [
            // ── Bottom Layer: Purple Wave ──────────────────────────────────
            const DashboardWaveHeader(height: 220),

            // ── Top Layer: Content ────────────────────────────────────────
            SafeArea(
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // ── Section 1: Header on wave ──────────────────────────
                    Padding(
                      padding: const EdgeInsets.fromLTRB(24, 16, 16, 0),
                      child: Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  welcomeLabel,
                                  style: theme.textTheme.titleMedium?.copyWith(
                                    color: isHighContrast
                                        ? theme.colorScheme.onSurface
                                        : theme.colorScheme.onPrimary.withValues(
                                            alpha: 0.8,
                                          ),
                                    fontWeight: FontWeight.w500,
                                    letterSpacing: 0.2,
                                  ),
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  businessName,
                                  style: theme.textTheme.headlineMedium
                                      ?.copyWith(
                                        fontWeight: FontWeight.w800,
                                        color: isHighContrast
                                            ? theme.colorScheme.primary
                                            : theme.colorScheme.onPrimary,
                                        letterSpacing: -0.3,
                                      ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(
                            width: 48,
                          ), // Spacer to balance the header if needed, or just remove
                        ],
                      ),
                    ),

                    // ── Section 2: Overlapping Hero Card ──────────────────
                    if (hasData) ...[
                      const SizedBox(height: 80),
                      Transform(
                        transform: Matrix4.translationValues(0.0, -20.0, 0.0),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 20),
                          child: Container(
                            decoration: BoxDecoration(
                              color: theme.colorScheme.surfaceContainer.withValues(
                                alpha: 0.85,
                              ),
                              borderRadius: BorderRadius.circular(
                                AppTheme.radiusXLarge,
                              ),
                              border: Border.all(
                                color: isHighContrast
                                    ? theme.colorScheme.primary.withValues(alpha: 0.3)
                                    : Colors.white.withValues(alpha: 0.05),
                                width: isHighContrast ? 1.5 : 1.0,
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.3),
                                  blurRadius: 24,
                                  offset: const Offset(0, 8),
                                ),
                              ],
                            ),
                            child: Column(
                              children: [
                                Stack(
                                  children: [
                                    CreditScoreGauge(score: dashProv.creditScore),
                                    Positioned(
                                      top: 8,
                                      right: 8,
                                      child: IconButton(
                                        icon: Icon(
                                          Icons.info_outline_rounded,
                                          color: theme.colorScheme.onSurfaceVariant,
                                          size: 22,
                                        ),
                                        onPressed: () =>
                                            CreditScoreInfoSheet.show(context),
                                      ),
                                    ),
                                  ],
                                ),
                                // Score Breakdown Bars
                                _buildScoreBreakdown(theme, dashProv),
                              ],
                            ),
                          ),
                        ),
                      ),

                      // ── Section 3: Quick Actions ──────────────────────────
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 20),
                        child: Transform(
                          transform: Matrix4.translationValues(0.0, -24.0, 0.0),
                          child: Row(
                            children: [
                              _buildQuickAction(
                                context,
                                icon: Icons.add_circle_outline_rounded,
                                label: 'Record\nSale',
                                color: theme.colorScheme.secondary,
                                onTap: () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (_) => ChangeNotifierProvider(
                                        create: (_) => SaleCalculatorProvider(),
                                        child: const RecordSaleScreen(),
                                      ),
                                    ),
                                  );
                                },
                              ),
                              const SizedBox(width: 12),
                              _buildQuickAction(
                                context,
                                icon: Icons.document_scanner_outlined,
                                label:
                                    'Record\nExpense',
                                color: Colors.orange,
                                onTap: () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (context) =>
                                          const ScannerScreen(),
                                    ),
                                  );
                                },
                              ),
                              const SizedBox(width: 12),
                              _buildQuickAction(
                                context,
                                icon: Icons.description_outlined,
                                label:
                                    'Generate\nReport',
                                color: Colors.white,
                                isPrimary: true,
                                isLoading: _isGeneratingPdf,
                                onTap: () => _generatePdfReport(
                                  dashProv: dashProv,
                                  salesProv: salesProv,
                                  expProv: expProv,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),

                      // ── Section 4: Net Profit Card ────────────────────────
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 20),
                        child: _buildNetProfitCard(theme, dashProv),
                      ),
                      const SizedBox(height: 28),

                      // ── Section 5: Cash Flow Overview ─────────────────────
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 20),
                        child: _buildCashFlowOverview(theme, dashProv),
                      ),
                      const SizedBox(height: 80), // Bottom padding for FAB
                    ] else ...[
                      // ── Zero-State UI ───────────────────────────────────
                      const SizedBox(height: 120),
                      Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Container(
                              width: 220,
                              height: 220,
                              decoration: BoxDecoration(
                                color: theme.colorScheme.primary.withValues(
                                  alpha: 0.05,
                                ),
                                shape: BoxShape.circle,
                              ),
                              child: Center(
                                child: Icon(
                                  Icons.insights_rounded,
                                  size: 100,
                                  color: theme.colorScheme.primary.withValues(
                                    alpha: 0.3,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(height: 40),
                            Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 24,
                              ),
                              child: Text(
                                zeroStateText,
                                textAlign: TextAlign.center,
                                style: theme.textTheme.bodyLarge?.copyWith(
                                  fontWeight: FontWeight.w600,
                                  color: theme.colorScheme.onSurfaceVariant,
                                  height: 1.5,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  // ── Quick Action Button ─────────────────────────────────────────────────
  Widget _buildQuickAction(
    BuildContext context, {
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
    bool isPrimary = false,
    bool isLoading = false,
  }) {
    final theme = Theme.of(context);
    final isHighContrast = theme.colorScheme.primary.toARGB32() == 0xFFFFFF00;

    final iconColor = isHighContrast
        ? (isPrimary ? theme.colorScheme.onPrimary : theme.colorScheme.primary)
        : (isPrimary ? theme.colorScheme.onPrimary : color);

    return Expanded(
      child: Column(
        children: [
          Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: isLoading ? null : onTap,
              borderRadius: BorderRadius.circular(100),
              child: Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  color: isPrimary
                      ? theme.colorScheme.primary
                      : theme.colorScheme.surfaceContainer,
                  shape: BoxShape.circle,
                  border: isPrimary
                      ? null
                      : Border.all(
                          color: isHighContrast
                              ? theme.colorScheme.primary.withValues(alpha: 0.3)
                              : Colors.white.withValues(alpha: 0.05),
                          width: isHighContrast ? 1.5 : 1.0,
                        ),
                  boxShadow: isPrimary
                      ? [
                          BoxShadow(
                            color: theme.colorScheme.primary.withValues(
                              alpha: 0.3,
                            ),
                            blurRadius: 16,
                            offset: const Offset(0, 4),
                          ),
                        ]
                      : [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.2),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ],
                ),
                child: isLoading
                    ? SizedBox(
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(
                          color: iconColor,
                          strokeWidth: 2.5,
                        ),
                      )
                    : Icon(icon, color: iconColor, size: 28),
              ),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            label,
            textAlign: TextAlign.center,
            style: theme.textTheme.labelMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
              fontSize: 12,
              height: 1.3,
            ),
          ),
        ],
      ),
    );
  }

  // ── Net Profit Card ─────────────────────────────────────────────────────
  Widget _buildNetProfitCard(ThemeData theme, DashboardProvider dashProv) {
    final isHighContrast = theme.colorScheme.primary.toARGB32() == 0xFFFFFF00;
    final isPositive = dashProv.netProfit >= 0;
    final profitParts = dashProv.netProfit.toStringAsFixed(2).split('.');
    const netProfitLabel = 'Net Profit (Current Month)';

    // ── Dynamic MoM trend ───────────────────────────────────────────────────
    final momPercent = dashProv.monthOverMonthPercent;
    final trend = dashProv.trendDirection; // 1 = up, -1 = down, 0 = flat/new

    final String trendLabel;
    final Color trendColor;
    final IconData trendIcon;

    if (momPercent == null) {
      // No last-month data at all → first month of usage
      trendLabel = 'First month — keep going!';
      trendColor = theme.colorScheme.secondary;
      trendIcon = Icons.auto_awesome_rounded;
    } else if (trend == 0) {
      trendLabel = 'No change vs last month';
      trendColor = theme.colorScheme.onSurfaceVariant;
      trendIcon = Icons.trending_flat_rounded;
    } else if (trend > 0) {
      trendLabel = '↗ ${momPercent.abs().toStringAsFixed(1)}% vs last month';
      trendColor = AppTheme.neonGreenDark;
      trendIcon = Icons.trending_up_rounded;
    } else {
      trendLabel = '↘ ${momPercent.abs().toStringAsFixed(1)}% vs last month';
      trendColor = theme.colorScheme.error;
      trendIcon = Icons.trending_down_rounded;
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainer,
        borderRadius: BorderRadius.circular(AppTheme.radiusXLarge),
        border: Border.all(
          color: isHighContrast
              ? theme.colorScheme.primary.withValues(alpha: 0.3)
              : Colors.white.withValues(alpha: 0.05),
          width: isHighContrast ? 1.5 : 1.0,
        ),
      ),
      child: Stack(
        children: [
          // Decorative glow
          Positioned(
            right: -40,
            top: -40,
            child: Container(
              width: 120,
              height: 120,
              decoration: BoxDecoration(
                color: (isPositive
                        ? AppTheme.neonGreenDark
                        : theme.colorScheme.error)
                    .withValues(alpha: 0.08),
                shape: BoxShape.circle,
              ),
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                netProfitLabel,
                style: theme.textTheme.labelMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 8),
              Text.rich(
                TextSpan(
                  children: [
                    TextSpan(
                      text: 'RM ${_formatWithCommas(profitParts[0])}',
                      style: theme.textTheme.displayMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                        color: theme.colorScheme.onSurface,
                        fontSize: 32,
                        letterSpacing: -0.5,
                      ),
                    ),
                    TextSpan(
                      text: '.${profitParts[1]}',
                      style: theme.textTheme.titleLarge?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              // Sales vs Expenses mini-row
              Row(
                children: [
                  Icon(Icons.arrow_downward_rounded, size: 14, color: AppTheme.neonGreenDark),
                  const SizedBox(width: 4),
                  Text(
                    'RM ${_formatWithCommas(dashProv.totalMonthlySales.toStringAsFixed(0))}',
                    style: theme.textTheme.labelMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                      color: AppTheme.neonGreenDark,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Icon(Icons.arrow_upward_rounded, size: 14, color: Colors.redAccent),
                  const SizedBox(width: 4),
                  Text(
                    'RM ${_formatWithCommas(dashProv.totalMonthlyExpenses.toStringAsFixed(0))}',
                    style: theme.textTheme.labelMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                      color: Colors.redAccent,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              // Trend pill chip — now data-driven
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: trendColor.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(100),
                ),
                child: Wrap(
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    Icon(trendIcon, size: 16, color: trendColor),
                    const SizedBox(width: 6),
                    Text(
                      trendLabel,
                      style: theme.textTheme.labelMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                        color: trendColor,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ── Cash Flow Overview Section ──────────────────────────────────────────
  Widget _buildCashFlowOverview(ThemeData theme, DashboardProvider dashProv) {
    final isHighContrast = theme.colorScheme.primary.toARGB32() == 0xFFFFFF00;
    const overviewTitle = 'Cash Flow Overview';
    const viewDetailsLabel = 'View Details';

    final totalSales = dashProv.totalMonthlySales;
    final totalExpenses = dashProv.totalMonthlyExpenses;
    final maxValue = totalSales > totalExpenses ? totalSales : totalExpenses;

    final String currentMonth = DateFormat('MMMM yyyy').format(DateTime.now());

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Header row
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    overviewTitle,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                      letterSpacing: -0.2,
                    ),
                  ),
                  Text(
                    currentMonth,
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            TextButton(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const CashflowAnalysisScreen(),
                  ),
                );
              },
              style: TextButton.styleFrom(
                minimumSize: const Size(0, AppTheme.minTouchTarget),
                padding: const EdgeInsets.symmetric(horizontal: 8),
              ),
              child: Wrap(
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  Text(
                    viewDetailsLabel,
                    style: theme.textTheme.labelMedium?.copyWith(
                      color: theme.colorScheme.secondary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(width: 4),
                  Icon(
                    Icons.chevron_right_rounded,
                    color: theme.colorScheme.secondary,
                    size: 20,
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        // Horizontal Bar Chart Card
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: theme.colorScheme.surfaceContainer,
            borderRadius: BorderRadius.circular(AppTheme.radiusLarge),
            border: Border.all(
              color: isHighContrast
                  ? theme.colorScheme.primary.withValues(alpha: 0.3)
                  : Colors.white.withValues(alpha: 0.05),
              width: isHighContrast ? 1.5 : 1.0,
            ),
          ),
          child: Column(
            children: [
              _buildHorizontalBar(
                theme,
                label: 'Total Sales',
                value: totalSales,
                maxValue: maxValue,
                color: AppTheme.neonGreenDark,
              ),
              const SizedBox(height: 20),
              _buildHorizontalBar(
                theme,
                label: 'Total Expenses',
                value: totalExpenses,
                maxValue: maxValue,
                color: Colors.redAccent,
              ),
              const SizedBox(height: 20),
              // Profit Margin Badge
              _buildProfitMarginBadge(theme, totalSales, totalExpenses),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildHorizontalBar(
    ThemeData theme, {
    required String label,
    required double value,
    required double maxValue,
    required Color color,
  }) {
    final percentage = maxValue > 0 ? (value / maxValue) : 0.0;
    final valueString = 'RM ${_formatWithCommas(value.toStringAsFixed(0))}';

    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Text(
                label,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurface,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
            const SizedBox(width: 8),
            Text(
              valueString,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: color,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Stack(
          children: [
            Container(
              height: 12,
              width: double.infinity,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.05),
                borderRadius: BorderRadius.circular(100),
              ),
            ),
            LayoutBuilder(
              builder: (context, constraints) {
                return AnimatedContainer(
                  duration: const Duration(milliseconds: 500),
                  curve: Curves.easeOutCubic,
                  height: 12,
                  width: constraints.maxWidth * percentage.clamp(0.0, 1.0),
                  decoration: BoxDecoration(
                    color: color,
                    borderRadius: BorderRadius.circular(100),
                    boxShadow: [
                      BoxShadow(
                        color: color.withValues(alpha: 0.2),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                );
              },
            ),
          ],
        ),
      ],
    );
  }

  /// Generates and shares a PDF report for a selected date range.
  Future<void> _generatePdfReport({
    required DashboardProvider dashProv,
    required SalesProvider salesProv,
    required ExpenseProvider expProv,
  }) async {
    final result = await ReportFilterBottomSheet.show(context);
    if (result == null) return;

    final startDate = result['start']!;
    final endDate = result['end']!;

    setState(() => _isGeneratingPdf = true);
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) throw Exception('No authenticated user');

      // Aggregate data for the specific period (direct fetch for maximum accuracy)
      final firestore = FirestoreService();
      final filteredSales = await firestore.getSaleRecordsInDateRange(
        user.uid,
        startDate,
        endDate,
      );

      final filteredExpenses = await firestore.getExpensesInDateRange(
        user.uid,
        startDate,
        endDate,
      );

      final totalSales = filteredSales.fold(
        0.0,
        (sum, s) => sum + s.totalPayable,
      );
      final totalExpenses = filteredExpenses.fold(
        0.0,
        (sum, e) => sum + e.amount,
      );

      await PdfReportService.generateAndShareReport(
        businessName: _profile?.businessName ?? 'My Business',
        totalSales: totalSales,
        totalExpenses: totalExpenses,
        sales: filteredSales,
        expenses: filteredExpenses,
        startDate: startDate,
        endDate: endDate,
      );
      final String successMsg = 'PDF report generated successfully!';
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(successMsg)));
      }
    } catch (e) {
      if (mounted) {
        final String errorMsg = 'Failed to generate report: $e';
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(errorMsg)));
      }
    } finally {
      if (mounted) setState(() => _isGeneratingPdf = false);
    }
  }

  // ── Credit Score Breakdown Bars ──────────────────────────────────────────
  Widget _buildScoreBreakdown(ThemeData theme, DashboardProvider dashProv) {
    // Reverse-engineer the score components
    final score = dashProv.creditScore;
    final bool profileComplete = score >= 400; // Base(300) + Profile(100)
    final int profilePts = profileComplete ? 100 : 0;

    // Activity: 10 pts per active day, max 300
    // Estimate from remaining score after base + profile + cashflow
    final cashflowPts = dashProv.netProfit > 0
        ? (dashProv.netProfit * 0.1).round().clamp(0, 300)
        : 0;
    final activityPts = (score - 300 - profilePts - cashflowPts).clamp(0, 300);

    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 0, 24, 20),
      child: Column(
        children: [
          Divider(
            color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.08),
            height: 1,
          ),
          const SizedBox(height: 16),
          Text(
            'SCORE BREAKDOWN',
            style: theme.textTheme.labelSmall?.copyWith(
              fontWeight: FontWeight.w700,
              color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.5),
              letterSpacing: 1.2,
            ),
          ),
          const SizedBox(height: 14),
          _buildScoreBar(theme, 'Base Score', 300, 300, Colors.blueAccent),
          const SizedBox(height: 10),
          _buildScoreBar(theme, 'Business Profile', profilePts, 100, Colors.purple),
          const SizedBox(height: 10),
          _buildScoreBar(theme, 'Activity Consistency', activityPts, 300, Colors.orange),
          const SizedBox(height: 10),
          _buildScoreBar(theme, 'Cashflow Health', cashflowPts, 300, AppTheme.neonGreenDark),
        ],
      ),
    );
  }

  Widget _buildScoreBar(
    ThemeData theme, String label, int pts, int maxPts, Color color,
  ) {
    final ratio = maxPts > 0 ? (pts / maxPts).clamp(0.0, 1.0) : 0.0;
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              label,
              style: theme.textTheme.labelMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
                fontWeight: FontWeight.w500,
              ),
            ),
            Text(
              '$pts / $maxPts',
              style: theme.textTheme.labelMedium?.copyWith(
                color: color,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        Stack(
          children: [
            Container(
              height: 6,
              width: double.infinity,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.05),
                borderRadius: BorderRadius.circular(100),
              ),
            ),
            LayoutBuilder(
              builder: (context, constraints) {
                return AnimatedContainer(
                  duration: const Duration(milliseconds: 500),
                  curve: Curves.easeOutCubic,
                  height: 6,
                  width: constraints.maxWidth * ratio,
                  decoration: BoxDecoration(
                    color: color,
                    borderRadius: BorderRadius.circular(100),
                    boxShadow: [
                      BoxShadow(
                        color: color.withValues(alpha: 0.3),
                        blurRadius: 6,
                        offset: const Offset(0, 1),
                      ),
                    ],
                  ),
                );
              },
            ),
          ],
        ),
      ],
    );
  }

  // ── Profit Margin Badge ──────────────────────────────────────────────────
  Widget _buildProfitMarginBadge(
    ThemeData theme, double totalSales, double totalExpenses,
  ) {
    final netProfit = totalSales - totalExpenses;
    final margin = totalSales > 0 ? (netProfit / totalSales) * 100 : 0.0;
    final Color badgeColor;
    if (margin >= 20) {
      badgeColor = AppTheme.neonGreenDark;
    } else if (margin >= 5) {
      badgeColor = AppTheme.amber;
    } else {
      badgeColor = Colors.redAccent;
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: badgeColor.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
        border: Border.all(color: badgeColor.withValues(alpha: 0.15)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            margin >= 20
                ? Icons.trending_up_rounded
                : margin >= 5
                    ? Icons.trending_flat_rounded
                    : Icons.trending_down_rounded,
            size: 18,
            color: badgeColor,
          ),
          const SizedBox(width: 8),
          Text(
            'Profit Margin: ${margin.toStringAsFixed(1)}%',
            style: theme.textTheme.labelLarge?.copyWith(
              fontWeight: FontWeight.w700,
              color: badgeColor,
            ),
          ),
        ],
      ),
    );
  }

  String _formatWithCommas(String number) {
    final isNegative = number.startsWith('-');
    final digits = isNegative ? number.substring(1) : number;
    final buffer = StringBuffer();
    for (int i = 0; i < digits.length; i++) {
      if (i > 0 && (digits.length - i) % 3 == 0) buffer.write(',');
      buffer.write(digits[i]);
    }
    return isNegative ? '-${buffer.toString()}' : buffer.toString();
  }

  // ── iOS 26 Glass Bottom Navigation Bar ────────────────────────────────────
  Widget _buildGlassBottomNav(ThemeData theme) {
    final isHighContrast = theme.colorScheme.primary.toARGB32() == 0xFFFFFF00;
    const homeLabel = 'Home';
    const transactionsLabel = 'Sales';
    const customersLabel = 'Customer';
    const profileLabel = 'Profile';

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
      child: SafeArea(
        top: false,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(28),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 40, sigmaY: 40),
            child: Container(
              height: 72,
              decoration: BoxDecoration(
                color: isHighContrast
                    ? theme.colorScheme.surfaceContainer.withValues(alpha: 0.92)
                    : theme.colorScheme.surfaceContainer.withValues(alpha: 0.25),
                borderRadius: BorderRadius.circular(28),
                border: Border.all(
                  color: isHighContrast
                      ? theme.colorScheme.primary.withValues(alpha: 0.4)
                      : AppTheme.primaryContainer.withValues(alpha: 0.35),
                  width: isHighContrast ? 1.5 : 1.0,
                ),
                boxShadow: [
                  // Purple glow effect
                  BoxShadow(
                    color: AppTheme.primary.withValues(alpha: 0.25),
                    blurRadius: 24,
                    spreadRadius: 1,
                    offset: const Offset(0, 0),
                  ),
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.15),
                    blurRadius: 20,
                    offset: const Offset(0, -2),
                    spreadRadius: 0,
                  ),
                ],
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _buildGlassNavItem(
                    theme,
                    Icons.home_outlined,
                    Icons.home_rounded,
                    homeLabel,
                    0,
                  ),
                  _buildGlassNavItem(
                    theme,
                    Icons.receipt_long_outlined,
                    Icons.receipt_long_rounded,
                    transactionsLabel,
                    1,
                  ),
                  // ── Center Add Button ──
                  _buildGlassCenterButton(theme),
                  _buildGlassNavItem(
                    theme,
                    Icons.people_outline_rounded,
                    Icons.people_rounded,
                    customersLabel,
                    2,
                  ),
                  _buildGlassNavItem(
                    theme,
                    Icons.person_outline_rounded,
                    Icons.person_rounded,
                    profileLabel,
                    3,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildGlassNavItem(
    ThemeData theme,
    IconData icon,
    IconData activeIcon,
    String label,
    int index,
  ) {
    final isActive = _currentIndex == index;
    final activeColor = theme.colorScheme.primary;
    final inactiveColor = theme.colorScheme.onSurfaceVariant;

    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _currentIndex = index),
        behavior: HitTestBehavior.opaque,
        child: SizedBox(
          height: 72,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 200),
                child: Icon(
                  isActive ? activeIcon : icon,
                  key: ValueKey(isActive),
                  color: isActive ? activeColor : inactiveColor,
                  size: 24,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                label,
                style: theme.textTheme.labelMedium?.copyWith(
                  fontSize: 11,
                  fontWeight: isActive ? FontWeight.w700 : FontWeight.w500,
                  color: isActive ? activeColor : inactiveColor,
                  height: 1.0,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 4),
              // Active indicator dot
              AnimatedContainer(
                duration: const Duration(milliseconds: 250),
                curve: Curves.easeOutCubic,
                width: isActive ? 5 : 0,
                height: isActive ? 5 : 0,
                decoration: BoxDecoration(
                  color: activeColor,
                  shape: BoxShape.circle,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildGlassCenterButton(ThemeData theme) {
    return Expanded(
      child: GestureDetector(
        onTap: () {
          AppDialogs.showNewEntryModal(
            context,
            onRecordSale: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => ChangeNotifierProvider(
                    create: (_) => SaleCalculatorProvider(),
                    child: const RecordSaleScreen(),
                  ),
                ),
              );
            },
            onRecordExpense: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const ScannerScreen()),
              );
            },
          );
        },
        behavior: HitTestBehavior.opaque,
        child: SizedBox(
          height: 72,
          child: Center(
            child: Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    theme.colorScheme.primary,
                    theme.colorScheme.primaryContainer,
                  ],
                ),
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: theme.colorScheme.primary.withValues(alpha: 0.35),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Icon(
                Icons.add_rounded,
                color: theme.colorScheme.onPrimary,
                size: 24,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
