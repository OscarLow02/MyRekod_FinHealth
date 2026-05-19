import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_core_platform_interface/test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:myrekod/core/app_theme.dart';
import 'package:myrekod/providers/settings_provider.dart';
import 'package:myrekod/providers/customer_provider.dart';
import 'package:myrekod/providers/sales_provider.dart';
import 'package:myrekod/providers/expense_provider.dart';
import 'package:myrekod/providers/onboarding_provider.dart';
import 'package:myrekod/providers/dashboard_provider.dart';
import 'package:myrekod/screens/dashboard_screen.dart';
import 'package:myrekod/widgets/cashflow_chart.dart';
import 'package:fl_chart/fl_chart.dart';

class MockDashboardProvider extends DashboardProvider {
  @override
  double get totalMonthlySales => 12500.50;

  @override
  double get totalMonthlyExpenses => 4200.75;

  @override
  bool get hasNoData => false;

  @override
  int get creditScore => 750;

  @override
  List<FlSpot> getSalesSpots(ChartPeriod period) => [
        const FlSpot(1, 1000),
        const FlSpot(2, 2000),
        const FlSpot(3, 1500),
      ];

  @override
  List<FlSpot> getExpenseSpots(ChartPeriod period) => [
        const FlSpot(1, 500),
        const FlSpot(2, 800),
        const FlSpot(3, 600),
      ];
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setupFirebaseCoreMocks();

  setUpAll(() async {
    await Firebase.initializeApp();
  });

  testWidgets('DashboardScreen layout under High Contrast does not overflow', (WidgetTester tester) async {
    SharedPreferences.setMockInitialValues({});
    
    // Set up standard mobile screen size (simulating typical B40 device)
    tester.binding.window.physicalSizeTestValue = const Size(360 * 3.0, 640 * 3.0);
    tester.binding.window.devicePixelRatioTestValue = 3.0;
    addTearDown(tester.binding.window.clearPhysicalSizeTestValue);

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider(create: (_) => SettingsProvider()..setHighContrast(true)),
          ChangeNotifierProvider(create: (_) => OnboardingProvider()),
          ChangeNotifierProvider(create: (_) => ExpenseProvider()),
          ChangeNotifierProvider(create: (_) => SalesProvider()),
          ChangeNotifierProvider(create: (_) => CustomerProvider()),
          ChangeNotifierProvider<DashboardProvider>(create: (_) => MockDashboardProvider()),
        ],
        child: Consumer<SettingsProvider>(
          builder: (context, settings, child) {
            return MaterialApp(
              theme: AppTheme.highContrastTheme,
              home: const DashboardScreen(),
            );
          },
        ),
      ),
    );

    await tester.pumpAndSettle();
  });
}
