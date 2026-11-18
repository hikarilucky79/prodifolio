import 'dart:math' as math;

import 'package:material_ui/material_ui.dart';

import '../../core/theme/app_theme.dart';
import '../../domain/entities/portfolio_entities.dart';

class LanguageBreakdownChart extends StatelessWidget {
  const LanguageBreakdownChart({
    super.key,
    required this.languages,
    this.sideBySide,
  });

  final List<LanguageStat> languages;
  final bool? sideBySide;

  @override
  Widget build(BuildContext context) {
    if (languages.isEmpty) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 24),
        child: Center(child: Text('Sem linguagens registradas.')),
      );
    }

    final folio = context.folio;
    final disableAnimations = MediaQuery.disableAnimationsOf(context);
    final summary = languages
        .take(5)
        .map((l) => '${l.name}: ${l.percentage.toStringAsFixed(1)}%')
        .join(', ');
    final useHorizontal = sideBySide ?? (MediaQuery.sizeOf(context).width >= 600);

    Color swatchFor(int idx) => folio.chartPalette[idx % folio.chartPalette.length];

    final chart = SizedBox(
      width: 196,
      height: 196,
      child: TweenAnimationBuilder<double>(
        tween: Tween(begin: disableAnimations ? 1.0 : 0.0, end: 1.0),
        duration: disableAnimations
            ? Duration.zero
            : const Duration(milliseconds: 650),
        curve: Curves.easeOutCubic,
        builder: (context, progress, _) {
          return CustomPaint(
            painter: LanguageChartPainter(
              languages: languages,
              progress: progress,
              palette: folio.chartPalette,
              trackColor: folio.hairline,
              textColor: folio.ink,
              mutedColor: folio.inkMuted,
            ),
          );
        },
      ),
    );

    final legend = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var i = 0; i < languages.length; i++)
          Container(
            padding: const EdgeInsets.symmetric(vertical: 9),
            decoration: BoxDecoration(
              border: Border(
                bottom: BorderSide(
                  color: i == languages.length - 1
                      ? Colors.transparent
                      : folio.hairline,
                ),
              ),
            ),
            child: Row(
              children: [
                Container(
                  width: 10,
                  height: 10,
                  color: swatchFor(i),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    languages[i].name,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontWeight: FontWeight.w500),
                  ),
                ),
                Text(
                  '${languages[i].count} ${languages[i].count == 1 ? 'repo' : 'repos'} · ${languages[i].percentage.toStringAsFixed(1)}%',
                  style: context.monoStyle(size: 11, color: folio.inkMuted),
                ),
              ],
            ),
          ),
      ],
    );

    return Semantics(
      label: 'Gráfico de linguagens mais usadas: $summary',
      child: useHorizontal
          ? Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                chart,
                const SizedBox(width: 28),
                Expanded(child: legend),
              ],
            )
          : Column(
              children: [
                chart,
                const SizedBox(height: 20),
                legend,
              ],
            ),
    );
  }
}

class LanguageChartPainter extends CustomPainter {
  LanguageChartPainter({
    required this.languages,
    required this.progress,
    required this.palette,
    required this.trackColor,
    required this.textColor,
    required this.mutedColor,
  });

  final List<LanguageStat> languages;
  final double progress;
  final List<Color> palette;
  final Color trackColor;
  final Color textColor;
  final Color mutedColor;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = math.min(size.width, size.height) * 0.37;
    const strokeWidth = 18.0;
    final rect = Rect.fromCircle(center: center, radius: radius);

    final outerRule = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1
      ..color = trackColor;
    canvas.drawCircle(center, radius + strokeWidth / 2 + 6, outerRule);
    canvas.drawCircle(center, radius - strokeWidth / 2 - 6, outerRule);

    final trackPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..color = trackColor.withValues(alpha: 0.35);
    canvas.drawCircle(center, radius, trackPaint);

    final totalCount = languages.fold<int>(0, (sum, item) => sum + item.count);
    if (totalCount == 0) return;

    var startAngle = -math.pi / 2;
    final maxSweep = math.pi * 2 * progress;
    var drawn = 0.0;

    for (var i = 0; i < languages.length; i++) {
      final slice = (languages[i].count / totalCount) * math.pi * 2;
      final remaining = maxSweep - drawn;
      if (remaining <= 0) break;

      final sweep = math.min(slice, remaining);
      final paint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth
        ..strokeCap = StrokeCap.butt
        ..color = palette[i % palette.length];

      canvas.drawArc(rect, startAngle, sweep, false, paint);
      startAngle += slice;
      drawn += sweep;
    }

    final top = languages.first;
    final tp = TextPainter(
      text: TextSpan(
        children: [
          TextSpan(
            text: '${top.percentage.toStringAsFixed(0)}%\n',
            style: TextStyle(
              fontFamily: 'BodoniModa',
              color: textColor,
              fontSize: 28,
              height: 1.0,
            ),
          ),
          TextSpan(
            text: top.name.toUpperCase(),
            style: TextStyle(
              fontFamily: 'JetBrainsMono',
              color: mutedColor,
              fontSize: 10,
              letterSpacing: 1.0,
              height: 1.4,
            ),
          ),
        ],
      ),
      textAlign: TextAlign.center,
      textDirection: TextDirection.ltr,
    )..layout(maxWidth: radius * 1.4);

    tp.paint(canvas, center - Offset(tp.width / 2, tp.height / 2));
  }

  @override
  bool shouldRepaint(covariant LanguageChartPainter oldDelegate) {
    return oldDelegate.progress != progress ||
        oldDelegate.languages != languages ||
        oldDelegate.textColor != textColor ||
        oldDelegate.trackColor != trackColor;
  }
}
