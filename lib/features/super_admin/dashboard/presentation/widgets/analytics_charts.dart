import 'package:flutter/material.dart';
import '../theme/dashboard_colors.dart';
import '../../domain/entities/dashboard_entities.dart';
import 'glow_card.dart';
import 'terminal_text.dart';

/// Section header + chart container.
class ChartCard extends StatelessWidget {
  final String title;
  final String? value;
  final String? subtitle;
  final Widget chart;
  final double height;

  const ChartCard({
    super.key,
    required this.title,
    required this.chart,
    this.value,
    this.subtitle,
    this.height = 200,
  });

  @override
  Widget build(BuildContext context) {
    return GlowCard(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    TerminalLabel(text: title),
                    if (value != null) ...[
                      const SizedBox(height: 6),
                      Text(
                        value!,
                        style: const TextStyle(
                          color: DashboardColors.textPrimary,
                          fontSize: 22,
                          fontWeight: FontWeight.w700,
                          fontFamily: DashboardColors.monoFont,
                          letterSpacing: -0.3,
                        ),
                      ),
                    ],
                    if (subtitle != null) ...[
                      const SizedBox(height: 2),
                      Text(
                        subtitle!,
                        style: const TextStyle(
                          color: DashboardColors.textMuted,
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                decoration: BoxDecoration(
                  border: Border.all(color: DashboardColors.border),
                  borderRadius: BorderRadius.circular(3),
                ),
                child: const Text(
                  '7D',
                  style: TextStyle(
                    color: DashboardColors.textSecondary,
                    fontSize: 9,
                    fontWeight: FontWeight.w700,
                    fontFamily: DashboardColors.monoFont,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          SizedBox(height: height, child: chart),
        ],
      ),
    );
  }
}

// =============================================================================
// Bar chart (Orders)
// =============================================================================
class OrdersBarChart extends StatelessWidget {
  final List<ChartPoint> data;
  const OrdersBarChart({super.key, required this.data});

  @override
  Widget build(BuildContext context) {
    final maxVal = data.map((e) => e.value).reduce((a, b) => a > b ? a : b);
    return Column(
      children: [
        Expanded(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: data.map((d) {
              final ratio = maxVal > 0 ? d.value / maxVal : 0.0;
              return Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: _AnimatedBar(ratio: ratio, value: d.value),
                ),
              );
            }).toList(),
          ),
        ),
        const SizedBox(height: 10),
        Row(
          children: data
              .map(
                (d) => Expanded(
                  child: Text(
                    d.label,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 10,
                      color: DashboardColors.textMuted,
                      fontFamily: DashboardColors.monoFont,
                    ),
                  ),
                ),
              )
              .toList(),
        ),
      ],
    );
  }
}

class _AnimatedBar extends StatefulWidget {
  final double ratio;
  final double value;
  const _AnimatedBar({required this.ratio, required this.value});

  @override
  State<_AnimatedBar> createState() => _AnimatedBarState();
}

class _AnimatedBarState extends State<_AnimatedBar>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c;
  @override
  void initState() {
    super.initState();
    _c = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    )..forward();
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        return AnimatedBuilder(
          animation: _c,
          builder: (_, _) {
            final h =
                constraints.maxHeight *
                widget.ratio *
                Curves.easeOutCubic.transform(_c.value);
            return Align(
              alignment: Alignment.bottomCenter,
              child: Tooltip(
                message: widget.value.toInt().toString(),
                child: Container(
                  width: double.infinity,
                  height: h,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        DashboardColors.accent,
                        DashboardColors.accent.withValues(alpha: 0.15),
                      ],
                    ),
                    borderRadius: const BorderRadius.vertical(
                      top: Radius.circular(2),
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: DashboardColors.accent.withValues(alpha: 0.25),
                        blurRadius: 8,
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }
}

// =============================================================================
// Line chart (Revenue) — used also for User Growth (area) with different color
// =============================================================================
class RevenueLineChart extends StatelessWidget {
  final List<ChartPoint> data;
  const RevenueLineChart({super.key, required this.data});

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _LineChartPainter(
        values: data.map((e) => e.value).toList(),
        labels: data.map((e) => e.label).toList(),
        lineColor: DashboardColors.chartSecondary,
      ),
      size: Size.infinite,
    );
  }
}

class UserGrowthAreaChart extends StatelessWidget {
  final List<ChartPoint> data;
  const UserGrowthAreaChart({super.key, required this.data});

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _LineChartPainter(
        values: data.map((e) => e.value).toList(),
        labels: data.map((e) => e.label).toList(),
        lineColor: DashboardColors.accent,
      ),
      size: Size.infinite,
    );
  }
}

class _LineChartPainter extends CustomPainter {
  final List<double> values;
  final List<String> labels;
  final Color lineColor;

  _LineChartPainter({
    required this.values,
    required this.labels,
    required this.lineColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (values.isEmpty) return;
    const labelArea = 22.0;
    final chartHeight = size.height - labelArea;
    final maxVal = values.reduce((a, b) => a > b ? a : b);
    final minVal = values.reduce((a, b) => a < b ? a : b);
    final range = (maxVal - minVal) == 0 ? 1.0 : (maxVal - minVal);

    final points = <Offset>[];
    for (int i = 0; i < values.length; i++) {
      final x = values.length == 1
          ? size.width / 2
          : (i / (values.length - 1)) * size.width;
      final normalized = (values[i] - minVal) / range;
      final y = chartHeight - (normalized * chartHeight) + 4;
      points.add(Offset(x, y));
    }

    // Grid lines
    final gridPaint = Paint()
      ..color = DashboardColors.borderSubtle
      ..strokeWidth = 1;
    for (int i = 0; i < 4; i++) {
      final y = (chartHeight / 4) * i + 4;
      canvas.drawLine(Offset(0, y), Offset(size.width, y), gridPaint);
    }

    // Filled area
    final fillPath = Path()..moveTo(0, chartHeight + 4);
    for (final p in points) {
      fillPath.lineTo(p.dx, p.dy);
    }
    fillPath.lineTo(size.width, chartHeight + 4);
    fillPath.close();
    canvas.drawPath(
      fillPath,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [lineColor.withValues(alpha: 0.25), lineColor.withValues(alpha: 0.0)],
        ).createShader(Rect.fromLTWH(0, 0, size.width, chartHeight)),
    );

    // Line
    final linePath = Path()..moveTo(points.first.dx, points.first.dy);
    for (int i = 1; i < points.length; i++) {
      linePath.lineTo(points[i].dx, points[i].dy);
    }
    canvas.drawPath(
      linePath,
      Paint()
        ..color = lineColor
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round,
    );

    // Highlight last point
    final last = points.last;
    canvas.drawCircle(last, 9, Paint()..color = lineColor.withValues(alpha: 0.2));
    canvas.drawCircle(last, 4, Paint()..color = lineColor);
    canvas.drawCircle(last, 2, Paint()..color = DashboardColors.background);

    // Labels
    final textStyle = TextStyle(
      color: DashboardColors.textMuted,
      fontSize: 9,
      fontFamily: DashboardColors.monoFont,
    );
    final step = (labels.length / 6).ceil().clamp(1, labels.length);
    for (int i = 0; i < labels.length; i++) {
      if (i % step != 0 && i != labels.length - 1) continue;
      final tp = TextPainter(
        text: TextSpan(text: labels[i], style: textStyle),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(canvas, Offset(points[i].dx - tp.width / 2, chartHeight + 8));
    }
  }

  @override
  bool shouldRepaint(covariant _LineChartPainter old) => false;
}

// =============================================================================
// Horizontal bar chart (Store performance)
// =============================================================================
class StorePerformanceChart extends StatelessWidget {
  final List<StorePerformance> data;
  const StorePerformanceChart({super.key, required this.data});

  @override
  Widget build(BuildContext context) {
    if (data.isEmpty) {
      return const SizedBox(
        width: double.infinity,
        height: double.infinity,
        child: Center(
          child: Text(
            'NO STORE DATA',
            style: TextStyle(
              color: DashboardColors.textMuted,
              fontSize: 11,
              fontFamily: DashboardColors.monoFont,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      );
    }

    final maxVal = data.map((e) => e.revenue).reduce((a, b) => a > b ? a : b);

    return Column(
      children: data.asMap().entries.map((entry) {
        final i = entry.key;
        final d = entry.value;
        final ratio = maxVal > 0 ? d.revenue / maxVal : 0.0;

        return Padding(
          padding: EdgeInsets.only(bottom: i == data.length - 1 ? 0 : 14),
          child: _StoreBar(
            name: d.name,
            value: d.revenue,
            ratio: ratio,
            rank: i + 1,
          ),
        );
      }).toList(),
    );
  }
}

class _StoreBar extends StatefulWidget {
  final String name;
  final double value;
  final double ratio;
  final int rank;
  const _StoreBar({
    required this.name,
    required this.value,
    required this.ratio,
    required this.rank,
  });

  @override
  State<_StoreBar> createState() => _StoreBarState();
}

class _StoreBarState extends State<_StoreBar>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c;
  @override
  void initState() {
    super.initState();
    _c = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..forward();
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              width: 18,
              height: 18,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: DashboardColors.surfaceElevated,
                border: Border.all(color: DashboardColors.border),
                borderRadius: BorderRadius.circular(2),
              ),
              child: Text(
                '${widget.rank}',
                style: const TextStyle(
                  color: DashboardColors.textSecondary,
                  fontSize: 9,
                  fontWeight: FontWeight.w700,
                  fontFamily: DashboardColors.monoFont,
                ),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                widget.name,
                style: const TextStyle(
                  color: DashboardColors.textPrimary,
                  fontSize: 12.5,
                  fontWeight: FontWeight.w500,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            Text(
              '\$${(widget.value / 1000).toStringAsFixed(1)}k',
              style: const TextStyle(
                color: DashboardColors.accent,
                fontSize: 12.5,
                fontWeight: FontWeight.w700,
                fontFamily: DashboardColors.monoFont,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        ClipRRect(
          borderRadius: BorderRadius.circular(2),
          child: Stack(
            children: [
              Container(height: 6, color: DashboardColors.surfaceElevated),
              AnimatedBuilder(
                animation: _c,
                builder: (_, _) {
                  return FractionallySizedBox(
                    widthFactor:
                        widget.ratio * Curves.easeOutCubic.transform(_c.value),
                    child: Container(
                      height: 6,
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [
                            DashboardColors.accent,
                            DashboardColors.accentMuted,
                          ],
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: DashboardColors.accent.withValues(alpha: 0.4),
                            blurRadius: 4,
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ],
          ),
        ),
      ],
    );
  }
}
