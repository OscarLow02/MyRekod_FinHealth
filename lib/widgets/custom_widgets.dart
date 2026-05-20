import 'package:flutter/material.dart';
import '../core/app_theme.dart';

/// Centralized custom widgets to ensure UI consistency across MyRekod.
/// Implements the "Luminescent Vault" aesthetic with explicit borders as requested.

class AppButton extends StatelessWidget {
  final String text;
  final VoidCallback? onPressed;
  final bool isPrimary;
  final bool isLoading;
  final Widget? icon;

  const AppButton({
    super.key,
    required this.text,
    this.onPressed,
    this.isPrimary = true,
    this.isLoading = false,
    this.icon,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final borderColor = AppTheme.secondaryDark; // #B6A4F3

    if (isPrimary) {
      return SizedBox(
        width: double.infinity,
        height: AppTheme.minTouchTarget + 8,
        child: ElevatedButton(
          onPressed: isLoading ? null : onPressed,
          style: ElevatedButton.styleFrom(
            side: BorderSide(color: borderColor, width: 1),
          ),
          child: isLoading
              ? const SizedBox(
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(
                    color: Colors.white,
                    strokeWidth: 2.5,
                  ),
                )
              : Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    if (icon != null) ...[icon!, const SizedBox(width: 8)],
                    Flexible(child: Text(text, overflow: TextOverflow.ellipsis)),
                  ],
                ),
        ),
      );
    } else {
      return SizedBox(
        width: double.infinity,
        height: AppTheme.minTouchTarget + 8,
        child: OutlinedButton(
          onPressed: isLoading ? null : onPressed,
          style: OutlinedButton.styleFrom(
            side: BorderSide(color: borderColor, width: 1.5),
            foregroundColor: theme.colorScheme.onSurface,
          ),
          child: isLoading
              ? const SizedBox(
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(
                    strokeWidth: 2.5,
                  ),
                )
              : Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    if (icon != null) ...[icon!, const SizedBox(width: 8)],
                    Flexible(child: Text(text, overflow: TextOverflow.ellipsis)),
                  ],
                ),
        ),
      );
    }
  }
}

class AppTextField extends StatelessWidget {
  final TextEditingController? controller;
  final String? hintText;
  final String? labelText;
  final bool obscureText;
  final TextInputType? keyboardType;
  final String? Function(String?)? validator;
  final Widget? suffixIcon;
  final Widget? prefixIcon;
  final int? maxLines;
  final String? label;
  final IconData? icon;
  final bool enabled;
  final TextCapitalization textCapitalization;
  final void Function(String)? onChanged;
  final FocusNode? focusNode;

  final bool isRequired;

  const AppTextField({
    super.key,
    this.controller,
    this.hintText,
    this.labelText,
    this.isRequired = false,
    this.obscureText = false,
    this.keyboardType,
    this.validator,
    this.suffixIcon,
    this.prefixIcon,
    this.enabled = true,
    this.textCapitalization = TextCapitalization.none,
    this.onChanged,
    this.focusNode,
    this.maxLines = 1,
    this.label,
    this.icon,
    this.textInputAction = TextInputAction.done,
  });

  final TextInputAction textInputAction;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (label != null) ...[
          Row(
            children: [
              if (icon != null) ...[
                Icon(icon, size: 16, color: theme.colorScheme.onSurfaceVariant),
                const SizedBox(width: 8),
              ],
              Flexible(
                child: Text(
                  label!,
                  style: theme.textTheme.labelMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (isRequired) ...[
                const SizedBox(width: 6),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                  decoration: BoxDecoration(
                    color: Colors.redAccent.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(4),
                    border: Border.all(color: Colors.redAccent, width: 1),
                  ),
                  child: Text(
                    'REQUIRED',
                    style: theme.textTheme.labelSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: Colors.redAccent,
                      fontSize: 8,
                    ),
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 8),
        ],
        TextFormField(
          controller: controller,
          focusNode: focusNode,
          obscureText: obscureText,
          keyboardType: keyboardType,
          validator: validator,
          enabled: enabled,
          textCapitalization: textCapitalization,
          textInputAction: textInputAction,
          onChanged: onChanged,
          maxLines: maxLines,
          style: theme.textTheme.bodyLarge?.copyWith(
            fontWeight: FontWeight.w600,
          ),
          decoration: InputDecoration(
            hintText: hintText,
            suffixIcon: suffixIcon,
            prefixIcon: prefixIcon,
            filled: true,
            fillColor:
                theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
            // Borders now inherited from Theme.inputDecorationTheme
          ),
        ),
      ],
    );
  }
}

class AppDropdown<T> extends StatelessWidget {
  final T? value;
  final String? hintText;
  final List<DropdownMenuItem<T>> items;
  final void Function(T?)? onChanged;
  final String? Function(T?)? validator;

  const AppDropdown({
    super.key,
    required this.items,
    this.value,
    this.hintText,
    this.onChanged,
    this.validator,
  });

  @override
  Widget build(BuildContext context) {


    return DropdownButtonFormField<T>(
      initialValue: value,
      items: items,
      onChanged: onChanged,
      validator: validator,
      decoration: InputDecoration(
        hintText: hintText,
        // Borders now inherited from Theme.inputDecorationTheme
      ),
    );
  }
}

Widget buildEmptyState(
  BuildContext context, {
  required IconData icon,
  required String message,
  required Color color,
  VoidCallback? onAction,
  String? actionLabel,
}) {
  final theme = Theme.of(context);

  return Center(
    child: Padding(
      padding: const EdgeInsets.all(48.0),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Stacked background container for a premium illustration feel
          Container(
            width: 140,
            height: 140,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.05),
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Container(
                width: 100,
                height: 100,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: color.withValues(alpha: 0.3),
                      blurRadius: 24,
                      spreadRadius: 4,
                    ),
                  ],
                ),
                child: Icon(
                  icon,
                  size: 80,
                  color: color.withValues(alpha: 0.8),
                ),
              ),
            ),
          ),
          const SizedBox(height: 32),
          Text(
            message,
            style: theme.textTheme.titleMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
              fontWeight: FontWeight.w600,
            ),
            textAlign: TextAlign.center,
          ),
          if (onAction != null && actionLabel != null) ...[
            const SizedBox(height: 32),
            AppButton(
              text: actionLabel,
              onPressed: onAction,
              isPrimary: true,
            ),
          ],
        ],
      ),
    ),
  );
}
