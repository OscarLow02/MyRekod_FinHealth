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
import 'package:myrekod/providers/sale_calculator_provider.dart';
import 'package:myrekod/screens/sales/record_sale_screen.dart';
import 'package:myrekod/widgets/app_dialogs.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setupFirebaseCoreMocks();

  setUpAll(() async {
    await Firebase.initializeApp();
  });

  testWidgets('RecordSaleScreen layout under High Contrast does not overflow', (WidgetTester tester) async {
    SharedPreferences.setMockInitialValues({});
    
    // Set up standard mobile screen size
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
          ChangeNotifierProvider(create: (_) => DashboardProvider()),
          ChangeNotifierProvider(create: (_) => SaleCalculatorProvider()),
        ],
        child: Consumer<SettingsProvider>(
          builder: (context, settings, child) {
            return MaterialApp(
              theme: AppTheme.highContrastTheme,
              home: const RecordSaleScreen(),
            );
          },
        ),
      ),
    );

    await tester.pumpAndSettle();
  });

  testWidgets('showMockLhdnSuccessDialog under High Contrast does not overflow', (WidgetTester tester) async {
    SharedPreferences.setMockInitialValues({});
    
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
          ChangeNotifierProvider(create: (_) => DashboardProvider()),
        ],
        child: Consumer<SettingsProvider>(
          builder: (context, settings, child) {
            return MaterialApp(
              theme: AppTheme.highContrastTheme,
              home: Scaffold(
                body: Builder(
                  builder: (context) {
                    return ElevatedButton(
                      onPressed: () {
                        AppDialogs.showMockLhdnSuccessDialog(
                          context,
                          invoiceNumber: 'INV-2026-0001',
                          totalAmount: 1500.00,
                          onDone: () {},
                          isLhdnSubmitted: true,
                        );
                      },
                      child: const Text('Show Dialog'),
                    );
                  },
                ),
              ),
            );
          },
        ),
      ),
    );

    await tester.tap(find.text('Show Dialog'));
    await tester.pumpAndSettle();

    expect(find.byType(Dialog), findsOneWidget);
    expect(find.text('LHDN Submission Successful'), findsOneWidget);
  });
}
