import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_theme.dart';
import '../../domain/entities/portfolio_entities.dart';
import '../providers/portfolio_providers.dart';
import 'async_state_view.dart';
import 'external_link.dart';
import 'project_preview_image.dart';

Future<void> showProjectLightbox(BuildContext context, String projectName) {
  return showDialog<void>(
    context: context,
    barrierColor: Colors.black.withValues(alpha: 0.78),
    builder: (context) => _ProjectLightboxDialog(projectName: projectName),
  );
}

class _ProjectLightboxDialog extends ConsumerWidget {
  const _ProjectLightboxDialog({required this.projectName});

  final String projectName;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final folio = context.folio;
    final detailAsync = ref.watch(projectDetailProvider(projectName));
    final width = MediaQuery.sizeOf(context).width;
    final isCompact = width < 600;

    return Dialog(
      backgroundColor: folio.canvas,
      surfaceTintColor: Colors.transparent,
      insetPadding: EdgeInsets.all(isCompact ? 12 : 24),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(2),
        side: BorderSide(color: folio.hairline),
      ),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 740, maxHeight: 760),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
              decoration: BoxDecoration(
                border: Border(bottom: BorderSide(color: folio.hairline)),
              ),
              child: Row(
                children: [
                  Text(
                    'FICHA TÉCNICA · REPOSITÓRIO',
                    style: context.monoStyle(size: 11, color: folio.accent),
                  ),
                  const Spacer(),
                  Semantics(
                    button: true,
                    label: 'Fechar ficha técnica',
                    child: IconButton(
                      tooltip: 'Fechar',
                      onPressed: () => Navigator.of(context).pop(),
                      icon: Icon(Icons.close, size: 18, color: folio.ink),
                      style: IconButton.styleFrom(
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(2),
                          side: BorderSide(color: folio.hairline),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Flexible(
              child: SingleChildScrollView(
                padding: EdgeInsets.all(isCompact ? 20 : 32),
                child: AsyncStateView<ProjectDetail>(
                  value: detailAsync,
                  onRetry: () => ref.invalidate(projectDetailProvider(projectName)),
                  builder: (detail) => _LightboxBody(detail: detail),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _LightboxBody extends ConsumerWidget {
  const _LightboxBody({required this.detail});

  final ProjectDetail detail;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final folio = context.folio;
    final totalBytes = detail.languageBytes.values.fold<int>(0, (s, v) => s + v);
    final formattedCommitDate = detail.lastCommit == null
        ? '—'
        : '${detail.lastCommit!.day.toString().padLeft(2, '0')}/'
            '${detail.lastCommit!.month.toString().padLeft(2, '0')}/'
            '${detail.lastCommit!.year}';
    final shortSha = detail.lastCommitSha.length > 7
        ? detail.lastCommitSha.substring(0, 7)
        : (detail.lastCommitSha.isEmpty ? '—' : detail.lastCommitSha);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          detail.name,
          style: context.displayStyle(size: 38, height: 1.04),
        ),
        const SizedBox(height: 14),
        Text(
          detail.description.isNotEmpty
              ? detail.description
              : 'Sem descrição cadastrada no GitHub.',
          style: Theme.of(context).textTheme.bodyLarge?.copyWith(color: folio.inkMuted),
        ),
        const SizedBox(height: 20),
        AspectRatio(
          aspectRatio: 16 / 9,
          child: ProjectPreviewImage(
            projectName: detail.name,
            previewUrl: detail.resolvedPreviewUrl,
            primaryLanguage:
                detail.languages.isNotEmpty ? detail.languages.first : null,
          ),
        ),
        const SizedBox(height: 24),
        Container(
          decoration: BoxDecoration(
            border: Border(
              top: BorderSide(color: folio.hairline),
              bottom: BorderSide(color: folio.hairline),
            ),
          ),
          padding: const EdgeInsets.symmetric(vertical: 14),
          child: Wrap(
            spacing: 28,
            runSpacing: 12,
            children: [
              _SpecCell(label: 'BRANCH', value: detail.defaultBranch),
              _SpecCell(label: 'ESTRELAS', value: '${detail.stars}'),
              _SpecCell(label: 'FORKS', value: '${detail.forks}'),
              _SpecCell(label: 'ÚLTIMO COMMIT', value: '$formattedCommitDate · $shortSha'),
            ],
          ),
        ),
        if (detail.languageBytes.isNotEmpty && totalBytes > 0) ...[
          const SizedBox(height: 24),
          Text(
            'COMPOSIÇÃO DE CÓDIGO',
            style: context.monoStyle(size: 11, color: folio.inkMuted),
          ),
          const SizedBox(height: 10),
          SizedBox(
            height: 8,
            child: Row(
              children: [
                for (var i = 0; i < detail.languageBytes.entries.length; i++)
                  Expanded(
                    flex: detail.languageBytes.entries.elementAt(i).value.clamp(1, totalBytes),
                    child: Container(
                      margin: EdgeInsets.only(right: i == detail.languageBytes.length - 1 ? 0 : 2),
                      color: folio.chartPalette[i % folio.chartPalette.length],
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 16,
            runSpacing: 8,
            children: [
              for (var i = 0; i < detail.languageBytes.entries.length; i++)
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 8,
                      height: 8,
                      color: folio.chartPalette[i % folio.chartPalette.length],
                    ),
                    const SizedBox(width: 6),
                    Text(
                      '${detail.languageBytes.entries.elementAt(i).key} '
                      '${((detail.languageBytes.entries.elementAt(i).value / totalBytes) * 100).toStringAsFixed(1)}%',
                      style: context.monoStyle(size: 11, color: folio.ink),
                    ),
                  ],
                ),
            ],
          ),
        ] else if (detail.languages.isNotEmpty) ...[
          const SizedBox(height: 20),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final lang in detail.languages)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    border: Border.all(color: folio.hairline),
                    borderRadius: BorderRadius.circular(2),
                  ),
                  child: Text(lang, style: context.monoStyle(size: 11, color: folio.ink)),
                ),
            ],
          ),
        ],
        if (detail.lastCommitMessage.isNotEmpty) ...[
          const SizedBox(height: 24),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: folio.surface,
              border: Border.all(color: folio.hairline),
              borderRadius: BorderRadius.circular(2),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'REGISTRO DO ÚLTIMO COMMIT',
                  style: context.monoStyle(size: 10, color: folio.accent),
                ),
                const SizedBox(height: 6),
                Text(
                  detail.lastCommitMessage,
                  style: context.monoStyle(size: 12, color: folio.ink),
                ),
              ],
            ),
          ),
        ],
        const SizedBox(height: 28),
        Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            FilledButton.icon(
              onPressed: () => openExternalUrl(context, detail.url),
              icon: const Icon(Icons.north_east, size: 16),
              label: const Text('Abrir repositório'),
            ),
            if (detail.homepage.isNotEmpty)
              OutlinedButton.icon(
                onPressed: () => openExternalUrl(context, detail.homepage),
                icon: const Icon(Icons.language, size: 16),
                label: const Text('Demo'),
              ),
            OutlinedButton.icon(
              onPressed: () {
                ref.read(contactBriefingContextProvider.notifier).state =
                    'Referência de projeto: ${detail.name}';
                Navigator.of(context).pop();
                ref.read(selectedTabProvider.notifier).state = 4;
              },
              icon: const Icon(Icons.mail_outline, size: 16),
              label: const Text('Solicitar projeto similar'),
            ),
          ],
        ),
      ],
    );
  }
}

class _SpecCell extends StatelessWidget {
  const _SpecCell({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final folio = context.folio;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(label, style: context.monoStyle(size: 10, color: folio.inkMuted)),
        const SizedBox(height: 4),
        Text(value, style: context.monoStyle(size: 12, color: folio.ink)),
      ],
    );
  }
}
