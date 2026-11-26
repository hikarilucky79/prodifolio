import 'package:material_ui/material_ui.dart';

import '../../core/theme/app_theme.dart';

class ProjectPreviewImage extends StatelessWidget {
  const ProjectPreviewImage({
    super.key,
    required this.projectName,
    required this.previewUrl,
    this.primaryLanguage,
    this.compact = false,
  });

  final String projectName;
  final String? previewUrl;
  final String? primaryLanguage;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final folio = context.folio;
    final url = previewUrl?.trim() ?? '';

    return Semantics(
      image: true,
      label: 'Preview do projeto $projectName',
      child: Container(
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          color: folio.surface,
          border: Border.all(color: folio.hairline),
          borderRadius: BorderRadius.circular(2),
        ),
        child: url.isEmpty
            ? _PreviewFallback(
                projectName: projectName,
                primaryLanguage: primaryLanguage,
                compact: compact,
              )
            : Image.network(
                url,
                fit: BoxFit.cover,
                width: double.infinity,
                height: double.infinity,
                loadingBuilder: (context, child, loadingProgress) {
                  if (loadingProgress == null) return child;
                  return Container(
                    color: folio.surfaceAlt,
                    alignment: Alignment.center,
                    child: SizedBox(
                      width: compact ? 16 : 22,
                      height: compact ? 16 : 22,
                      child: CircularProgressIndicator(
                        strokeWidth: 1.8,
                        color: folio.accent,
                      ),
                    ),
                  );
                },
                errorBuilder: (context, error, stackTrace) => _PreviewFallback(
                  projectName: projectName,
                  primaryLanguage: primaryLanguage,
                  compact: compact,
                ),
              ),
      ),
    );
  }
}

class _PreviewFallback extends StatelessWidget {
  const _PreviewFallback({
    required this.projectName,
    required this.primaryLanguage,
    required this.compact,
  });

  final String projectName;
  final String? primaryLanguage;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final folio = context.folio;
    final lang = (primaryLanguage ?? '').trim();

    return Container(
      width: double.infinity,
      height: double.infinity,
      padding: EdgeInsets.all(compact ? 10 : 18),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [folio.surface, folio.surfaceAlt],
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Icon(
                Icons.code_rounded,
                size: compact ? 14 : 18,
                color: folio.accent,
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  lang.isNotEmpty ? lang.toUpperCase() : 'REPOSITÓRIO',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: context.monoStyle(
                    size: compact ? 9 : 11,
                    color: folio.inkMuted,
                  ),
                ),
              ),
            ],
          ),
          Text(
            projectName,
            maxLines: compact ? 2 : 2,
            overflow: TextOverflow.ellipsis,
            style: context.displayStyle(
              size: compact ? 15 : 22,
              height: 1.1,
              color: folio.ink,
            ),
          ),
        ],
      ),
    );
  }
}
