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
/// Supports search functionality, icons, and premium styling.
class CustomPremiumDropdown<T> extends StatefulWidget {
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
  });

  @override
  State<CustomPremiumDropdown<T>> createState() => _CustomPremiumDropdownState<T>();
}

class _CustomPremiumDropdownState<T> extends State<CustomPremiumDropdown<T>> {
  final MenuController _menuController = MenuController();
  final FocusNode _buttonFocusNode = FocusNode();
  String _searchQuery = '';

  @override
  void dispose() {
    _buttonFocusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final selectedItem = widget.items.any((i) => i.value == widget.value)
        ? widget.items.firstWhere((i) => i.value == widget.value)
        : null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Label with Icon (if selected item has one)
        Row(
          children: [
            if (selectedItem?.icon != null) ...[
              Icon(selectedItem!.icon, size: 16, color: AppTheme.primary),
              const SizedBox(width: 8),
            ],
            Text(
              widget.label,
              style: theme.textTheme.labelMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        
        MenuAnchor(
          controller: _menuController,
          childFocusNode: _buttonFocusNode,
          style: MenuStyle(
            backgroundColor: WidgetStateProperty.all(theme.colorScheme.surface),
            elevation: WidgetStateProperty.all(12),
            padding: WidgetStateProperty.all(EdgeInsets.zero),
            shape: WidgetStateProperty.all(
              RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppTheme.radiusLarge),
              ),
            ),
            maximumSize: WidgetStateProperty.all(const Size.fromHeight(400)),
          ),
          builder: (context, controller, child) {
            return InkWell(
              onTap: widget.isEditMode 
                ? () {
                    if (controller.isOpen) {
                      controller.close();
                    } else {
                      _searchQuery = ''; // Reset search when opening
                      controller.open();
                    }
                  } 
                : null,
              borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                decoration: BoxDecoration(
                  color: widget.fillColor ?? (widget.isEditMode
                      ? theme.colorScheme.surfaceContainerHighest
                      : theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.6)),
                  borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
                  border: widget.isEditMode 
                    ? Border.all(color: theme.colorScheme.primary.withValues(alpha: 0.1))
                    : null,
                ),
                child: Row(
                  children: [
                    if (selectedItem?.emoji != null) ...[
                      Text(selectedItem!.emoji!, style: const TextStyle(fontSize: 20)),
                      const SizedBox(width: 12),
                    ],
                    Expanded(
                      child: Text(
                        selectedItem?.label ?? (widget.hint ?? 'Select'),
                        style: theme.textTheme.bodyLarge?.copyWith(
                          color: selectedItem != null ? null : theme.colorScheme.onSurfaceVariant,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (widget.isEditMode)
                      Icon(
                        Icons.keyboard_arrow_down_rounded,
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                  ],
                ),
              ),
            );
          },
          menuChildren: [
            if (widget.isSearchable)
              _DropdownSearchHeader(
                onChanged: (val) => setState(() => _searchQuery = val),
              ),
            ..._buildMenuItems(context),
          ],
        ),
      ],
    );
  }

  List<Widget> _buildMenuItems(BuildContext context) {
    final theme = Theme.of(context);
    
    final filteredItems = widget.items.where((item) {
      if (_searchQuery.isEmpty) return true;
      return item.label.toLowerCase().contains(_searchQuery.toLowerCase());
    }).toList();

    if (filteredItems.isEmpty) {
      return [
        const Padding(
          padding: EdgeInsets.symmetric(vertical: 24, horizontal: 16),
          child: Center(child: Text('No results found')),
        )
      ];
    }

    return filteredItems.map((item) {
      final isSelected = item.value == widget.value;
      return MenuItemButton(
        onPressed: () => widget.onChanged(item.value),
        style: MenuItemButton.styleFrom(
          backgroundColor: isSelected 
            ? theme.colorScheme.primary.withValues(alpha: 0.08)
            : null,
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        ),
        child: Row(
          children: [
            if (item.emoji != null) ...[
              Text(item.emoji!, style: const TextStyle(fontSize: 20)),
              const SizedBox(width: 12),
            ] else if (item.icon != null) ...[
              Icon(
                item.icon, 
                size: 20, 
                color: isSelected ? theme.colorScheme.primary : theme.colorScheme.onSurfaceVariant
              ),
              const SizedBox(width: 12),
            ],
            Expanded(
              child: Text(
                item.label,
                style: theme.textTheme.bodyLarge?.copyWith(
                  color: isSelected ? theme.colorScheme.primary : null,
                  fontWeight: isSelected ? FontWeight.w600 : null,
                ),
              ),
            ),
            if (isSelected)
              Icon(Icons.check_rounded, size: 18, color: theme.colorScheme.primary),
          ],
        ),
      );
    }).toList();
  }
}

class _DropdownSearchHeader extends StatefulWidget {
  final ValueChanged<String> onChanged;

  const _DropdownSearchHeader({required this.onChanged});

  @override
  State<_DropdownSearchHeader> createState() => _DropdownSearchHeaderState();
}

class _DropdownSearchHeaderState extends State<_DropdownSearchHeader> {
  final TextEditingController _ctrl = TextEditingController();

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.all(12),
      child: TextField(
        controller: _ctrl,
        onChanged: widget.onChanged,
        autofocus: true,
        decoration: InputDecoration(
          hintText: 'Search...',
          prefixIcon: const Icon(Icons.search_rounded, size: 20),
          isDense: true,
          contentPadding: const EdgeInsets.symmetric(vertical: 0, horizontal: 12),
          filled: true,
          fillColor: theme.colorScheme.surfaceContainerHighest,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
            borderSide: BorderSide.none,
          ),
        ),
      ),
    );
  }
}

/// Helper to build dropdown items from common types
class CustomDropdownBuilder {
  static List<CustomDropdownItem<String>> fromMap(Map<String, String> map, {IconData? icon}) {
    return map.entries.map((e) => CustomDropdownItem<String>(
      label: e.value,
      value: e.key,
      icon: icon,
    )).toList();
  }

  static List<CustomDropdownItem<String>> fromList(List<String> list, {IconData? icon}) {
    return list.map((e) => CustomDropdownItem<String>(
      label: e,
      value: e,
      icon: icon,
    )).toList();
  }
}
