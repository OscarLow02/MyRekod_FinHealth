import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/app_theme.dart';
import '../../core/app_strings.dart';
import '../../providers/settings_provider.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final settingsProvider = Provider.of<SettingsProvider>(context);
    final lang = settingsProvider.currentLanguage;

    return Scaffold(
      appBar: AppBar(
        title: Text(AppStrings.get('settings', lang)),
      ),
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          // Theme Toggle
          Container(
            decoration: BoxDecoration(
              color: theme.colorScheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
            ),
            child: SwitchListTile(
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              title: Text(
                AppStrings.get('high_contrast', lang),
                style: theme.textTheme.titleMedium,
              ),
              subtitle: Padding(
                padding: const EdgeInsets.only(top: 4.0),
                child: Text(
                  AppStrings.get('high_contrast_desc', lang),
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
              value: settingsProvider.isHighContrast,
              onChanged: (value) {
                settingsProvider.setHighContrast(value);
              },
              activeThumbColor: theme.colorScheme.primary,
            ),
          ),
          const SizedBox(height: 24),

          // Language Selection
          Text(
            AppStrings.get('language', lang),
            style: theme.textTheme.titleMedium,
          ),
          const SizedBox(height: 12),
          Container(
            decoration: BoxDecoration(
              color: theme.colorScheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
            ),
            child: Column(
              children: [
                _LanguageTile(
                  title: AppStrings.get('english', lang),
                  languageCode: 'en',
                  currentLanguage: lang,
                  onTap: () => settingsProvider.setLanguage('en'),
                ),
                Divider(height: 1, color: theme.colorScheme.surface),
                _LanguageTile(
                  title: AppStrings.get('malay', lang),
                  languageCode: 'ms',
                  currentLanguage: lang,
                  onTap: () => settingsProvider.setLanguage('ms'),
                ),
                Divider(height: 1, color: theme.colorScheme.surface),
                _LanguageTile(
                  title: AppStrings.get('chinese', lang),
                  languageCode: 'zh',
                  currentLanguage: lang,
                  onTap: () => settingsProvider.setLanguage('zh'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _LanguageTile extends StatelessWidget {
  final String title;
  final String languageCode;
  final String currentLanguage;
  final VoidCallback onTap;

  const _LanguageTile({
    required this.title,
    required this.languageCode,
    required this.currentLanguage,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isSelected = languageCode == currentLanguage;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppTheme.radiusSmall),
      child: Container(
        constraints: const BoxConstraints(minHeight: AppTheme.minTouchTarget),
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              title,
              style: theme.textTheme.bodyLarge?.copyWith(
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                color: isSelected ? theme.colorScheme.primary : theme.colorScheme.onSurface,
              ),
            ),
            if (isSelected)
              Icon(
                Icons.check_circle_rounded,
                color: theme.colorScheme.primary,
              ),
          ],
        ),
      ),
    );
  }
}
