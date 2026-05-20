import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../core/app_theme.dart';
import '../../services/auth_service.dart';
import '../../services/firestore_service.dart';
import '../../models/business_profile.dart';
import '../auth/auth_wrapper.dart';
import 'business_profile_screen.dart';
import 'item_settings_screen.dart';
import 'tax_settings_screen.dart';
import 'theme_settings_screen.dart';
import '../../widgets/app_dialogs.dart';

/// Main Profile menu screen — matches the "Luminescent Vault" design.
/// Shows user header card, navigation tiles, and logout button.
class ProfileMenuScreen extends StatefulWidget {
  const ProfileMenuScreen({super.key});

  @override
  State<ProfileMenuScreen> createState() => _ProfileMenuScreenState();
}

class _ProfileMenuScreenState extends State<ProfileMenuScreen> {
  BusinessProfile? _profile;

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
        });
      }
    } else {
      // No user, nothing to load
    }
  }

  Future<void> _handleLogout() async {
    AppDialogs.showActionModal(
      context,
      title: 'Log Out',
      body: 'Are you sure you want to log out?',
      primaryButtonText: 'Log Out',
      primaryButtonColor: Colors.redAccent,
      icon: Icons.logout_rounded,
      onPrimaryPressed: () async {
        if (!mounted) return;
        await AuthService().signOut();
        if (!mounted) return;
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (_) => const AuthWrapper()),
          (route) => false,
        );
      },
      secondaryButtonText: 'Cancel',
      onSecondaryPressed: () {},
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final user = FirebaseAuth.instance.currentUser;

    final displayName = _profile?.businessName ?? user?.displayName ?? 'User';
    final tinDisplay = _profile?.tinNumber ?? '—';

    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 40),

          // ── Section Title ──
          Text(
            'Profile',
            style: theme.textTheme.headlineMedium?.copyWith(
              fontWeight: FontWeight.w800,
              letterSpacing: -0.3,
            ),
          ),
          const SizedBox(height: 28),

          // ── Avatar + Name (Floating Style) ──
          _buildAvatarSection(theme, displayName, tinDisplay, user?.email),
          const SizedBox(height: 20),

          // ── Profile Completion Indicator ──
          if (_profile != null)
            _buildProfileCompletionCard(theme),
          const SizedBox(height: 28),

          // ── Section 1: Business Settings ──
          _buildSectionLabel(theme, 'BUSINESS'),
          const SizedBox(height: 10),
          _buildMenuSection(theme, items: [
            _MenuItem(
              icon: Icons.business_center_outlined,
              title: 'Business Profile',
              subtitle: 'TIN, BRN & company details',
              onTap: () async {
                await Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => const BusinessProfileScreen(),
                  ),
                );
                _loadProfile();
              },
            ),
            _MenuItem(
              icon: Icons.inventory_2_outlined,
              title: 'Item Settings',
              subtitle: 'Manage your item catalog & categories',
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const ItemSettingsScreen()),
              ),
            ),
          ]),
          const SizedBox(height: 20),

          // ── Section 2: App Settings ──
          _buildSectionLabel(theme, 'APP SETTINGS'),
          const SizedBox(height: 10),
          _buildMenuSection(theme, items: [
            _MenuItem(
              icon: Icons.account_balance_outlined,
              title: 'Tax Settings',
              subtitle: 'LHDN tax type & calculation rules',
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const TaxSettingsScreen()),
              ),
            ),
            _MenuItem(
              icon: Icons.palette_outlined,
              title: 'App Theme Settings',
              subtitle: 'High contrast & accessibility',
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const ThemeSettingsScreen()),
              ),
            ),
          ]),
          const SizedBox(height: 20),

          // ── Section 3: Log Out (standalone) ──
          _buildLogoutCard(theme),
          const SizedBox(height: 20),

          // ── Version Footer ──
          Center(
            child: Text(
              'VERSION 0.1.0 (BUILD 1)',
              style: theme.textTheme.labelMedium?.copyWith(
                fontSize: 11,
                letterSpacing: 1.0,
                color: theme.colorScheme.onSurfaceVariant.withValues(
                  alpha: 0.5,
                ),
              ),
            ),
          ),
          const SizedBox(height: 100), // Bottom padding for nav bar clearance
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // Avatar + Name Section (floating style, no card wrapper)
  // ═══════════════════════════════════════════════════════════════════════════
  Widget _buildAvatarSection(
    ThemeData theme,
    String displayName,
    String tinDisplay,
    String? email,
  ) {
    return Center(
      child: Column(
        children: [
          // ── Avatar with Edit Badge ──
          Stack(
            clipBehavior: Clip.none,
            children: [
              // Purple outer ring
              Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      AppTheme.primary.withValues(alpha: 0.6),
                      AppTheme.primaryContainer.withValues(alpha: 0.3),
                    ],
                  ),
                ),
                child: CircleAvatar(
                  radius: 52,
                  backgroundColor:
                      theme.colorScheme.surfaceContainerHighest,
                  backgroundImage: _profile?.imageUrl != null
                      ? NetworkImage(_profile!.imageUrl!)
                      : null,
                  child: _profile?.imageUrl == null
                      ? Icon(
                          Icons.person_rounded,
                          size: 48,
                          color: AppTheme.primary.withValues(alpha: 0.6),
                        )
                      : null,
                ),
              ),
              // Edit badge
              Positioned(
                bottom: 2,
                right: 2,
                child: GestureDetector(
                  onTap: () async {
                    await Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => const BusinessProfileScreen(),
                      ),
                    );
                    _loadProfile();
                  },
                  child: Container(
                    width: 34,
                    height: 34,
                    decoration: BoxDecoration(
                      color: AppTheme.primary,
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: theme.scaffoldBackgroundColor,
                        width: 3,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: AppTheme.primary.withValues(alpha: 0.4),
                          blurRadius: 8,
                          spreadRadius: 1,
                        ),
                      ],
                    ),
                    child: const Icon(
                      Icons.edit_rounded,
                      size: 16,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          // Business Name
          Text(
            displayName,
            style: theme.textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.w700,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 6),
          // TIN chip
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
            decoration: BoxDecoration(
              color: AppTheme.primary.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: AppTheme.primary.withValues(alpha: 0.2),
              ),
            ),
            child: Text(
              'TIN: $tinDisplay',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
                fontWeight: FontWeight.w500,
                letterSpacing: 0.5,
              ),
            ),
          ),
          // User email
          if (email != null && email.isNotEmpty) ...[
            const SizedBox(height: 8),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.email_outlined,
                  size: 14,
                  color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.5),
                ),
                const SizedBox(width: 6),
                Text(
                  email,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.6),
                    fontWeight: FontWeight.w400,
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // Grouped Menu Section (card with dividers between items)
  // ═══════════════════════════════════════════════════════════════════════════
  Widget _buildMenuSection(ThemeData theme, {required List<_MenuItem> items}) {
    return Container(
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(AppTheme.radiusLarge),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.04),
        ),
      ),
      child: Column(
        children: [
          for (int i = 0; i < items.length; i++) ...[
            _buildMenuRow(theme, items[i]),
            if (i < items.length - 1)
              Divider(
                height: 1,
                indent: 68, // Aligns with text start (16 + 40 icon + 12 gap)
                endIndent: 16,
                color: Colors.white.withValues(alpha: 0.06),
              ),
          ],
        ],
      ),
    );
  }

  Widget _buildSectionLabel(ThemeData theme, String label) {
    return Padding(
      padding: const EdgeInsets.only(left: 4),
      child: Text(
        label,
        style: theme.textTheme.labelSmall?.copyWith(
          fontWeight: FontWeight.w700,
          letterSpacing: 1.2,
          color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.5),
          fontSize: 11,
        ),
      ),
    );
  }

  Widget _buildMenuRow(ThemeData theme, _MenuItem item) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: item.onTap,
        borderRadius: BorderRadius.circular(AppTheme.radiusLarge),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(
            children: [
              // Icon container
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: AppTheme.primary.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(AppTheme.radiusSmall),
                ),
                child: Icon(item.icon, color: AppTheme.primary, size: 22),
              ),
              const SizedBox(width: 12),
              // Title + subtitle
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.title,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    if (item.subtitle != null) ...[
                      const SizedBox(height: 2),
                      Text(
                        item.subtitle!,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.6),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              // Chevron
              Icon(
                Icons.chevron_right_rounded,
                color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.5),
                size: 22,
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // Logout Card (standalone, red accent)
  // ═══════════════════════════════════════════════════════════════════════════
  Widget _buildLogoutCard(ThemeData theme) {
    return Container(
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(AppTheme.radiusLarge),
        border: Border.all(
          color: Colors.redAccent.withValues(alpha: 0.12),
        ),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: _handleLogout,
          borderRadius: BorderRadius.circular(AppTheme.radiusLarge),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
            child: Row(
              children: [
                // Red icon container
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: Colors.redAccent.withValues(alpha: 0.12),
                    borderRadius:
                        BorderRadius.circular(AppTheme.radiusSmall),
                  ),
                  child: const Icon(
                    Icons.logout_rounded,
                    color: Colors.redAccent,
                    size: 22,
                  ),
                ),
                const SizedBox(width: 12),
                // Title
                Expanded(
                  child: Text(
                    'Log Out',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w500,
                      color: Colors.redAccent,
                    ),
                  ),
                ),
                Icon(
                  Icons.chevron_right_rounded,
                  color: Colors.redAccent.withValues(alpha: 0.5),
                  size: 22,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ── Profile Completion Helpers ──

  double _calculateProfileCompletion() {
    if (_profile == null) return 0.0;
    final p = _profile!;
    final checks = [
      p.businessName.isNotEmpty,
      p.tinNumber.isNotEmpty,
      p.brnNumber.isNotEmpty,
      p.msicCode.isNotEmpty,
      p.businessActivityDescription.isNotEmpty,
      p.email.isNotEmpty,
      p.phoneNumber.isNotEmpty,
      p.addressLine1.isNotEmpty,
      p.city.isNotEmpty,
      p.stateCode.isNotEmpty,
      p.postalCode.isNotEmpty,
    ];
    final filled = checks.where((c) => c).length;
    return filled / checks.length;
  }

  Widget _buildProfileCompletionCard(ThemeData theme) {
    final pct = _calculateProfileCompletion();
    final pctInt = (pct * 100).round();
    final isComplete = pctInt >= 100;

    final barColor = isComplete
        ? AppTheme.neonGreenDark
        : (pctInt >= 70 ? Colors.amber : theme.colorScheme.primary);

    final label = isComplete
        ? 'Profile complete — LHDN ready!'
        : '$pctInt% complete • fill in missing fields for LHDN compliance';

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
        border: Border.all(
          color: barColor.withValues(alpha: 0.2),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                isComplete ? Icons.check_circle_rounded : Icons.pie_chart_rounded,
                size: 18,
                color: barColor,
              ),
              const SizedBox(width: 8),
              Text(
                'Profile Completion',
                style: theme.textTheme.labelMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: theme.colorScheme.onSurface,
                ),
              ),
              const Spacer(),
              Text(
                '$pctInt%',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w800,
                  color: barColor,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: pct,
              minHeight: 6,
              backgroundColor: barColor.withValues(alpha: 0.12),
              valueColor: AlwaysStoppedAnimation<Color>(barColor),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            label,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.6),
              fontSize: 11,
            ),
          ),
        ],
      ),
    );
  }
}

/// Internal model for a menu item.
class _MenuItem {
  final IconData icon;
  final String title;
  final String? subtitle;
  final VoidCallback onTap;

  const _MenuItem({
    required this.icon,
    required this.title,
    this.subtitle,
    required this.onTap,
  });
}
