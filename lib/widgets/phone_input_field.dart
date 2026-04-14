import 'package:flutter/material.dart';
import '../core/app_theme.dart';
import '../core/country_codes.dart';

/// A premium phone input field with a searchable country picker.
/// Designed for "The Luminescent Vault" aesthetic.
class PhoneInputField extends StatefulWidget {
  final String label;
  final TextEditingController controller;
  final bool readOnly;
  final String? hint;

  const PhoneInputField({
    super.key,
    required this.label,
    required this.controller,
    this.readOnly = false,
    this.hint,
  });

  @override
  State<PhoneInputField> createState() => _PhoneInputFieldState();
}

class _PhoneInputFieldState extends State<PhoneInputField> {
  late Country _selectedCountry;

  @override
  void initState() {
    super.initState();
    // Default to Malaysia, or try to find country from controller text
    _selectedCountry = _findCountryFromText(widget.controller.text) ?? 
                      Country.allCountries.firstWhere((c) => c.code == 'MY');
  }

  Country? _findCountryFromText(String text) {
    if (text.isEmpty) return null;
    // Simple check: see if text starts with any of our dial codes
    // But this can be ambiguous (e.g. +1). For now, we prefer the longest match.
    Country? bestMatch;
    for (var country in Country.allCountries) {
      if (text.startsWith(country.dialCode)) {
        if (bestMatch == null || country.dialCode.length > bestMatch.dialCode.length) {
          bestMatch = country;
        }
      }
    }
    return bestMatch;
  }

  void _showCountryPicker() {
    if (widget.readOnly) return;
    
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _CountryPickerBottomSheet(
        onSelect: (country) {
          setState(() {
            _selectedCountry = country;
            // Optional: Update text if it doesn't have a dial code or has a different one
            // For now, we just update the selector.
          });
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(Icons.phone_outlined, size: 16, color: AppTheme.primary),
            const SizedBox(width: 8),
            Text(
              widget.label,
              style: theme.textTheme.labelMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        TextFormField(
          controller: widget.controller,
          readOnly: widget.readOnly,
          keyboardType: TextInputType.phone,
          style: theme.textTheme.bodyLarge,
          decoration: InputDecoration(
            hintText: widget.hint ?? '12 345 6789',
            prefixIcon: Padding(
              padding: const EdgeInsets.only(left: 4),
              child: InkWell(
                onTap: _showCountryPicker,
                borderRadius: BorderRadius.circular(AppTheme.radiusSmall),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const SizedBox(width: 12),
                    Text(_selectedCountry.flag, style: const TextStyle(fontSize: 20)),
                    const SizedBox(width: 4),
                    Icon(
                      Icons.keyboard_arrow_down_rounded, 
                      size: 16, 
                      color: theme.colorScheme.onSurfaceVariant
                    ),
                    const SizedBox(width: 8),
                    Text(
                      _selectedCountry.dialCode,
                      style: theme.textTheme.bodyLarge?.copyWith(
                        color: theme.colorScheme.onSurface,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Container(
                      width: 1,
                      height: 24,
                      color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.15),
                    ),
                    const SizedBox(width: 12),
                  ],
                ),
              ),
            ),
            filled: true,
            fillColor: widget.readOnly
                ? theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.6)
                : theme.colorScheme.surfaceContainerHighest,
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
              borderSide: BorderSide.none,
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
              borderSide: BorderSide(color: theme.colorScheme.primary, width: 1.5),
            ),
          ),
        ),
      ],
    );
  }
}

class _CountryPickerBottomSheet extends StatefulWidget {
  final ValueChanged<Country> onSelect;

  const _CountryPickerBottomSheet({required this.onSelect});

  @override
  State<_CountryPickerBottomSheet> createState() => _CountryPickerBottomSheetState();
}

class _CountryPickerBottomSheetState extends State<_CountryPickerBottomSheet> {
  final TextEditingController _searchCtrl = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final countries = Country.allCountries.where((c) =>
      c.name.toLowerCase().contains(_query.toLowerCase()) ||
      c.dialCode.contains(_query)
    ).toList();

    return Container(
      height: MediaQuery.of(context).size.height * 0.75,
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(AppTheme.radiusXLarge)),
      ),
      child: Column(
        children: [
          const SizedBox(height: 12),
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 16),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Row(
              children: [
                Text('Select Country', style: theme.textTheme.headlineSmall),
                const Spacer(),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close_rounded),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: TextField(
              controller: _searchCtrl,
              autofocus: true,
              onChanged: (val) => setState(() => _query = val),
              decoration: InputDecoration(
                hintText: 'Search by name or extension',
                prefixIcon: const Icon(Icons.search_rounded),
                filled: true,
                fillColor: theme.colorScheme.surfaceContainerHighest,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.only(bottom: 32),
              itemCount: countries.length,
              itemBuilder: (context, index) {
                final country = countries[index];
                return ListTile(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 4),
                  leading: Text(country.flag, style: const TextStyle(fontSize: 24)),
                  title: Text(
                    country.name,
                    style: theme.textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.w500),
                  ),
                  trailing: Text(
                    country.dialCode, 
                    style: theme.textTheme.bodyLarge?.copyWith(
                      fontWeight: FontWeight.w600,
                      color: AppTheme.primary,
                    ),
                  ),
                  onTap: () {
                    widget.onSelect(country);
                    Navigator.pop(context);
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
