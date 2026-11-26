import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_theme.dart';
import '../../domain/entities/portfolio_entities.dart';
import '../providers/portfolio_providers.dart';
import '../widgets/async_state_view.dart';

class AboutScreen extends ConsumerWidget {
  const AboutScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final timelineAsync = ref.watch(aboutTimelineProvider);

    return AsyncStateView<List<TimelineMilestone>>(
      value: timelineAsync,
      onRetry: () => ref.invalidate(projectsFeedProvider),
      isEmpty: (items) => items.isEmpty,
      emptyIcon: Icons.timeline_outlined,
      emptyTitle: 'Linha do tempo vazia',
      emptyMessage: 'Nenhum marco cadastrado no momento.',
      builder: (milestones) => _AnimatedTimeline(milestones: milestones),
    );
  }
}

class _AnimatedTimeline extends StatefulWidget {
  const _AnimatedTimeline({required this.milestones});

  final List<TimelineMilestone> milestones;

  @override
  State<_AnimatedTimeline> createState() => _AnimatedTimelineState();
}

class _AnimatedTimelineState extends State<_AnimatedTimeline>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    )..forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final disableAnimations = MediaQuery.disableAnimationsOf(context);
    final folio = context.folio;

    return LayoutBuilder(
      builder: (context, constraints) {
        final isWide = constraints.maxWidth >= 860;
        final padH = isWide ? 40.0 : 20.0;

        final manifestoPlate = Container(
          padding: EdgeInsets.all(isWide ? 32 : 22),
          decoration: BoxDecoration(
            color: folio.contrastSurface,
            border: Border.all(color: folio.contrastHairline),
            borderRadius: BorderRadius.circular(2),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '“Da modelagem relacional ao último pixel: sistemas pensados com clareza estrutural e prova em produção.”',
                style: context.displayStyle(
                  size: isWide ? 26 : 22,
                  height: 1.24,
                  color: folio.contrastInk,
                ),
              ),
              const SizedBox(height: 24),
              const _PracticeNote(
                index: 'A',
                title: 'Backend em Go 1.22+',
                body: 'Serviços REST concorrentes, cache TTL em memória e rate limit por IP.',
              ),
              const _PracticeNote(
                index: 'B',
                title: 'Banco TiDB Cloud em 3FN',
                body: 'Modelagem normalizada, integridade transacional e protocolo PostgreSQL.',
              ),
              const _PracticeNote(
                index: 'C',
                title: 'Apps em Flutter & CustomPainter',
                body: 'Gráficos desenhados manualmente, acessibilidade e multi-viewport.',
                isLast: true,
              ),
            ],
          ),
        );

        final timelineList = Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (var i = 0; i < widget.milestones.length; i++)
              _TimelineItemTile(
                milestone: widget.milestones[i],
                isLast: i == widget.milestones.length - 1,
                animation: disableAnimations
                    ? const AlwaysStoppedAnimation(1.0)
                    : CurvedAnimation(
                        parent: _controller,
                        curve: Interval(
                          (i * 0.18).clamp(0.0, 0.55),
                          ((i * 0.18) + 0.45).clamp(0.45, 1.0),
                          curve: Curves.easeOutCubic,
                        ),
                      ),
              ),
          ],
        );

        return ListView(
          padding: EdgeInsets.fromLTRB(padH, isWide ? 28 : 20, padH, 36),
          children: [
            Text(
              'Sobre & Trajetória',
              style: context.displayStyle(size: isWide ? 36 : 28),
            ),
            const SizedBox(height: 24),
            if (isWide)
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(flex: 5, child: manifestoPlate),
                  const SizedBox(width: 28),
                  Expanded(flex: 7, child: timelineList),
                ],
              )
            else ...[
              manifestoPlate,
              const SizedBox(height: 28),
              timelineList,
            ],
          ],
        );
      },
    );
  }
}

class _PracticeNote extends StatelessWidget {
  const _PracticeNote({
    required this.index,
    required this.title,
    required this.body,
    this.isLast = false,
  });

  final String index;
  final String title;
  final String body;
  final bool isLast;

  @override
  Widget build(BuildContext context) {
    final folio = context.folio;

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 14),
      decoration: BoxDecoration(
        border: Border(
          top: BorderSide(color: folio.contrastHairline),
          bottom: isLast ? BorderSide(color: folio.contrastHairline) : BorderSide.none,
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 26,
            child: Text(
              index,
              style: context.monoStyle(size: 11, color: folio.contrastAccent),
            ),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontFamily: 'Archivo',
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                    color: folio.contrastInk,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  body,
                  style: TextStyle(
                    fontFamily: 'Archivo',
                    fontSize: 13,
                    height: 1.45,
                    color: folio.contrastMuted,
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

class _TimelineItemTile extends StatelessWidget {
  const _TimelineItemTile({
    required this.milestone,
    required this.isLast,
    required this.animation,
  });

  final TimelineMilestone milestone;
  final bool isLast;
  final Animation<double> animation;

  @override
  Widget build(BuildContext context) {
    final folio = context.folio;

    return FadeTransition(
      opacity: animation,
      child: SlideTransition(
        position: Tween<Offset>(
          begin: const Offset(0, 0.08),
          end: Offset.zero,
        ).animate(animation),
        child: IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SizedBox(
                width: 24,
                child: Column(
                  children: [
                    Container(
                      width: 10,
                      height: 10,
                      margin: const EdgeInsets.only(top: 6),
                      color: folio.accent,
                    ),
                    if (!isLast)
                      Expanded(
                        child: Container(
                          width: 1,
                          color: folio.hairline,
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Container(
                  margin: EdgeInsets.only(bottom: isLast ? 0 : 20),
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: folio.surface,
                    border: Border.all(color: folio.hairline),
                    borderRadius: BorderRadius.circular(2),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        milestone.period.toUpperCase(),
                        style: context.monoStyle(size: 11, color: folio.accent),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        milestone.title,
                        style: context.displayStyle(size: 22, height: 1.15),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        milestone.subtitle,
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                      const SizedBox(height: 12),
                      for (final highlight in milestone.highlights)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 5),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '— ',
                                style: context.monoStyle(size: 12, color: folio.accent),
                              ),
                              Expanded(
                                child: Text(
                                  highlight,
                                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                        color: folio.inkMuted,
                                      ),
                                ),
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
