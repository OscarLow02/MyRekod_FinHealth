import 'dart:math';
import 'package:flutter/material.dart';
import '../core/app_theme.dart';

/// A visually striking 240° arc gauge that displays the user's
/// Credit Readiness Score (0–1000) using [CustomPainter].
///
/// Color-coded thresholds:
/// - Red   : 0–499   (Needs Improvement)
/// - Amber : 500–749 (Good Progress)
/// - Green : 750–1000 (Excellent)
class CreditScoreGauge extends StatelessWidget {
  final int score;
  final int maxScore;

  const CreditScoreGauge({
    super.key,
    required this.score,
    this.maxScore = 1000,
  });

  // ── Threshold-based colour ────────────────────────────────────────────────
  Color get _gaugeColor {
    if (score < 500) return Colors.redAccent;
    if (score < 750) return AppTheme.amber;
    return AppTheme.neonGreenDark;
  }

  // ── Health label ──────────────────────────────────────────────────────────
  String get _healthLabel {
    if (score < 300) return 'Getting Started';
    if (score < 500) return 'Building Foundation';
    if (score < 750) return 'Good Progress';
    if (score < 900) return 'Strong Health';
    return 'Excellent!';
  }

  IconData get _healthIcon {
    if (score < 500) return Icons.trending_up_rounded;
    if (score < 750) return Icons.show_chart_rounded;
    return Icons.rocket_launch_rounded;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(24, 28, 24, 20),
      decoration: BoxDecoration(
        color: theme.cardTheme.color,
        borderRadius: BorderRadius.circular(AppTheme.radiusLarge),
        border: Border.all(
          color: _gaugeColor.withValues(alpha: 0.15),
          width: 1,
        ),
      ),
      child: Column(
        children: [
          // ── Section Title ─────────────────────────────────────────────
          Text(
            'Financial Health Score',
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w700,
              letterSpacing: -0.3,
            ),
          ),
          const SizedBox(height: 24),

          // ── The Gauge ─────────────────────────────────────────────────
          SizedBox(
            width: 220,
            height: 140,
            child: CustomPaint(
              painter: _GaugeArcPainter(
                score: score.toDouble(),
                maxScore: maxScore.toDouble(),
                gaugeColor: _gaugeColor,
                trackColor: theme.colorScheme.surfaceContainerHighest,
              ),
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.only(top: 32),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Large score number
                      Text(
                        '$score',
                        style: theme.textTheme.displayMedium?.copyWith(
                          fontWeight: FontWeight.w800,
                          color: _gaugeColor,
                          fontSize: 44,
                          height: 1.0,
                        ),
                      ),
                      Text(
                        '/ $maxScore',
                        style: theme.textTheme.labelMedium?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 20),

          // ── Health Badge ───────────────────────────────────────────────
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: BoxDecoration(
              color: _gaugeColor.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(AppTheme.radiusXLarge),
            ),
            child: Wrap(
              spacing: 8,
              runSpacing: 4,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                Icon(_healthIcon, size: 18, color: _gaugeColor),
                Text(
                  _healthLabel,
                  style: theme.textTheme.labelLarge?.copyWith(
                    color: _gaugeColor,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ──────────────────────────────────────────────────────────────────────────────
// Custom Painter — 240° Arc Gauge (Speedometer Style)
// ──────────────────────────────────────────────────────────────────────────────

class _GaugeArcPainter extends CustomPainter {
  final double score;
  final double maxScore;
  final Color gaugeColor;
  final Color trackColor;

  _GaugeArcPainter({
    required this.score,
    required this.maxScore,
    required this.gaugeColor,
    required this.trackColor,
  });

  // 240° arc: starts at 150° (5π/6), sweeps 240° (4π/3)
  static const double _startAngle = 5 * pi / 6;
  static const double _totalSweep = 4 * pi / 3;
  static const double _strokeWidth = 14.0;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height * 0.82);
    final radius = (size.width / 2) - _strokeWidth;
    final rect = Rect.fromCircle(center: center, radius: radius);

    // ── Background track ────────────────────────────────────────────────
    final trackPaint = Paint()
      ..color = trackColor.withValues(alpha: 0.4)
      ..style = PaintingStyle.stroke
      ..strokeWidth = _strokeWidth
      ..strokeCap = StrokeCap.round;

    canvas.drawArc(rect, _startAngle, _totalSweep, false, trackPaint);

    // ── Score arc with glow ─────────────────────────────────────────────
    final progress = (score / maxScore).clamp(0.0, 1.0);
    if (progress > 0) {
      final scoreSweep = _totalSweep * progress;

      // Glow layer
      final glowPaint = Paint()
        ..color = gaugeColor.withValues(alpha: 0.25)
        ..style = PaintingStyle.stroke
        ..strokeWidth = _strokeWidth + 8
        ..strokeCap = StrokeCap.round
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8);

      canvas.drawArc(rect, _startAngle, scoreSweep, false, glowPaint);

      // Main arc
      final scorePaint = Paint()
        ..color = gaugeColor
        ..style = PaintingStyle.stroke
        ..strokeWidth = _strokeWidth
        ..strokeCap = StrokeCap.round;

      canvas.drawArc(rect, _startAngle, scoreSweep, false, scorePaint);
    }
  }

  @override
  bool shouldRepaint(covariant _GaugeArcPainter oldDelegate) {
    return oldDelegate.score != score ||
        oldDelegate.maxScore != maxScore ||
        oldDelegate.gaugeColor != gaugeColor;
  }
}
