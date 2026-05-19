import 'package:flutter/material.dart';

/// A curved background header that renders the top portion of the Dashboard.
///
/// Uses [ClipPath] with a [CustomClipper<Path>] to draw a smooth quadratic
/// bezier wave at the bottom edge, creating the overlapping visual effect
/// required by the Luminescent Vault design system.
class DashboardWaveHeader extends StatelessWidget {
  /// Total height of the wave header (including the curve).
  final double height;

  const DashboardWaveHeader({
    super.key,
    this.height = 220,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isHighContrast = theme.colorScheme.primary.toARGB32() == 0xFFFFFF00;

    return ClipPath(
      clipper: _WaveClipper(),
      child: Container(
        height: height,
        width: double.infinity,
        decoration: BoxDecoration(
          color: isHighContrast ? theme.colorScheme.surfaceContainer : theme.colorScheme.primary,
        ),
      ),
    );
  }
}

/// Custom clipper that draws a smooth wave at the bottom of the container.
///
/// The wave uses a single quadratic bezier curve from the bottom-left corner
/// to the bottom-right corner, with the control point at the center-bottom
/// creating a smooth concave dip.
class _WaveClipper extends CustomClipper<Path> {
  @override
  Path getClip(Size size) {
    final path = Path();

    // Start at top-left
    path.lineTo(0, 0);

    // Draw down the left edge to the wave start point
    path.lineTo(0, size.height - 50);

    // Smooth quadratic bezier wave across the bottom
    path.quadraticBezierTo(
      size.width / 2, // Control point X (center)
      size.height, // Control point Y (bottom — creates a downward curve)
      size.width, // End point X (right edge)
      size.height - 50, // End point Y (same height as start)
    );

    // Close the right edge back to the top-right
    path.lineTo(size.width, 0);
    path.close();

    return path;
  }

  @override
  bool shouldReclip(covariant CustomClipper<Path> oldClipper) => false;
}
