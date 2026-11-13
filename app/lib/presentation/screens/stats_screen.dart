import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_theme.dart';
import '../../domain/entities/portfolio_entities.dart';
import '../providers/portfolio_providers.dart';
import '../widgets/activity_chart_painter.dart';
import '../widgets/async_state_view.dart';
import '../widgets/language_chart_painter.dart';

class StatsScreen extends ConsumerWidget {
  const StatsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final statsAsync = ref.watch(statsProvider);
    final folio = context.folio;

    return AsyncStateView<PortfolioStats>(
      value: statsAsync,
      onRetry: () => ref.invalidate(statsProvider),
      isEmpty: (stats) =>
          stats.totalProjects == 0 &&
          stats.languages.isEmpty &&
          stats.activity.isEmpty,
      emptyIcon: Icons.analytics_outlined,
      emptyTitle: 'Sem estatísticas disponíveis',
      emptyMessage: 'Não há dados suficientes de repositórios ou commits ainda.',
      builder: (stats) {
        final recentCommits = stats.activity.fold<int>(0, (sum, p) => sum + p.commits);

        return RefreshIndicator(
          color: folio.accent,
          onRefresh: () => ref.refresh(statsProvider.future),
          child: LayoutBuilder(
            builder: (context, constraints) {
              final width = constraints.maxWidth;
              final isWide = width >= 880;
              final isCompact = width < 520;
              final padH = isWide ? 40.0 : 20.0;
              final panelPad = isWide ? 28.0 : 20.0;
              final chartInnerWidth = isWide
                  ? (width - padH * 2 - 1) / 2 - panelPad * 2
                  : width - padH * 2 - panelPad * 2;

              final ledgerItems = [
                _LedgerMetric(label: 'REPOSITÓRIOS', value: '${stats.totalProjects}'),
                _LedgerMetric(label: 'ESTRELAS', value: '${stats.totalStars}'),
                _LedgerMetric(label: 'COMMITS (14D)', value: '$recentCommits'),
              ];

              final languagesPanel = Padding(
                padding: EdgeInsets.all(panelPad),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Linguagens mais usadas',
                      style: context.displayStyle(size: 24),
                    ),
                    const SizedBox(height: 20),
                    LanguageBreakdownChart(
                      languages: stats.languages,
                      sideBySide: chartInnerWidth >= 460,
                    ),
                  ],
                ),
              );

              final activityPanel = Padding(
                padding: EdgeInsets.all(panelPad),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Atividade recente de commits',
                      style: context.displayStyle(size: 24),
                    ),
                    const SizedBox(height: 20),
                    CommitActivityChart(activity: stats.activity),
                  ],
                ),
              );

              return ListView(
                padding: EdgeInsets.fromLTRB(padH, isWide ? 28 : 20, padH, 36),
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Expanded(
                        child: Text(
                          'Estatísticas do GitHub',
                          style: context.displayStyle(size: isWide ? 36 : 28),
                        ),
                      ),
                      Semantics(
                        button: true,
                        label: 'Atualizar estatísticas',
                        child: OutlinedButton.icon(
                          onPressed: () => ref.invalidate(statsProvider),
                          icon: const Icon(Icons.refresh, size: 15),
                          label: Text(isCompact ? 'Atualizar' : 'Sincronizar'),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  Container(
                    decoration: BoxDecoration(
                      color: folio.surface,
                      border: Border.all(color: folio.hairline),
                      borderRadius: BorderRadius.circular(2),
                    ),
                    child: isCompact
                        ? Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              for (var i = 0; i < ledgerItems.length; i++)
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 18,
                                    vertical: 14,
                                  ),
                                  decoration: BoxDecoration(
                                    border: Border(
                                      bottom: BorderSide(
                                        color: i == ledgerItems.length - 1
                                            ? Colors.transparent
                                            : folio.hairline,
                                      ),
                                    ),
                                  ),
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Text(
                                        ledgerItems[i].label,
                                        style: context.monoStyle(size: 11),
                                      ),
                                      Text(
                                        ledgerItems[i].value,
                                        style: context.displayStyle(
                                          size: 26,
                                          color: i == 2 ? folio.accent : folio.ink,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                            ],
                          )
                        : IntrinsicHeight(
                            child: Row(
                              children: [
                                for (var i = 0; i < ledgerItems.length; i++) ...[
                                  if (i > 0) Container(width: 1, color: folio.hairline),
                                  Expanded(
                                    child: Padding(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 22,
                                        vertical: 18,
                                      ),
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            ledgerItems[i].label,
                                            style: context.monoStyle(size: 10),
                                          ),
                                          const SizedBox(height: 8),
                                          Text(
                                            ledgerItems[i].value,
                                            style: context.displayStyle(
                                              size: 36,
                                              color: i == 2 ? folio.accent : folio.ink,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                  ),
                  const SizedBox(height: 24),
                  Container(
                    decoration: BoxDecoration(
                      color: folio.surface,
                      border: Border.all(color: folio.hairline),
                      borderRadius: BorderRadius.circular(2),
                    ),
                    child: isWide
                        ? IntrinsicHeight(
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                Expanded(child: languagesPanel),
                                Container(width: 1, color: folio.hairline),
                                Expanded(child: activityPanel),
                              ],
                            ),
                          )
                        : Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              languagesPanel,
                              Container(height: 1, color: folio.hairline),
                              activityPanel,
                            ],
                          ),
                  ),
                ],
              );
            },
          ),
        );
      },
    );
  }
}

class _LedgerMetric {
  const _LedgerMetric({required this.label, required this.value});

  final String label;
  final String value;
}
