import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../core/app_theme.dart';
import '../services/firestore_service.dart';
import '../models/business_profile.dart';
import '../widgets/app_dialogs.dart';
import 'profile/profile_menu_screen.dart';
import 'transactions_screen.dart';
import 'expenses/scanner_screen.dart';

/// Dashboard screen with bottom navigation skeleton.
/// Sprint 1 placeholder — full implementation in Sprint 2.
class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  int _currentIndex = 0;
  BusinessProfile? _profile;
  bool _isLoading = true;

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
              // TODO: Sprint 3 - Implement Record Sale
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Record Sale coming soon!')),
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
    // Sprint 1: Only the Home tab has content; others are placeholders
    switch (_currentIndex) {
      case 0:
        return _buildHomePage(theme, displayName);
      case 1:
        return const TransactionsScreen();
      case 2:
        return _buildPlaceholderPage(theme, 'Customers', Icons.people_outline_rounded);
      case 3:
        return const ProfileMenuScreen();
      default:
        return _buildHomePage(theme, displayName);
    }
  }

  Widget _buildHomePage(ThemeData theme, String displayName) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 16),

          // ── Greeting ──
          Text(
            // TODO: Implement i18n
            'Welcome to MyRekod,',
            style: theme.textTheme.bodyLarge,
          ),
          const SizedBox(height: 4),
          Text(
            '$displayName!',
            style: theme.textTheme.headlineMedium,
          ),
          const SizedBox(height: 32),

          // ── Quick Stats Card (placeholder) ──
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: theme.colorScheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(AppTheme.radiusLarge),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  // TODO: Implement i18n
                  "TODAY'S SALES",
                  style: theme.textTheme.labelMedium,
                ),
                const SizedBox(height: 8),
                Text(
                  'RM 0.00',
                  style: theme.textTheme.displayMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.5,
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  // TODO: Implement i18n
                  'Start recording transactions to see your daily summary.',
                  style: theme.textTheme.bodyLarge,
                ),
              ],
            ),
          ),

          const Spacer(),

          // ── Setup Completion Badge ──
          Center(
            child: Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: 20, vertical: 12),
              decoration: BoxDecoration(
                color: AppTheme.neonGreenDark.withValues(alpha: 0.1),
                borderRadius:
                    BorderRadius.circular(AppTheme.radiusMedium),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.check_circle_rounded,
                    color: AppTheme.neonGreenDark,
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    // TODO: Implement i18n
                    'Business profile setup complete!',
                    style: theme.textTheme.labelLarge?.copyWith(
                      color: AppTheme.neonGreenDark,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Widget _buildPlaceholderPage(
      ThemeData theme, String title, IconData icon) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            size: 64,
            color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.3),
          ),
          const SizedBox(height: 16),
          Text(
            title,
            style: theme.textTheme.headlineSmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            // TODO: Implement i18n
            'Coming in Sprint 2',
            style: theme.textTheme.bodyLarge,
          ),
        ],
      ),
    );
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
