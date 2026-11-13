import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_theme.dart';
import '../../domain/entities/portfolio_entities.dart';
import '../providers/portfolio_providers.dart';
import '../widgets/async_state_view.dart';
import '../widgets/external_link.dart';
import '../widgets/project_lightbox_sheet.dart';

class ProjectsScreen extends ConsumerStatefulWidget {
  const ProjectsScreen({super.key});

  @override
  ConsumerState<ProjectsScreen> createState() => _ProjectsScreenState();
}

class _ProjectsScreenState extends ConsumerState<ProjectsScreen> {
  final _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final filteredAsync = ref.watch(filteredProjectsProvider);
    final languages = ref.watch(availableLanguagesProvider);
    final selectedLanguage = ref.watch(selectedLanguageProvider);
    final query = ref.watch(projectSearchQueryProvider);
    final hasActiveFilter = selectedLanguage != null || query.trim().isNotEmpty;
    final folio = context.folio;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        LayoutBuilder(
          builder: (context, constraints) {
            final isWide = constraints.maxWidth >= 720;
            final padH = isWide ? 40.0 : 20.0;
            final count = filteredAsync.valueOrNull?.length;

            return Container(
              padding: EdgeInsets.fromLTRB(padH, isWide ? 28 : 20, padH, 16),
              decoration: BoxDecoration(
                border: Border(bottom: BorderSide(color: folio.hairline)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.baseline,
                    textBaseline: TextBaseline.alphabetic,
                    children: [
                      Expanded(
                        child: Text(
                          'Catálogo de Projetos',
                          style: context.displayStyle(size: isWide ? 36 : 28),
                        ),
                      ),
                      if (count != null)
                        Text(
                          '$count ITENS',
                          style: context.monoStyle(size: 11, color: folio.accent),
                        ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Semantics(
                    textField: true,
                    label: 'Buscar projetos por nome ou tecnologia',
                    child: TextField(
                      controller: _searchController,
                      decoration: InputDecoration(
                        hintText: 'Buscar projetos...',
                        prefixIcon: Icon(Icons.search, size: 18, color: folio.inkMuted),
                        suffixIcon: query.isNotEmpty
                            ? IconButton(
                                tooltip: 'Limpar busca',
                                icon: Icon(Icons.clear, size: 18, color: folio.ink),
                                onPressed: () {
                                  _searchController.clear();
                                  ref.read(projectSearchQueryProvider.notifier).state = '';
                                },
                              )
                            : null,
                      ),
                      onChanged: (value) {
                        ref.read(projectSearchQueryProvider.notifier).state = value;
                      },
                    ),
                  ),
                  if (languages.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: [
                          Padding(
                            padding: const EdgeInsets.only(right: 8),
                            child: Semantics(
                              button: true,
                              selected: selectedLanguage == null,
                              label: 'Filtrar por todas as linguagens',
                              child: FilterChip(
                                label: Text(
                                  'Todas',
                                  style: TextStyle(
                                    color: selectedLanguage == null
                                        ? folio.contrastInk
                                        : folio.ink,
                                  ),
                                ),
                                selected: selectedLanguage == null,
                                side: BorderSide(
                                  color: selectedLanguage == null
                                      ? folio.contrastSurface
                                      : folio.hairline,
                                ),
                                onSelected: (_) {
                                  ref.read(selectedLanguageProvider.notifier).state = null;
                                },
                              ),
                            ),
                          ),
                          for (final lang in languages)
                            Padding(
                              padding: const EdgeInsets.only(right: 8),
                              child: Semantics(
                                button: true,
                                selected: selectedLanguage == lang,
                                label: 'Filtrar por $lang',
                                child: FilterChip(
                                  label: Text(
                                    lang,
                                    style: TextStyle(
                                      color: selectedLanguage == lang
                                          ? folio.contrastInk
                                          : folio.ink,
                                    ),
                                  ),
                                  selected: selectedLanguage == lang,
                                  side: BorderSide(
                                    color: selectedLanguage == lang
                                        ? folio.contrastSurface
                                        : folio.hairline,
                                  ),
                                  onSelected: (selected) {
                                    ref.read(selectedLanguageProvider.notifier).state =
                                        selected ? lang : null;
                                  },
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            );
          },
        ),
        Expanded(
          child: AsyncStateView<List<Project>>(
            value: filteredAsync,
            onRetry: () => ref.invalidate(projectsFeedProvider),
            isEmpty: (items) => items.isEmpty,
            emptyIcon: Icons.search_off_outlined,
            emptyTitle: hasActiveFilter
                ? 'Nenhum projeto encontrado'
                : 'Nenhum repositório público',
            emptyMessage: hasActiveFilter
                ? 'Tente ajustar a busca ou limpar o filtro de linguagem.'
                : 'Os repositórios públicos aparecerão aqui automaticamente.',
            emptyAction: hasActiveFilter
                ? OutlinedButton(
                    onPressed: () {
                      _searchController.clear();
                      ref.read(projectSearchQueryProvider.notifier).state = '';
                      ref.read(selectedLanguageProvider.notifier).state = null;
                    },
                    child: const Text('Limpar filtros'),
                  )
                : null,
            builder: (projects) {
              return RefreshIndicator(
                color: folio.accent,
                onRefresh: () => ref.refresh(projectsFeedProvider.future),
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final isWide = constraints.maxWidth >= 720;
                    final padH = isWide ? 40.0 : 20.0;

                    return ListView.separated(
                      padding: EdgeInsets.fromLTRB(padH, 12, padH, 32),
                      itemCount: projects.length,
                      separatorBuilder: (_, _) => Divider(color: folio.hairline),
                      itemBuilder: (context, index) => _CatalogProjectRow(
                        ordinal: index + 1,
                        project: projects[index],
                        isWide: isWide,
                        onOpenDetail: () =>
                            showProjectLightbox(context, projects[index].name),
                      ),
                    );
                  },
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

class _CatalogProjectRow extends StatelessWidget {
  const _CatalogProjectRow({
    required this.ordinal,
    required this.project,
    required this.isWide,
    required this.onOpenDetail,
  });

  final int ordinal;
  final Project project;
  final bool isWide;
  final VoidCallback onOpenDetail;

  @override
  Widget build(BuildContext context) {
    final folio = context.folio;
    final formattedDate = project.lastCommit == null
        ? 'Sem commits'
        : '${project.lastCommit!.day.toString().padLeft(2, '0')}/'
            '${project.lastCommit!.month.toString().padLeft(2, '0')}/'
            '${project.lastCommit!.year}';
    final indexCode = 'N° ${ordinal.toString().padLeft(2, '0')}';

    final detailsColumn = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          project.name,
          style: context.displayStyle(size: isWide ? 24 : 21, height: 1.12),
        ),
        const SizedBox(height: 6),
        Text(
          project.description.isNotEmpty
              ? project.description
              : 'Sem descrição cadastrada no GitHub.',
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: folio.inkMuted,
              ),
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
        if (project.languages.isNotEmpty) ...[
          const SizedBox(height: 12),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              for (final lang in project.languages)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    border: Border.all(color: folio.hairline),
                    borderRadius: BorderRadius.circular(2),
                  ),
                  child: Text(
                    lang,
                    style: context.monoStyle(size: 11, color: folio.ink),
                  ),
                ),
            ],
          ),
        ],
      ],
    );

    final actionsRow = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Semantics(
          button: true,
          label: 'Abrir ${project.name} no GitHub',
          child: TextButton(
            onPressed: () => openExternalUrl(context, project.url),
            child: const Text('GitHub'),
          ),
        ),
        const SizedBox(width: 4),
        Semantics(
          button: true,
          label: 'Inspecionar ficha técnica de ${project.name}',
          child: OutlinedButton.icon(
            onPressed: onOpenDetail,
            icon: Icon(Icons.north_east, size: 14, color: folio.accent),
            label: const Text('Ficha'),
          ),
        ),
      ],
    );

    final starReadout = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(Icons.star_outline, size: 13, color: folio.inkMuted),
        const SizedBox(width: 4),
        Text(
          '${project.stars}',
          style: context.monoStyle(size: isWide ? 12 : 11, color: folio.ink),
        ),
      ],
    );

    return InkWell(
      onTap: onOpenDetail,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 18),
        child: isWide
            ? Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(
                    width: 112,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          indexCode,
                          style: context.monoStyle(
                            size: 12,
                            color: ordinal == 1 ? folio.accent : folio.inkMuted,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          formattedDate,
                          style: context.monoStyle(size: 11, color: folio.inkMuted),
                        ),
                      ],
                    ),
                  ),
                  Expanded(child: detailsColumn),
                  const SizedBox(width: 24),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      starReadout,
                      const SizedBox(height: 12),
                      actionsRow,
                    ],
                  ),
                ],
              )
            : Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        '$indexCode · $formattedDate',
                        style: context.monoStyle(size: 11, color: folio.accent),
                      ),
                      starReadout,
                    ],
                  ),
                  const SizedBox(height: 10),
                  detailsColumn,
                  const SizedBox(height: 12),
                  Align(alignment: Alignment.centerRight, child: actionsRow),
                ],
              ),
      ),
    );
  }
}
