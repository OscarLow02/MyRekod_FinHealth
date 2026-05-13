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
      final profile =
          await FirestoreService().getBusinessProfile(user.uid);
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

    final displayName = _profile?.businessName ??
        user?.displayName ??
        'User';

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _buildCurrentPage(theme, displayName),
      bottomNavigationBar: _buildBottomNav(theme),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
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
        child: const Icon(Icons.add_rounded, size: 28),
      ),
      floatingActionButtonLocation:
          FloatingActionButtonLocation.centerDocked,
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

        // TODO: Implement i18n
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
                      padding: const EdgeInsets.fromLTRB(24, 16, 24, 0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            welcomeLabel,
                            style: theme.textTheme.labelMedium?.copyWith(
                              color: theme.colorScheme.secondary,
                              fontWeight: FontWeight.w500,
                              letterSpacing: 0.5,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            businessName,
                            style: theme.textTheme.headlineSmall?.copyWith(
                              fontWeight: FontWeight.w700,
                              color: Colors.white,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),

                    // ── Section 2: Overlapping Hero Card ──────────────────
                    if (hasData) ...[
                      const SizedBox(height: 40),
                      Transform(
                        transform: Matrix4.translationValues(0.0, -40.0, 0.0),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 20),
                          child: Container(
                            decoration: BoxDecoration(
                              color: AppTheme.darkSurfaceContainer.withValues(alpha: 0.85),
                              borderRadius: BorderRadius.circular(AppTheme.radiusXLarge),
                              border: Border.all(
                                color: Colors.white.withValues(alpha: 0.05),
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.3),
                                  blurRadius: 24,
                                  offset: const Offset(0, 8),
                                ),
                              ],
                            ),
                            child: Stack(
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
                              const SizedBox(width: 16),
                              _buildQuickAction(
                                context,
                                icon: Icons.qr_code_scanner_rounded,
                                label: 'Record\nExpense',
                                color: Colors.redAccent,
                                onTap: () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                        builder: (_) => const ScannerScreen()),
                                  );
                                },
                              ),
                              const SizedBox(width: 16),
                              _buildQuickAction(
                                context,
                                icon: Icons.description_outlined,
                                label: 'Generate\nReport',
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
                                color: theme.colorScheme.primary
                                    .withValues(alpha: 0.05),
                                shape: BoxShape.circle,
                              ),
                              child: Center(
                                child: Icon(
                                  Icons.insights_rounded,
                                  size: 100,
                                  color: theme.colorScheme.primary
                                      .withValues(alpha: 0.3),
                                ),
                              ),
                            ),
                            const SizedBox(height: 40),
                            Padding(
                              padding:
                                  const EdgeInsets.symmetric(horizontal: 24),
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
                      : AppTheme.darkSurfaceContainer,
                  shape: BoxShape.circle,
                  border: isPrimary
                      ? null
                      : Border.all(
                          color: Colors.white.withValues(alpha: 0.05),
                        ),
                  boxShadow: isPrimary
                      ? [
                          BoxShadow(
                            color: theme.colorScheme.primary
                                .withValues(alpha: 0.3),
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
                    ? const SizedBox(
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 2.5,
                        ),
                      )
                    : Icon(icon, color: color, size: 28),
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
    final isPositive = dashProv.netProfit >= 0;
    final profitParts = dashProv.netProfit.toStringAsFixed(2).split('.');
    // TODO: Implement i18n
    const netProfitLabel = 'Net Profit (Current Month)';
    const trendLabel = '↗ 12% vs last month'; // Mocked trend

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: AppTheme.darkSurfaceContainer,
        borderRadius: BorderRadius.circular(AppTheme.radiusXLarge),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.05),
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
                color: AppTheme.neonGreenDark.withValues(alpha: 0.08),
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
              Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    'RM ${_formatWithCommas(profitParts[0])}',
                    style: theme.textTheme.displayMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                      fontSize: 32,
                      letterSpacing: -0.5,
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: Text(
                      '.${profitParts[1]}',
                      style: theme.textTheme.titleLarge?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              // Trend pill chip
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                decoration: BoxDecoration(
                  color: (isPositive
                          ? AppTheme.neonGreenDark
                          : theme.colorScheme.error)
                      .withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(100),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.trending_up_rounded,
                      size: 16,
                      color: isPositive
                          ? AppTheme.neonGreenDark
                          : theme.colorScheme.error,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      trendLabel,
                      style: theme.textTheme.labelMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                        color: isPositive
                            ? AppTheme.neonGreenDark
                            : theme.colorScheme.error,
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
    // TODO: Implement i18n
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
            Column(
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
              child: Row(
                mainAxisSize: MainAxisSize.min,
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
            color: AppTheme.darkSurfaceContainer,
            borderRadius: BorderRadius.circular(AppTheme.radiusLarge),
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.05),
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
          children: [
            Text(
              label,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurface,
                fontWeight: FontWeight.w500,
              ),
            ),
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
      // Aggregate data for the specific period (bypassing UI pagination limits)
      final filteredSales = salesProv.getRecordsInRange(startDate, endDate);
      final filteredExpenses = expProv.getRecordsInRange(startDate, endDate);

      final totalSales = filteredSales.fold(0.0, (sum, s) => sum + s.totalPayable);
      final totalExpenses = filteredExpenses.fold(0.0, (sum, e) => sum + e.amount);

      await PdfReportService.generateAndShareReport(
        businessName: _profile?.businessName ?? 'My Business',
        totalSales: totalSales,
        totalExpenses: totalExpenses,
        sales: filteredSales,
        expenses: filteredExpenses,
        startDate: startDate,
        endDate: endDate,
      );
      if (mounted) {
        // TODO: Implement i18n
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('PDF report generated successfully!')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to generate report: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isGeneratingPdf = false);
    }
  }

  /// Adds commas to number strings (e.g. "10081" → "10,081").
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

  Widget _buildBottomNav(ThemeData theme) {
    // TODO: Implement i18n
    const homeLabel = 'Home';
    const transactionsLabel = 'Transactions';
    const customersLabel = 'Customers';
    const profileLabel = 'Profile';

    return BottomAppBar(
      color: theme.bottomNavigationBarTheme.backgroundColor,
      shape: const CircularNotchedRectangle(),
      notchMargin: 8,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _buildNavItem(theme, Icons.home_outlined, Icons.home_rounded,
              homeLabel, 0),
          _buildNavItem(
              theme,
              Icons.receipt_long_outlined,
              Icons.receipt_long_rounded,
              transactionsLabel,
              1),
          const SizedBox(width: 48), // Space for FAB
          _buildNavItem(theme, Icons.people_outline_rounded,
              Icons.people_rounded, customersLabel, 2),
          _buildNavItem(
              theme,
              Icons.person_outline_rounded,
              Icons.person_rounded,
              profileLabel,
              3),
        ],
      ),
    );
  }

  Widget _buildNavItem(ThemeData theme, IconData icon,
      IconData activeIcon, String label, int index) {
    final isActive = _currentIndex == index;
    final color = isActive
        ? AppTheme.primary
        : theme.colorScheme.onSurfaceVariant;

    return InkWell(
      onTap: () => setState(() => _currentIndex = index),
      borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
      child: SizedBox(
        width: AppTheme.minTouchTarget + 16,
        height: AppTheme.minTouchTarget,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              isActive ? activeIcon : icon,
              color: color,
              size: 24,
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: TextStyle(
                fontSize: 10,
                fontWeight:
                    isActive ? FontWeight.w600 : FontWeight.w400,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
