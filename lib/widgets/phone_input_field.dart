import 'package:flutter/material.dart';
import '../core/app_theme.dart';
import '../core/validators.dart';
import '../core/country_codes.dart';

/// A premium phone input field with a searchable country picker.
/// Stores the complete international number (e.g. +60123456789) in [controller].
/// Designed for "The Luminescent Vault" aesthetic.
class PhoneInputField extends StatefulWidget {
  final String label;
  final TextEditingController controller;
  final bool readOnly;
  final String? hint;
  final String? Function(String?)? validator;

  const PhoneInputField({
    super.key,
    required this.label,
    required this.controller,
    this.readOnly = false,
    this.hint,
    this.validator,
  });

  @override
  State<PhoneInputField> createState() => _PhoneInputFieldState();
}

class _PhoneInputFieldState extends State<PhoneInputField> {
  late Country _selectedCountry;
  late final TextEditingController _localCtrl;

  @override
  void initState() {
    super.initState();
    // Parse existing value from controller (e.g. "+60123456789" → country MY, local "123456789")
    _selectedCountry = _parseCountry(widget.controller.text) ??
        Country.allCountries.firstWhere((c) => c.code == 'MY');
    _localCtrl = TextEditingController(
      text:
          _extractLocalNumber(widget.controller.text, _selectedCountry.dialCode),
    );
    // Keep external controller up to date whenever local digits change
    _localCtrl.addListener(_syncExternalController);
  }

  @override
  void dispose() {
    _localCtrl.dispose();
    super.dispose();
  }

  Country? _parseCountry(String text) {
    if (text.isEmpty) return null;
    final cleaned = text.replaceAll(RegExp(r'[\s\-]'), '');
    Country? best;
    for (final c in Country.allCountries) {
      if (cleaned.startsWith(c.dialCode)) {
        if (best == null || c.dialCode.length > best.dialCode.length) {
          best = c;
        }
      }
    }
    return best;
  }

  String _extractLocalNumber(String full, String dialCode) {
    final cleaned = full.replaceAll(RegExp(r'[\s\-]'), '');
    if (cleaned.startsWith(dialCode)) {
      return cleaned.substring(dialCode.length);
    }
    return cleaned.startsWith('+') ? '' : cleaned;
  }

  void _syncExternalController() {
    final full = '${_selectedCountry.dialCode}${_localCtrl.text.trimLeft()}';
    if (widget.controller.text != full) {
      widget.controller.value = TextEditingValue(text: full);
    }
  }

  void _onCountryChanged(Country country) {
    setState(() => _selectedCountry = country);
    _syncExternalController();
  }

  void _showCountryPicker() {
    if (widget.readOnly) return;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _CountryPickerBottomSheet(
        onSelect: _onCountryChanged,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final borderColor = AppTheme.secondaryDark; // #B6A4F3

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
          controller: _localCtrl,
          readOnly: widget.readOnly,
          keyboardType: TextInputType.phone,
          style: theme.textTheme.bodyLarge,
          // Validate using the full external controller value so the dial code is included
          validator: widget.validator ??
              ((_) => AppValidators.phone(widget.controller.text)),
          decoration: InputDecoration(
            hintText: widget.hint ?? '12 345 6789',
            prefixIcon: Padding(
              padding: const EdgeInsets.only(left: 4),
              child: InkWell(
                onTap: widget.readOnly ? null : _showCountryPicker,
                borderRadius: BorderRadius.circular(AppTheme.radiusSmall),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const SizedBox(width: 12),
                    // Country code letters (flag emojis fail on iOS Simulator so use code)
                    Text(
                      _selectedCountry.code,
                      style: const TextStyle(
                          fontSize: 14, fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(width: 4),
                    if (!widget.readOnly)
                      Icon(
                        Icons.keyboard_arrow_down_rounded,
                        size: 16,
                        color: theme.colorScheme.onSurfaceVariant,
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
                      color: theme.colorScheme.onSurfaceVariant
                          .withValues(alpha: 0.15),
                    ),
                    const SizedBox(width: 12),
                  ],
                ),
              ),
            ),
            filled: false,
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
              borderSide: BorderSide(
                  color: borderColor.withValues(alpha: 0.5), width: 1),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
              borderSide: BorderSide(color: borderColor, width: 1.5),
            ),
            errorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
              borderSide: BorderSide(color: theme.colorScheme.error, width: 1.5),
            ),
            focusedErrorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
              borderSide: BorderSide(color: theme.colorScheme.error, width: 1.5),
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
  State<_CountryPickerBottomSheet> createState() =>
      _CountryPickerBottomSheetState();
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
    final borderColor = AppTheme.secondaryDark; // #B6A4F3
    final countries = Country.allCountries
        .where((c) =>
            c.name.toLowerCase().contains(_query.toLowerCase()) ||
            c.dialCode.contains(_query) ||
            c.code.toLowerCase().contains(_query.toLowerCase()))
        .toList();

    return Container(
      height: MediaQuery.of(context).size.height * 0.75,
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: const BorderRadius.vertical(
            top: Radius.circular(AppTheme.radiusXLarge)),
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
                hintText: 'Search by name or dial code',
                prefixIcon: const Icon(Icons.search_rounded),
                filled: true,
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
                  borderSide: BorderSide(
                      color: borderColor.withValues(alpha: 0.5), width: 1),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
                  borderSide: BorderSide(color: borderColor, width: 1.5),
                ),
                contentPadding:
                    const EdgeInsets.symmetric(vertical: 0, horizontal: 12),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Expanded(
            child: countries.isEmpty
                ? Center(
                    child: Text(
                      'No countries found',
                      style: theme.textTheme.bodyLarge?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.only(bottom: 32),
                    itemCount: countries.length,
                    itemBuilder: (context, index) {
                      final country = countries[index];
                      return ListTile(
                        contentPadding: const EdgeInsets.symmetric(
                            horizontal: 24, vertical: 2),
                        leading: CircleAvatar(
                          radius: 18,
                          backgroundColor:
                              AppTheme.primary.withValues(alpha: 0.1),
                          child: Text(
                            country.code,
                            style: const TextStyle(
                                fontSize: 11, fontWeight: FontWeight.w700),
                          ),
                        ),
                        title: Text(
                          country.name,
                          style: theme.textTheme.bodyLarge
                              ?.copyWith(fontWeight: FontWeight.w500),
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
