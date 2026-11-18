import 'dart:math' as math;

import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/config/app_config.dart';
import '../../core/theme/app_theme.dart';
import '../../domain/entities/portfolio_entities.dart';
import '../providers/portfolio_providers.dart';
import '../widgets/async_state_view.dart';
import '../widgets/external_link.dart';
import '../widgets/project_lightbox_sheet.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final feedAsync = ref.watch(projectsFeedProvider);
    final folio = context.folio;
    final disableAnimations = MediaQuery.disableAnimationsOf(context);

    return AsyncStateView<ProjectsFeed>(
      value: feedAsync,
      onRetry: () => ref.invalidate(projectsFeedProvider),
      isEmpty: (feed) => feed.owner.username.isEmpty && feed.projects.isEmpty,
      emptyTitle: 'Perfil indisponível',
      emptyMessage: 'Nenhum dado de perfil encontrado.',
      builder: (feed) {
        final owner = feed.owner;
        final totalStars = feed.projects.fold<int>(0, (sum, p) => sum + p.stars);
        final topLanguages = feed.projects
            .expand((p) => p.languages)
            .toSet()
            .take(6)
            .toList(growable: false);
        final featured = feed.projects.take(4).toList(growable: false);

        return RefreshIndicator(
          color: folio.accent,
          onRefresh: () => ref.refresh(projectsFeedProvider.future),
          child: LayoutBuilder(
            builder: (context, constraints) {
              final isWide = constraints.maxWidth >= 860;
              final splitMinHeight = math.max(0.0, constraints.maxHeight - 56);
              const displayName = AppConfig.ownerDisplayName;

              final leadSection = Padding(
                padding: EdgeInsets.all(isWide ? 44 : 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          displayName,
                          style: context.displayStyle(
                            size: isWide ? 72 : 44,
                            height: 0.98,
                            letterSpacing: -0.03,
                          ),
                        ),
                        SizedBox(height: isWide ? 28 : 20),
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            _PortraitFrame(
                              avatarUrl: owner.avatarUrl,
                              displayName: displayName,
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    '@${owner.username}',
                                    style: context.monoStyle(
                                      size: 13,
                                      color: folio.accent,
                                    ),
                                  ),
                                  const SizedBox(height: 6),
                                  ConstrainedBox(
                                    constraints: const BoxConstraints(maxWidth: 480),
                                    child: Text(
                                      owner.bio.isNotEmpty
                                          ? owner.bio
                                          : 'Desenvolvedor focado em backend Go, arquitetura de dados e interfaces autorais em Flutter.',
                                      style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                                            color: folio.inkMuted,
                                            fontSize: isWide ? 17 : 15,
                                          ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                    const SizedBox(height: 32),
                    Wrap(
                      spacing: 10,
                      runSpacing: 10,
                      children: [
                        Semantics(
                          button: true,
                          label: 'Explorar catálogo de projetos',
                          child: FilledButton.icon(
                            onPressed: () {
                              ref.read(selectedTabProvider.notifier).state = 1;
                            },
                            icon: const Icon(Icons.north_east, size: 15),
                            label: const Text('Explorar Projetos'),
                          ),
                        ),
                        Semantics(
                          button: true,
                          label: 'Abrir currículo',
                          child: OutlinedButton.icon(
                            onPressed: () =>
                                _openResume(context, feed, topLanguages),
                            icon: const Icon(Icons.description_outlined, size: 15),
                            label: const Text('Currículo'),
                          ),
                        ),
                        if (owner.profileUrl.isNotEmpty)
                          Semantics(
                            button: true,
                            label: 'Abrir perfil no GitHub',
                            child: OutlinedButton.icon(
                              onPressed: () =>
                                  openExternalUrl(context, owner.profileUrl),
                              icon: const Icon(Icons.code, size: 15),
                              label: const Text('GitHub'),
                            ),
                          ),
                        Semantics(
                          button: true,
                          label: 'Abrir perfil no LinkedIn',
                          child: OutlinedButton.icon(
                            onPressed: () =>
                                openExternalUrl(context, AppConfig.linkedInUrl),
                            icon: const Icon(Icons.north_east, size: 15),
                            label: const Text('LinkedIn'),
                          ),
                        ),
                        Semantics(
                          button: true,
                          label: 'Ir para formulário de contato',
                          child: OutlinedButton.icon(
                            onPressed: () {
                              ref.read(selectedTabProvider.notifier).state = 4;
                            },
                            icon: const Icon(Icons.mail_outline, size: 15),
                            label: const Text('Contato'),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              );

              final proofSheet = TweenAnimationBuilder<double>(
                tween: Tween(begin: disableAnimations ? 1.0 : 0.0, end: 1.0),
                duration: disableAnimations
                    ? Duration.zero
                    : const Duration(milliseconds: 550),
                curve: Curves.easeOutCubic,
                builder: (context, t, child) {
                  return Opacity(
                    opacity: t,
                    child: Transform.translate(
                      offset: Offset(0, (1 - t) * 14),
                      child: child,
                    ),
                  );
                },
                child: Container(
                  color: folio.contrastSurface,
                  padding: EdgeInsets.all(isWide ? 40 : 22),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '“Arquitetura legível, dados normalizados e interfaces com presença em produção.”',
                            style: context.displayStyle(
                              size: isWide ? 32 : 24,
                              height: 1.24,
                              color: folio.contrastInk,
                            ),
                          ),
                          if (topLanguages.isNotEmpty) ...[
                            const SizedBox(height: 16),
                            Text(
                              topLanguages.join('  ·  ').toUpperCase(),
                              style: context.monoStyle(
                                size: 11,
                                color: folio.contrastMuted,
                              ),
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 28),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Container(
                            padding: const EdgeInsets.only(bottom: 10),
                            decoration: BoxDecoration(
                              border: Border(
                                bottom: BorderSide(color: folio.contrastHairline),
                              ),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  'ÍNDICE SELECIONADO',
                                  style: context.monoStyle(
                                    size: 10,
                                    color: folio.contrastMuted,
                                  ),
                                ),
                                Text(
                                  '${feed.projects.length} PÚBLICOS',
                                  style: context.monoStyle(
                                    size: 10,
                                    color: folio.contrastAccent,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          for (var i = 0; i < featured.length; i++)
                            _CatalogPreviewRow(
                              index: i + 1,
                              project: featured[i],
                              onTap: () =>
                                  showProjectLightbox(context, featured[i].name),
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
              );

              final bottomLedger = Container(
                padding: EdgeInsets.symmetric(
                  horizontal: isWide ? 44 : 20,
                  vertical: 18,
                ),
                decoration: BoxDecoration(
                  border: Border(top: BorderSide(color: folio.hairline)),
                ),
                child: Wrap(
                  spacing: 28,
                  runSpacing: 8,
                  alignment: WrapAlignment.spaceBetween,
                  children: [
                    Text(
                      '${feed.projects.length} ${feed.projects.length == 1 ? 'REPOSITÓRIO SINCRONIZADO' : 'REPOSITÓRIOS SINCRONIZADOS'}',
                      style: context.monoStyle(size: 11, color: folio.ink),
                    ),
                    Text(
                      '$totalStars ${totalStars == 1 ? 'ESTRELA NO GITHUB' : 'ESTRELAS NO GITHUB'}',
                      style: context.monoStyle(size: 11, color: folio.inkMuted),
                    ),
                    Text(
                      '${topLanguages.length} ${topLanguages.length == 1 ? 'LINGUAGEM PRINCIPAL' : 'LINGUAGENS PRINCIPAIS'}',
                      style: context.monoStyle(size: 11, color: folio.inkMuted),
                    ),
                  ],
                ),
              );

              return SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                child: ConstrainedBox(
                  constraints: BoxConstraints(minHeight: constraints.maxHeight),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      if (isWide)
                        ConstrainedBox(
                          constraints: BoxConstraints(minHeight: splitMinHeight),
                          child: IntrinsicHeight(
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                Expanded(flex: 11, child: leadSection),
                                Container(width: 1, color: folio.hairline),
                                Expanded(flex: 9, child: proofSheet),
                              ],
                            ),
                          ),
                        )
                      else ...[
                        leadSection,
                        Container(height: 1, color: folio.hairline),
                        proofSheet,
                      ],
                      bottomLedger,
                    ],
                  ),
                ),
              );
            },
          ),
        );
      },
    );
  }

  void _openResume(
    BuildContext context,
    ProjectsFeed feed,
    List<String> topLanguages,
  ) {
    if (AppConfig.resumeUrl.trim().isNotEmpty) {
      openExternalUrl(context, AppConfig.resumeUrl);
      return;
    }

    final folio = context.folio;
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      backgroundColor: folio.contrastSurface,
      builder: (context) {
        final owner = feed.owner;
        return Padding(
          padding: const EdgeInsets.fromLTRB(28, 8, 28, 32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Currículo · ${AppConfig.ownerDisplayName}',
                style: context.displayStyle(
                  size: 28,
                  color: folio.contrastInk,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                owner.bio.isNotEmpty
                    ? owner.bio
                    : 'Desenvolvedor de software com foco em Go, Flutter e sistemas web.',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: folio.contrastMuted,
                    ),
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.symmetric(vertical: 12),
                decoration: BoxDecoration(
                  border: Border(
                    top: BorderSide(color: folio.contrastHairline),
                    bottom: BorderSide(color: folio.contrastHairline),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Repositórios públicos: ${feed.projects.length}',
                      style: context.monoStyle(size: 12, color: folio.contrastInk),
                    ),
                    if (topLanguages.isNotEmpty) ...[
                      const SizedBox(height: 6),
                      Text(
                        'Stack detectada: ${topLanguages.join(', ')}',
                        style: context.monoStyle(size: 12, color: folio.contrastMuted),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 20),
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: [
                  FilledButton.icon(
                    style: FilledButton.styleFrom(
                      backgroundColor: folio.contrastInk,
                      foregroundColor: folio.contrastSurface,
                    ),
                    onPressed: () => openExternalUrl(
                      context,
                      AppConfig.defaultPublicResumeUrl,
                    ),
                    icon: const Icon(Icons.picture_as_pdf_outlined, size: 15),
                    label: const Text('Baixar PDF'),
                  ),
                  if (owner.profileUrl.isNotEmpty)
                    OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: folio.contrastInk,
                        side: BorderSide(color: folio.contrastHairline),
                      ),
                      onPressed: () => openExternalUrl(context, owner.profileUrl),
                      icon: const Icon(Icons.code, size: 15),
                      label: const Text('GitHub'),
                    ),
                  OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: folio.contrastInk,
                      side: BorderSide(color: folio.contrastHairline),
                    ),
                    onPressed: () =>
                        openExternalUrl(context, AppConfig.linkedInUrl),
                    icon: const Icon(Icons.north_east, size: 15),
                    label: const Text('LinkedIn'),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }
}

class _CatalogPreviewRow extends StatelessWidget {
  const _CatalogPreviewRow({
    required this.index,
    required this.project,
    required this.onTap,
  });

  final int index;
  final Project project;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final folio = context.folio;
    final ordinal = 'N° ${index.toString().padLeft(2, '0')}';
    final langLabel =
        project.languages.isEmpty ? 'Código' : project.languages.take(2).join(' · ');
    final metaLabel = project.stars > 0
        ? '$langLabel · ${project.stars} ${project.stars == 1 ? 'estrela' : 'estrelas'}'
        : langLabel;

    return Semantics(
      button: true,
      label: 'Abrir ficha técnica de ${project.name}',
      child: InkWell(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 13),
          decoration: BoxDecoration(
            border: Border(bottom: BorderSide(color: folio.contrastHairline)),
          ),
          child: Row(
            children: [
              SizedBox(
                width: 56,
                child: Text(
                  ordinal,
                  style: context.monoStyle(size: 11, color: folio.contrastMuted),
                ),
              ),
              Expanded(
                child: Text(
                  project.name,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontFamily: 'Archivo',
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: folio.contrastInk,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Text(
                metaLabel,
                style: context.monoStyle(size: 11, color: folio.contrastAccent),
              ),
              const SizedBox(width: 10),
              Icon(Icons.north_east, size: 15, color: folio.contrastInk),
            ],
          ),
        ),
      ),
    );
  }
}

class _PortraitFrame extends StatelessWidget {
  const _PortraitFrame({required this.avatarUrl, required this.displayName});

  final String avatarUrl;
  final String displayName;

  @override
  Widget build(BuildContext context) {
    final folio = context.folio;
    final initial = displayName.trim().isEmpty
        ? 'K'
        : displayName.trim().substring(0, 1).toUpperCase();

    Widget fallbackBox() => Container(
          width: 60,
          height: 60,
          alignment: Alignment.center,
          color: folio.surfaceAlt,
          child: Text(
            initial,
            style: context.displayStyle(size: 28, color: folio.accent),
          ),
        );

    return Container(
      width: 62,
      height: 62,
      decoration: BoxDecoration(
        border: Border.all(color: folio.hairline),
        borderRadius: BorderRadius.circular(2),
      ),
      clipBehavior: Clip.antiAlias,
      child: avatarUrl.trim().isEmpty
          ? fallbackBox()
          : Image.network(
              avatarUrl,
              width: 60,
              height: 60,
              fit: BoxFit.cover,
              errorBuilder: (context, error, stackTrace) => fallbackBox(),
            ),
    );
  }
}
