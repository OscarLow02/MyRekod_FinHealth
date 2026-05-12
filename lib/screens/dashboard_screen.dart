import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:provider/provider.dart';
import '../core/app_theme.dart';
import '../services/firestore_service.dart';
import '../models/business_profile.dart';
import '../providers/sales_provider.dart';
import '../providers/expense_provider.dart';
import '../providers/dashboard_provider.dart';
import '../providers/sale_calculator_provider.dart';
import '../widgets/app_dialogs.dart';
import '../widgets/cashflow_bar_chart.dart';
import '../widgets/credit_score_gauge.dart';
import '../services/pdf_report_service.dart';
import 'profile/profile_menu_screen.dart';
import 'transactions_screen.dart';
import 'expenses/scanner_screen.dart';
import 'sales/record_sale_screen.dart';
import 'customers/customer_list_screen.dart';

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

    // Resolve display name from profile or Firebase user
    final displayName = _profile?.businessName ??
        user?.displayName ??
        'User';

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: SafeArea(
        child: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : _buildCurrentPage(theme, displayName),
      ),
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

  Widget _buildHomePage(ThemeData theme, String displayName) {
    return Consumer3<SalesProvider, ExpenseProvider, DashboardProvider>(
      builder: (context, salesProv, expProv, dashProv, _) {
        // Re-aggregate monthly data whenever upstream providers change
        WidgetsBinding.instance.addPostFrameCallback((_) {
          dashProv.aggregateMonthlyData(
            salesProv.saleRecords,
            expProv.expenses,
            profile: _profile,
          );
        });

        final hasData = !dashProv.hasNoData;
        final String greetingText = "Selamat Pagi, $displayName!"; 
        const String zeroStateText = "No sales recorded today!\nTap the '+' to start your streak."; // TODO: Implement i18n

    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // --- Header Section ---
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  greetingText,
                  style: theme.textTheme.headlineMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              Row(
                children: [
                  _buildHeaderButton(
                    context, 
                    icon: Icons.language_rounded, 
                    onPressed: () {}, // TODO: Implement Language Settings
                  ),
                  const SizedBox(width: 12),
                  _buildHeaderButton(
                    context, 
                    icon: Icons.settings_rounded, 
                    onPressed: () {}, // TODO: Implement Settings
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 32),

          // --- Conditional Body ---
          if (hasData) ...[
            // Hero Card: Credit Score Gauge
            CreditScoreGauge(score: dashProv.creditScore),
            const SizedBox(height: 24),
            
            // Native Bar Chart: Sales vs. Expenses
            CashflowBarChart(
              totalSales: dashProv.totalMonthlySales,
              totalExpenses: dashProv.totalMonthlyExpenses,
            ),
            const SizedBox(height: 24),
            
            // PDF Export Button (48dp min touch target via ElevatedButton theme)
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _isGeneratingPdf
                    ? null
                    : () => _generatePdfReport(
                          dashProv: dashProv,
                          salesProv: salesProv,
                          expProv: expProv,
                        ),
                icon: _isGeneratingPdf
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(Icons.picture_as_pdf_rounded),
                // TODO: Implement i18n
                label: Text(
                  _isGeneratingPdf
                      ? 'Generating...'
                      : 'Generate Monthly PDF Report',
                ),
              ),
            ),
            const SizedBox(height: 80), // Padding for FAB
          ] else ...[
            // --- Zero-State UI ---
            const SizedBox(height: 80),
            Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Friendly Illustration Placeholder
                  Container(
                    width: 220,
                    height: 220,
                    decoration: BoxDecoration(
                      color: theme.colorScheme.primary.withValues(alpha: 0.05),
                      shape: BoxShape.circle,
                    ),
                    child: Center(
                      child: Icon(
                        Icons.insights_rounded,
                        size: 100,
                        color: theme.colorScheme.primary.withValues(alpha: 0.3),
                      ),
                    ),
                  ),
                  const SizedBox(height: 40),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
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
    );
  },
);
}

  /// Builds a header button with 48dp touch target as per requirements
  Widget _buildHeaderButton(BuildContext context, {required IconData icon, required VoidCallback onPressed}) {
    return Container(
      width: 48,
      height: 48,
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest.withValues(alpha: 0.4),
        borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
      ),
      child: IconButton(
        iconSize: 24,
        padding: EdgeInsets.zero,
        constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
        icon: Icon(icon, color: Theme.of(context).colorScheme.onSurface),
        onPressed: onPressed,
      ),
    );
  }

  /// Generates and shares the monthly PDF report via native share dialog.
  Future<void> _generatePdfReport({
    required DashboardProvider dashProv,
    required SalesProvider salesProv,
    required ExpenseProvider expProv,
  }) async {
    setState(() => _isGeneratingPdf = true);
    try {
      await PdfReportService.generateAndShareMonthlyReport(
        businessName: _profile?.businessName ?? 'My Business',
        totalSales: dashProv.totalMonthlySales,
        totalExpenses: dashProv.totalMonthlyExpenses,
        sales: salesProv.saleRecords,
        expenses: expProv.expenses,
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
