import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../core/app_theme.dart';
import '../../services/auth_service.dart';
import '../../services/firestore_service.dart';
import '../../models/business_profile.dart';
import '../auth/auth_wrapper.dart';
import 'business_profile_screen.dart';
import 'item_tax_settings_screen.dart';
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
  bool _isLoading = true;

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

    final displayName =
        _profile?.businessName ?? user?.displayName ?? 'User';
    final tinDisplay = _profile?.tinNumber ?? '—';

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 8),

          // ── Section Title ──
          Text(
            'Profile',
            style: theme.textTheme.headlineMedium,
          ),
          const SizedBox(height: 24),

          // ── User Header Card ──
          _buildHeaderCard(theme, displayName, tinDisplay),
          const SizedBox(height: 24),

          // ── Navigation Menu Tiles ──
          _buildMenuTile(
            theme,
            icon: Icons.business_center_outlined,
            title: 'Business Profile',
            onTap: () async {
              await Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => const BusinessProfileScreen(),
                ),
              );
              _loadProfile();
            },
          ),
          const SizedBox(height: 12),
          _buildMenuTile(
            theme,
            icon: Icons.receipt_long_outlined,
            title: 'Item & Tax Settings',
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => const ItemTaxSettingsScreen(),
              ),
            ),
          ),
          const SizedBox(height: 12),
          _buildMenuTile(
            theme,
            icon: Icons.translate_rounded,
            title: 'Language',
            subtitle: 'Bahasa Melayu',
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => _buildPlaceholderScreen('Language / Bahasa'),
              ),
            ),
          ),
          const SizedBox(height: 12),
          _buildMenuTile(
            theme,
            icon: Icons.help_outline_rounded,
            title: 'Help & Support',
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => _buildPlaceholderScreen('Help & Support'),
              ),
            ),
          ),
          const SizedBox(height: 32),

          // ── Log Out Button ──
          SizedBox(
            width: double.infinity,
            height: AppTheme.minTouchTarget + 8,
            child: OutlinedButton.icon(
              onPressed: _handleLogout,
              icon: const Icon(Icons.logout_rounded),
              label: const Text('Log Out'),
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.redAccent,
                side: const BorderSide(color: Colors.redAccent, width: 1.5),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),

          // ── Version Footer ──
          Center(
            child: Text(
              'VERSION 0.1.0 (BUILD 1)',
              style: theme.textTheme.labelMedium?.copyWith(
                fontSize: 11,
                letterSpacing: 1.0,
                color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.5),
              ),
            ),
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  // ── User Header Card ──
  Widget _buildHeaderCard(
      ThemeData theme, String displayName, String tinDisplay) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 28, horizontal: 20),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(AppTheme.radiusLarge),
      ),
      child: Column(
        children: [
          // Avatar
          CircleAvatar(
            radius: 36,
            backgroundColor: AppTheme.primary.withValues(alpha: 0.2),
            backgroundImage: _profile?.imageUrl != null 
                ? NetworkImage(_profile!.imageUrl!) 
                : null,
            child: _profile?.imageUrl == null
                ? Icon(
                    Icons.person_rounded,
                    size: 36,
                    color: AppTheme.primary.withValues(alpha: 0.8),
                  )
                : null,
          ),
          const SizedBox(height: 16),
          // Business Name
          Text(
            displayName,
            style: theme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.w700,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 6),
          // TIN
          Text(
            'TIN: $tinDisplay',
            style: theme.textTheme.bodyLarge?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }

  // ── Single menu navigation tile ──
  Widget _buildMenuTile(
    ThemeData theme, {
    required IconData icon,
    required String title,
    String? subtitle,
    required VoidCallback onTap,
  }) {
    return Material(
      color: theme.colorScheme.surfaceContainerHighest,
      borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
        child: Container(
          constraints: const BoxConstraints(minHeight: AppTheme.minTouchTarget + 8),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: AppTheme.primary.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(AppTheme.radiusSmall),
                ),
                child: Icon(icon, color: AppTheme.primary, size: 22),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: theme.textTheme.titleMedium,
                    ),
                    if (subtitle != null) ...[
                      const SizedBox(height: 2),
                      Text(
                        subtitle,
                        style: theme.textTheme.bodyLarge?.copyWith(
                          fontSize: 14,
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              Icon(
                Icons.chevron_right_rounded,
                color: theme.colorScheme.onSurfaceVariant,
                size: 24,
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── Placeholder screen for unimplemented menu items ──
  Widget _buildPlaceholderScreen(String title) {
    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.construction_rounded,
              size: 64,
              color: AppTheme.primary.withValues(alpha: 0.3),
            ),
            const SizedBox(height: 16),
            Text(
              title,
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Coming soon',
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey[500],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
