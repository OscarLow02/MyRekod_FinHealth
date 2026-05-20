import 'dart:ui';
import 'package:flutter/material.dart';
import '../core/app_theme.dart';

// ─────────────────────────────────────────────────────────────────────────────
// GLASS WIDGETS — Luminescent Vault Glassmorphism Components
// ─────────────────────────────────────────────────────────────────────────────
// Reusable frosted-glass (glassmorphism) primitives for the MyRekod_FinHealth
// design system. Every widget follows these Global Glassmorphism Rules:
//
//   1. Blur:   BackdropFilter with ImageFilter.blur(sigmaX: 12, sigmaY: 12)
//   2. Clip:   ClipRRect wrapping the blur, matching the container radius
//   3. Tint:   Semi-transparent surface fill + subtle white border (frost edge)
//
// High-contrast theme is automatically detected and respected.
// ─────────────────────────────────────────────────────────────────────────────

/// Detects high-contrast accessibility theme by checking the primary color.
bool _isHighContrastTheme(ThemeData theme) {
  return theme.colorScheme.primary.toARGB32() == 0xFFFFFF00;
}

// ═════════════════════════════════════════════════════════════════════════════
// 1. GlassContainer — The Base Wrapper
// ═════════════════════════════════════════════════════════════════════════════

/// A reusable glassmorphism container that applies backdrop blur, a
/// semi-transparent tint, and a frost border around any [child] widget.
///
/// Use this for cards, dialogs, floating panels, or any surface that should
/// appear as frosted glass.
///
/// ```dart
/// GlassContainer(
///   borderRadius: 20,
///   padding: EdgeInsets.all(16),
///   child: Text('Hello Glass'),
/// )
/// ```
class GlassContainer extends StatelessWidget {
  /// The widget rendered inside the glass surface.
  final Widget child;

  /// Optional fixed width. Defaults to unconstrained (parent-driven).
  final double? width;

  /// Optional fixed height. Defaults to unconstrained (child-driven).
  final double? height;

  /// Corner radius of the glass container. Defaults to [AppTheme.radiusLarge].
  final double borderRadius;

  /// Internal padding. Defaults to `EdgeInsets.zero`.
  final EdgeInsetsGeometry padding;

  /// Blur intensity. Defaults to 12.0 per the Global Glassmorphism Rules.
  final double blurSigma;

  /// Background tint opacity. Defaults to 0.4 for the standard glass look.
  /// Use higher values (0.6–0.8) for "heavier" glass panels.
  final double tintOpacity;

  /// Optional override for the tint color. When null, uses
  /// `Theme.colorScheme.surfaceContainer`.
  final Color? tintColor;

  /// Frost border opacity. Defaults to 0.1.
  final double borderOpacity;

  /// Optional margin around the container.
  final EdgeInsetsGeometry? margin;

  const GlassContainer({
    super.key,
    required this.child,
    this.width,
    this.height,
    this.borderRadius = AppTheme.radiusLarge,
    this.padding = EdgeInsets.zero,
    this.blurSigma = 20.0,
    this.tintOpacity = 0.08,
    this.tintColor,
    this.borderOpacity = 0.15,
    this.margin,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isHC = _isHighContrastTheme(theme);

    // High-contrast: use near-opaque surface for legibility.
    final effectiveTintOpacity = isHC ? 0.92 : tintOpacity;
    final effectiveBorderOpacity = isHC ? 0.4 : borderOpacity;
    final effectiveTintColor =
        tintColor ?? (isHC ? theme.colorScheme.surfaceContainer : Colors.white);
    final effectiveBorderColor = isHC
        ? theme.colorScheme.primary.withValues(alpha: effectiveBorderOpacity)
        : Colors.white.withValues(alpha: effectiveBorderOpacity);

    return Container(
      margin: margin,
      width: width,
      height: height,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(borderRadius),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: blurSigma, sigmaY: blurSigma),
          child: Container(
            padding: padding,
            decoration: BoxDecoration(
              color: effectiveTintColor.withValues(alpha: effectiveTintOpacity),
              borderRadius: BorderRadius.circular(borderRadius),
              border: Border.all(
                color: effectiveBorderColor,
                width: isHC ? 1.5 : 1.0,
              ),
            ),
            child: child,
          ),
        ),
      ),
    );
  }
}

// ═════════════════════════════════════════════════════════════════════════════
// 2. GlassSearchBar — Frosted Search TextField
// ═════════════════════════════════════════════════════════════════════════════

/// A search [TextField] built on frosted glass, with a search prefix icon
/// and an animated clear suffix button.
///
/// Text is always ≥ 16sp for Radical Accessibility compliance.
///
/// ```dart
/// GlassSearchBar(
///   controller: _searchCtrl,
///   hintText: 'Search vendor or category',
///   onChanged: (val) => provider.setSearchQuery(val),
///   onClear: () { _searchCtrl.clear(); provider.setSearchQuery(''); },
/// )
/// ```
class GlassSearchBar extends StatelessWidget {
  /// The text editing controller for the search field.
  final TextEditingController controller;

  /// Placeholder text shown when the field is empty.
  final String hintText;

  /// Called on every keystroke with the current text value.
  final ValueChanged<String>? onChanged;

  /// Called when the user taps the clear button. If null, no clear button is
  /// shown even when the field contains text.
  final VoidCallback? onClear;

  /// Called when the user submits (keyboard "search" action).
  final ValueChanged<String>? onSubmitted;

  /// Whether the field is enabled. Defaults to true.
  final bool enabled;

  /// Blur intensity override.
  final double blurSigma;

  /// Corner radius. Defaults to [AppTheme.radiusLarge].
  final double borderRadius;

  const GlassSearchBar({
    super.key,
    required this.controller,
    this.hintText = 'Search…',
    this.onChanged,
    this.onClear,
    this.onSubmitted,
    this.enabled = true,
    this.blurSigma = 12.0,
    this.borderRadius = AppTheme.radiusLarge,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isHC = _isHighContrastTheme(theme);

    final tintOpacity = isHC ? 0.92 : 0.08;
    final borderColor = isHC
        ? theme.colorScheme.primary.withValues(alpha: 0.4)
        : Colors.white.withValues(alpha: 0.15);

    final textColor = theme.colorScheme.onSurface;
    final hintColor = theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.6);
    final iconColor = theme.colorScheme.onSurfaceVariant;

    return ClipRRect(
      borderRadius: BorderRadius.circular(borderRadius),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: blurSigma, sigmaY: blurSigma),
        child: Container(
          height: AppTheme.minTouchTarget,
          decoration: BoxDecoration(
            color: (isHC ? theme.colorScheme.surfaceContainer : Colors.white)
                .withValues(alpha: tintOpacity),
            borderRadius: BorderRadius.circular(borderRadius),
            border: Border.all(color: borderColor, width: isHC ? 1.5 : 1.0),
          ),
          child: TextField(
            controller: controller,
            onChanged: onChanged,
            onSubmitted: onSubmitted,
            enabled: enabled,
            textInputAction: TextInputAction.search,
            style: theme.textTheme.bodyLarge?.copyWith(
              color: textColor,
              fontWeight: FontWeight.w500,
            ),
            decoration: InputDecoration(
              hintText: hintText,
              hintStyle: theme.textTheme.bodyLarge?.copyWith(
                color: hintColor,
                fontWeight: FontWeight.w400,
              ),
              prefixIcon: Icon(Icons.search_rounded, color: iconColor, size: 22),
              suffixIcon: controller.text.isNotEmpty && onClear != null
                  ? IconButton(
                      icon: Icon(Icons.clear_rounded, color: iconColor, size: 20),
                      onPressed: onClear,
                      tooltip: 'Clear search',
                    )
                  : null,
              filled: false,
              border: InputBorder.none,
              enabledBorder: InputBorder.none,
              focusedBorder: InputBorder.none,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 14,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ═════════════════════════════════════════════════════════════════════════════
// 3. GlassSegmentedTabs — Frosted Toggle / Tab Switch
// ═════════════════════════════════════════════════════════════════════════════

/// A segmented tab control rendered on a frosted glass track.
///
/// The outer track is a heavy glass container (higher blur, darker tint).
/// The active indicator slides with an [AnimatedAlign] for smooth transitions
/// and uses the primary color with a soft shadow.
///
/// Maintains a minimum 48dp height for Fitts's Law compliance.
///
/// ```dart
/// GlassSegmentedTabs(
///   labels: ['Sales', 'Expenses'],
///   selectedIndex: _currentTab,
///   onChanged: (index) => setState(() => _currentTab = index),
/// )
/// ```
class GlassSegmentedTabs extends StatelessWidget {
  /// The text labels for each tab segment.
  final List<String> labels;

  /// The currently selected tab index.
  final int selectedIndex;

  /// Called when the user taps a different tab.
  final ValueChanged<int> onChanged;

  /// Optional icons displayed before each label.
  final List<IconData>? icons;

  /// Corner radius of the outer track. Defaults to [AppTheme.radiusMedium].
  final double borderRadius;

  /// Blur intensity for the outer track. Higher = heavier glass.
  final double blurSigma;

  /// Overall height. Defaults to [AppTheme.minTouchTarget] (56dp).
  final double height;

  /// Internal padding between the track edge and the indicator.
  final double trackPadding;

  const GlassSegmentedTabs({
    super.key,
    required this.labels,
    required this.selectedIndex,
    required this.onChanged,
    this.icons,
    this.borderRadius = 28.0,
    this.blurSigma = 16.0,
    this.height = AppTheme.minTouchTarget,
    this.trackPadding = 4.0,
  }) : assert(labels.length >= 2, 'At least 2 tabs are required');

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isHC = _isHighContrastTheme(theme);
    final tabCount = labels.length;

    // ── Outer track decoration ─────────────────────────────────────────────
    final trackTintOpacity = isHC ? 0.92 : 0.10;
    final trackBorderColor = isHC
        ? theme.colorScheme.primary.withValues(alpha: 0.4)
        : Colors.white.withValues(alpha: 0.15);

    // ── Indicator colors ───────────────────────────────────────────────────
    final indicatorColor = isHC
        ? theme.colorScheme.primary
        : theme.colorScheme.primary.withValues(alpha: 0.85);
    final indicatorShadowColor = theme.colorScheme.primary.withValues(alpha: 0.25);

    // ── Text colors ────────────────────────────────────────────────────────
    final activeTextColor = isHC
        ? theme.colorScheme.onPrimary
        : Colors.white;
    final inactiveTextColor = theme.colorScheme.onSurfaceVariant;

    return ClipRRect(
      borderRadius: BorderRadius.circular(borderRadius),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: blurSigma, sigmaY: blurSigma),
        child: Container(
          height: height,
          decoration: BoxDecoration(
            color: (isHC ? theme.colorScheme.surfaceContainer : Colors.white)
                .withValues(alpha: trackTintOpacity),
            borderRadius: BorderRadius.circular(borderRadius),
            border: Border.all(
              color: trackBorderColor,
              width: isHC ? 1.5 : 1.0,
            ),
          ),
          child: Padding(
            padding: EdgeInsets.all(trackPadding),
            child: LayoutBuilder(
              builder: (context, constraints) {
                final indicatorWidth =
                    (constraints.maxWidth - trackPadding) / tabCount;
                final indicatorHeight = constraints.maxHeight;
                final innerRadius = borderRadius - trackPadding;

                return Stack(
                  children: [
                    // ── Sliding active indicator ─────────────────────────
                    AnimatedPositioned(
                      duration: const Duration(milliseconds: 250),
                      curve: Curves.easeOutCubic,
                      left: selectedIndex * indicatorWidth,
                      top: 0,
                      width: indicatorWidth,
                      height: indicatorHeight,
                      child: Container(
                        decoration: BoxDecoration(
                          color: indicatorColor,
                          borderRadius: BorderRadius.circular(innerRadius),
                          boxShadow: [
                            BoxShadow(
                              color: indicatorShadowColor,
                              blurRadius: 12,
                              offset: const Offset(0, 2),
                              spreadRadius: 0,
                            ),
                          ],
                        ),
                      ),
                    ),

                    // ── Tab labels row ───────────────────────────────────
                    Row(
                      children: List.generate(tabCount, (index) {
                        final isActive = index == selectedIndex;
                        return Expanded(
                          child: GestureDetector(
                            onTap: () {
                              if (index != selectedIndex) onChanged(index);
                            },
                            behavior: HitTestBehavior.opaque,
                            child: SizedBox(
                              height: indicatorHeight,
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  if (icons != null &&
                                      index < icons!.length) ...[
                                    AnimatedDefaultTextStyle(
                                      duration: const Duration(milliseconds: 200),
                                      style: TextStyle(
                                        color: isActive
                                            ? activeTextColor
                                            : inactiveTextColor,
                                      ),
                                      child: Icon(
                                        icons![index],
                                        size: 18,
                                        color: isActive
                                            ? activeTextColor
                                            : inactiveTextColor,
                                      ),
                                    ),
                                    const SizedBox(width: 6),
                                  ],
                                  AnimatedDefaultTextStyle(
                                    duration: const Duration(milliseconds: 200),
                                    style: theme.textTheme.labelLarge!.copyWith(
                                      color: isActive
                                          ? activeTextColor
                                          : inactiveTextColor,
                                      fontWeight: isActive
                                          ? FontWeight.w700
                                          : FontWeight.w500,
                                    ),
                                    child: Text(labels[index]),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        );
                      }),
                    ),
                  ],
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}
