import 'dart:math' as math;

import 'package:material_ui/material_ui.dart';

import '../../core/theme/app_theme.dart';
import '../../domain/entities/portfolio_entities.dart';

class CommitActivityChart extends StatelessWidget {
  const CommitActivityChart({super.key, required this.activity});

  final List<ActivityPoint> activity;

  @override
  Widget build(BuildContext context) {
    if (activity.isEmpty) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 24),
        child: Center(child: Text('Sem atividade recente registrada.')),
      );
    }

    final totalCommits = activity.fold<int>(0, (sum, p) => sum + p.commits);
    final folio = context.folio;
    final disableAnimations = MediaQuery.disableAnimationsOf(context);

    return Semantics(
      label: 'Gráfico de atividade recente: $totalCommits commits nos últimos ${activity.length} dias',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            height: 204,
            width: double.infinity,
            child: TweenAnimationBuilder<double>(
              tween: Tween(begin: disableAnimations ? 1.0 : 0.0, end: 1.0),
              duration: disableAnimations
                  ? Duration.zero
                  : const Duration(milliseconds: 650),
              curve: Curves.easeOutCubic,
              builder: (context, progress, _) {
                return CustomPaint(
                  painter: ActivityChartPainter(
                    activity: activity,
                    progress: progress,
                    barColor: folio.accentSecondary,
                    peakColor: folio.accent,
                    gridColor: folio.hairline,
                    labelColor: folio.inkMuted,
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'TOTAL NO PERÍODO: $totalCommits COMMITS (${activity.length} DIAS)',
            style: context.monoStyle(size: 11, color: folio.inkMuted),
          ),
        ],
      ),
    );
  }
}

class ActivityChartPainter extends CustomPainter {
  ActivityChartPainter({
    required this.activity,
    required this.progress,
    required this.barColor,
    required this.peakColor,
    required this.gridColor,
    required this.labelColor,
  });

  final List<ActivityPoint> activity;
  final double progress;
  final Color barColor;
  final Color peakColor;
  final Color gridColor;
  final Color labelColor;

  @override
  void paint(Canvas canvas, Size size) {
    if (activity.isEmpty) return;

    const leftPad = 32.0;
    const bottomPad = 24.0;
    const topPad = 12.0;
    final chartWidth = math.max(10.0, size.width - leftPad);
    final chartHeight = math.max(10.0, size.height - bottomPad - topPad);

    final maxCommits = math.max(
      1,
      activity.fold<int>(0, (m, p) => math.max(m, p.commits)),
    );

    final gridPaint = Paint()
      ..color = gridColor
      ..strokeWidth = 1;

    for (final ratio in const [0.0, 0.5, 1.0]) {
      final y = topPad + chartHeight * (1 - ratio);
      canvas.drawLine(Offset(leftPad, y), Offset(size.width, y), gridPaint);
      final value = (maxCommits * ratio).round();
      _drawLabel(
        canvas,
        '$value',
        Offset(0, y - 6),
        maxWidth: leftPad - 6,
        align: TextAlign.right,
      );
    }

    final slotWidth = chartWidth / activity.length;
    final barWidth = math.max(4.0, slotWidth * 0.56);
    final standardPaint = Paint()..color = barColor;
    final topPaint = Paint()..color = peakColor;
    final emptyPaint = Paint()..color = gridColor;

    for (var i = 0; i < activity.length; i++) {
      final count = activity[i].commits;
      final normalized = (count / maxCommits) * progress;
      final barHeight = count == 0 ? 2.0 : math.max(4.0, chartHeight * normalized);
      final left = leftPad + i * slotWidth + (slotWidth - barWidth) / 2;
      final top = topPad + chartHeight - barHeight;
      final rect = Rect.fromLTWH(left, top, barWidth, barHeight);
      final paint = count == 0
          ? emptyPaint
          : (count == maxCommits ? topPaint : standardPaint);
      canvas.drawRect(rect, paint);
    }

    final indices = <int>{0, activity.length ~/ 2, activity.length - 1};
    for (final idx in indices) {
      final rawDate = activity[idx].date;
      final shortDate = rawDate.length >= 10 ? rawDate.substring(5) : rawDate;
      final x = leftPad + idx * slotWidth;
      _drawLabel(
        canvas,
        shortDate,
        Offset(math.min(x, size.width - 40), topPad + chartHeight + 8),
        maxWidth: 46,
        align: TextAlign.left,
      );
    }
  }

  void _drawLabel(
    Canvas canvas,
    String text,
    Offset offset, {
    required double maxWidth,
    required TextAlign align,
  }) {
    final tp = TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(
          fontFamily: 'JetBrainsMono',
          fontSize: 10,
          color: labelColor,
          fontFeatures: const [FontFeature.tabularFigures()],
        ),
      ),
      textAlign: align,
      textDirection: TextDirection.ltr,
    )..layout(minWidth: maxWidth, maxWidth: maxWidth);
    tp.paint(canvas, offset);
  }

  @override
  bool shouldRepaint(covariant ActivityChartPainter oldDelegate) {
    return oldDelegate.progress != progress ||
        oldDelegate.activity != activity ||
        oldDelegate.barColor != barColor ||
        oldDelegate.peakColor != peakColor;
  }
}
