import 'dart:math' as math;

import 'package:flutter/material.dart';

/// Charts are drawn with CustomPainter (no chart dependency). Every division
/// is guarded so empty or all-zero data never produces NaN geometry.

class DonutSegment {
  final String label;
  final int value;
  final Color color;

  const DonutSegment(this.label, this.value, this.color);
}

class DonutChart extends StatelessWidget {
  const DonutChart({
    super.key,
    required this.segments,
    required this.center,
    required this.semanticsLabel,
    this.size = 170,
  });

  final List<DonutSegment> segments;
  final Widget center;
  final String semanticsLabel;
  final double size;

  @override
  Widget build(BuildContext context) {
    final track = Theme.of(context).colorScheme.surfaceContainerHighest;
    return Semantics(
      label: semanticsLabel,
      child: SizedBox.square(
        dimension: size,
        child: TweenAnimationBuilder<double>(
          tween: Tween(begin: 0, end: 1),
          duration: const Duration(milliseconds: 650),
          curve: Curves.easeOutCubic,
          builder: (context, t, child) => CustomPaint(
            painter: _DonutPainter(segments, t, track),
            child: child,
          ),
          child: Center(child: ExcludeSemantics(child: center)),
        ),
      ),
    );
  }
}

class _DonutPainter extends CustomPainter {
  _DonutPainter(this.segments, this.progress, this.track);

  final List<DonutSegment> segments;
  final double progress;
  final Color track;

  @override
  void paint(Canvas canvas, Size size) {
    final stroke = size.shortestSide * 0.14;
    final rect = Rect.fromCircle(
      center: size.center(Offset.zero),
      radius: (size.shortestSide - stroke) / 2,
    );
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke;

    canvas.drawArc(rect, 0, 2 * math.pi, false, paint..color = track);

    final total = segments.fold<int>(0, (s, e) => s + math.max(0, e.value));
    if (total <= 0) return;

    const gap = 0.02;
    var start = -math.pi / 2;
    final available = 2 * math.pi * progress;
    final drawGaps = segments.where((s) => s.value > 0).length > 1;
    for (final s in segments) {
      if (s.value <= 0) continue;
      final sweep = available * s.value / total;
      final visible = drawGaps ? math.max(0.0, sweep - gap) : sweep;
      canvas.drawArc(rect, start, visible, false, paint..color = s.color);
      start += sweep;
    }
  }

  @override
  bool shouldRepaint(_DonutPainter old) =>
      old.progress != progress ||
      old.segments != segments ||
      old.track != track;
}

class BarGroup {
  final String label;
  final List<int> values;

  const BarGroup(this.label, this.values);
}

/// Vertical grouped bar chart with an animated grow-in.
class BarChart extends StatelessWidget {
  const BarChart({
    super.key,
    required this.groups,
    required this.colors,
    required this.formatValue,
    required this.semanticsLabel,
    this.height = 200,
    this.highlightIndex,
  });

  final List<BarGroup> groups;
  final List<Color> colors;
  final String Function(int) formatValue;
  final String semanticsLabel;
  final double height;
  final int? highlightIndex;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    var maxValue = 0;
    for (final g in groups) {
      for (final v in g.values) {
        if (v > maxValue) maxValue = v;
      }
    }
    final labelStyle = theme.textTheme.labelSmall!.copyWith(
      color: theme.colorScheme.onSurfaceVariant,
    );
    // Show every label if there is room, otherwise every n-th.
    final labelEvery = groups.length <= 12 ? 1 : (groups.length / 8).ceil();

    return Semantics(
      label: semanticsLabel,
      child: ExcludeSemantics(
        child: SizedBox(
          height: height,
          child: Column(
            children: [
              Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  maxValue == 0 ? '' : 'Max ${formatValue(maxValue)}',
                  style: labelStyle,
                ),
              ),
              const SizedBox(height: 6),
              Expanded(
                child: TweenAnimationBuilder<double>(
                  tween: Tween(begin: 0, end: 1),
                  duration: const Duration(milliseconds: 600),
                  curve: Curves.easeOutCubic,
                  builder: (context, t, _) => CustomPaint(
                    size: Size.infinite,
                    painter: _BarPainter(
                      groups: groups,
                      colors: colors,
                      maxValue: maxValue,
                      progress: t,
                      grid: theme.colorScheme.outlineVariant,
                      highlightIndex: highlightIndex,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 6),
              Row(
                children: [
                  for (var i = 0; i < groups.length; i++)
                    Expanded(
                      child: Text(
                        i % labelEvery == 0 ? groups[i].label : '',
                        textAlign: TextAlign.center,
                        maxLines: 1,
                        overflow: TextOverflow.clip,
                        style: labelStyle.copyWith(
                          fontWeight: i == highlightIndex
                              ? FontWeight.w800
                              : null,
                          color: i == highlightIndex
                              ? theme.colorScheme.onSurface
                              : null,
                        ),
                      ),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _BarPainter extends CustomPainter {
  _BarPainter({
    required this.groups,
    required this.colors,
    required this.maxValue,
    required this.progress,
    required this.grid,
    required this.highlightIndex,
  });

  final List<BarGroup> groups;
  final List<Color> colors;
  final int maxValue;
  final double progress;
  final Color grid;
  final int? highlightIndex;

  @override
  void paint(Canvas canvas, Size size) {
    final gridPaint = Paint()
      ..color = grid.withValues(alpha: 0.5)
      ..strokeWidth = 1;
    for (var i = 0; i <= 3; i++) {
      final y = size.height * i / 3;
      canvas.drawLine(Offset(0, y), Offset(size.width, y), gridPaint);
    }
    if (groups.isEmpty || maxValue <= 0 || size.width <= 0) return;

    final slot = size.width / groups.length;
    final series = groups.first.values.length;
    final groupWidth = slot * 0.7;
    final barWidth = math.max(1.0, groupWidth / series - (series > 1 ? 2 : 0));
    final paint = Paint();

    for (var g = 0; g < groups.length; g++) {
      final dim = highlightIndex != null && g != highlightIndex;
      final left = slot * g + (slot - groupWidth) / 2;
      for (var s = 0; s < series; s++) {
        final v = groups[g].values[s];
        if (v <= 0) continue;
        final h = size.height * (v / maxValue) * progress;
        final x = left + s * (groupWidth / series);
        paint.color = colors[s % colors.length].withValues(
          alpha: dim ? 0.45 : 1,
        );
        canvas.drawRRect(
          RRect.fromRectAndCorners(
            Rect.fromLTWH(x, size.height - h, barWidth, h),
            topLeft: Radius.circular(math.min(4, barWidth / 2)),
            topRight: Radius.circular(math.min(4, barWidth / 2)),
          ),
          paint,
        );
      }
    }
  }

  @override
  bool shouldRepaint(_BarPainter old) =>
      old.progress != progress ||
      old.groups != groups ||
      old.maxValue != maxValue ||
      old.highlightIndex != highlightIndex ||
      old.grid != grid;
}

/// Thin animated progress bar used for budgets and category shares.
class ProgressBar extends StatelessWidget {
  const ProgressBar({
    super.key,
    required this.value,
    required this.color,
    this.height = 8,
  });

  /// 0..1 (values outside are clamped).
  final double value;
  final Color color;
  final double height;

  @override
  Widget build(BuildContext context) {
    final v = value.isFinite ? value.clamp(0.0, 1.0) : 0.0;
    return ClipRRect(
      borderRadius: BorderRadius.circular(height),
      child: SizedBox(
        height: height,
        child: TweenAnimationBuilder<double>(
          tween: Tween(begin: 0, end: v),
          duration: const Duration(milliseconds: 500),
          curve: Curves.easeOutCubic,
          builder: (context, t, _) => LinearProgressIndicator(
            value: t,
            minHeight: height,
            color: color,
            backgroundColor: Theme.of(
              context,
            ).colorScheme.surfaceContainerHighest,
          ),
        ),
      ),
    );
  }
}
