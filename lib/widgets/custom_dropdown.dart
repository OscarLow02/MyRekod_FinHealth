import 'package:flutter/material.dart';
import '../core/app_theme.dart';

/// A premium, highly customizable dropdown item.
class CustomDropdownItem<T> {
  final String label;
  final IconData? icon;
  final String? emoji; // Useful for flags
  final T value;

  const CustomDropdownItem({
    required this.label,
    this.icon,
    this.emoji,
    required this.value,
  });
}

/// A premium dropdown component designed for "The Luminescent Vault" aesthetic.
/// Opens a full-page bottom sheet for item selection to avoid overflow issues.
class CustomPremiumDropdown<T> extends StatelessWidget {
  final String label;
  final List<CustomDropdownItem<T>> items;
  final T? value;
  final ValueChanged<T?> onChanged;
  final String? hint;
  final bool isEditMode;
  final bool isSearchable;
  final Color? fillColor;

  const CustomPremiumDropdown({
    super.key,
    required this.label,
    required this.items,
    required this.value,
    required this.onChanged,
    this.hint,
    this.isEditMode = true,
    this.isSearchable = false,
    this.fillColor,
    this.validator,
  });

  final String? Function(T?)? validator;

  Future<void> _openSelectionSheet(BuildContext context, FormFieldState<T> state) {
    return showModalBottomSheet<T>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _DropdownSelectionSheet<T>(
        title: label,
        items: items,
        selectedValue: value,
        isSearchable: isSearchable,
      ),
    ).then((selected) {
      if (selected != null) {
        onChanged(selected);
        state.didChange(selected);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final selectedItem = items.any((i) => i.value == value)
        ? items.firstWhere((i) => i.value == value)
        : null;

    return FormField<T>(
      validator: validator,
      initialValue: value,
      builder: (FormFieldState<T> state) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
        // Label
        Row(
          children: [
            if (selectedItem?.icon != null) ...[
              Icon(selectedItem!.icon, size: 16, color: AppTheme.primary),
              const SizedBox(width: 8),
            ],
            Text(
              label,
              style: theme.textTheme.labelMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),

        // Trigger button
        InkWell(
          onTap: isEditMode ? () => _openSelectionSheet(context, state) : null,
          borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(
              color: fillColor ??
                  (isEditMode
                      ? theme.colorScheme.surfaceContainerHighest
                      : theme.colorScheme.surfaceContainerHighest
                          .withValues(alpha: 0.6)),
              borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
              border: Border.all(
                color: state.hasError
                    ? theme.colorScheme.error
                    : (isEditMode ? theme.colorScheme.primary.withValues(alpha: 0.1) : Colors.transparent),
              ),
            ),
            child: Row(
              children: [
                if (selectedItem?.emoji != null) ...[
                  Text(selectedItem!.emoji!,
                      style: const TextStyle(fontSize: 20)),
                  const SizedBox(width: 12),
                ],
                Expanded(
                  child: Text(
                    selectedItem?.label ?? (hint ?? 'Select'),
                    style: theme.textTheme.bodyLarge?.copyWith(
                      color: selectedItem != null
                          ? null
                          : theme.colorScheme.onSurfaceVariant,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (isEditMode)
                  Icon(
                    Icons.keyboard_arrow_down_rounded,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
              ],
            ),
          ),
        ),
        if (state.hasError)
          Padding(
            padding: const EdgeInsets.only(top: 8.0, left: 16.0),
            child: Text(
              state.errorText!,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.error,
              ),
            ),
          ),
      ],
    );
      },
    );
  }
}

/// Full-page bottom sheet for dropdown selection.
class _DropdownSelectionSheet<T> extends StatefulWidget {
  final String title;
  final List<CustomDropdownItem<T>> items;
  final T? selectedValue;
  final bool isSearchable;

  const _DropdownSelectionSheet({
    required this.title,
    required this.items,
    this.selectedValue,
    this.isSearchable = false,
  });

  @override
  State<_DropdownSelectionSheet<T>> createState() =>
      _DropdownSelectionSheetState<T>();
}

class _DropdownSelectionSheetState<T>
    extends State<_DropdownSelectionSheet<T>> {
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

    final filtered = widget.items.where((item) {
      if (_query.isEmpty) return true;
      return item.label.toLowerCase().contains(_query.toLowerCase());
    }).toList();

    return Container(
      height: MediaQuery.of(context).size.height * 0.75,
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: const BorderRadius.vertical(
            top: Radius.circular(AppTheme.radiusXLarge)),
      ),
      child: Column(
        children: [
          // Drag handle
          const SizedBox(height: 12),
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: theme.colorScheme.onSurfaceVariant
                  .withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 16),

          // Title row
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    widget.title,
                    style: theme.textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close_rounded),
                  style: IconButton.styleFrom(
                    minimumSize: const Size(
                      AppTheme.minTouchTarget,
                      AppTheme.minTouchTarget,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),

          // Search field
          if (widget.isSearchable)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: TextField(
                controller: _searchCtrl,
                autofocus: true,
                onChanged: (val) => setState(() => _query = val),
                decoration: InputDecoration(
                  hintText: 'Search...',
                  prefixIcon:
                      const Icon(Icons.search_rounded, size: 20),
                  filled: true,
                  fillColor:
                      theme.colorScheme.surfaceContainerHighest,
                  border: OutlineInputBorder(
                    borderRadius:
                        BorderRadius.circular(AppTheme.radiusMedium),
                    borderSide: BorderSide.none,
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                      vertical: 0, horizontal: 12),
                ),
              ),
            ),

          if (widget.isSearchable) const SizedBox(height: 12),

          // Items list
          Expanded(
            child: filtered.isEmpty
                ? Center(
                    child: Text(
                      'No results found',
                      style: theme.textTheme.bodyLarge?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.only(bottom: 32),
                    itemCount: filtered.length,
                    itemBuilder: (context, index) {
                      final item = filtered[index];
                      final isSelected =
                          item.value == widget.selectedValue;

                      return ListTile(
                        contentPadding:
                            const EdgeInsets.symmetric(
                                horizontal: 24, vertical: 4),
                        leading: item.emoji != null
                            ? Text(item.emoji!,
                                style:
                                    const TextStyle(fontSize: 24))
                            : item.icon != null
                                ? CircleAvatar(
                                    radius: 18,
                                    backgroundColor: isSelected
                                        ? AppTheme.primary
                                            .withValues(alpha: 0.15)
                                        : AppTheme.primary
                                            .withValues(alpha: 0.08),
                                    child: Icon(
                                      item.icon,
                                      size: 18,
                                      color: isSelected
                                          ? AppTheme.primary
                                          : theme.colorScheme
                                              .onSurfaceVariant,
                                    ),
                                  )
                                : null,
                        title: Text(
                          item.label,
                          style:
                              theme.textTheme.bodyLarge?.copyWith(
                            fontWeight: isSelected
                                ? FontWeight.w600
                                : FontWeight.w400,
                            color: isSelected
                                ? AppTheme.primary
                                : null,
                          ),
                        ),
                        trailing: isSelected
                            ? Icon(Icons.check_rounded,
                                size: 20, color: AppTheme.primary)
                            : null,
                        selected: isSelected,
                        selectedTileColor:
                            AppTheme.primary.withValues(alpha: 0.06),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(
                              AppTheme.radiusMedium),
                        ),
                        onTap: () =>
                            Navigator.pop(context, item.value),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

/// Helper to build dropdown items from common types
class CustomDropdownBuilder {
  static List<CustomDropdownItem<String>> fromMap(
      Map<String, String> map,
      {IconData? icon}) {
    return map.entries
        .map((e) => CustomDropdownItem<String>(
              label: e.value,
              value: e.key,
              icon: icon,
            ))
        .toList();
  }

  static List<CustomDropdownItem<String>> fromList(List<String> list,
      {IconData? icon}) {
    return list
        .map((e) => CustomDropdownItem<String>(
              label: e,
              value: e,
              icon: icon,
            ))
        .toList();
  }
}
