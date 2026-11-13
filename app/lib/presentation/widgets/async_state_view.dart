import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_theme.dart';
import '../../domain/repositories/portfolio_repository.dart';

class AsyncStateView<T> extends StatelessWidget {
  const AsyncStateView({
    super.key,
    required this.value,
    required this.builder,
    required this.onRetry,
    this.isEmpty,
    this.emptyIcon = Icons.inbox_outlined,
    this.emptyTitle = 'Nada por aqui ainda',
    this.emptyMessage = 'Nenhum dado disponível no momento.',
    this.emptyAction,
    this.loadingLabel = 'Carregando dados',
  });

  final AsyncValue<T> value;
  final Widget Function(T data) builder;
  final VoidCallback onRetry;
  final bool Function(T data)? isEmpty;
  final IconData emptyIcon;
  final String emptyTitle;
  final String emptyMessage;
  final Widget? emptyAction;
  final String loadingLabel;

  @override
  Widget build(BuildContext context) {
    final folio = context.folio;

    return value.when(
      loading: () => Center(
        child: Semantics(
          label: loadingLabel,
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                SizedBox(
                  width: 28,
                  height: 28,
                  child: CircularProgressIndicator(
                    strokeWidth: 1.8,
                    color: folio.accent,
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  loadingLabel.toUpperCase(),
                  style: context.monoStyle(size: 11),
                ),
              ],
            ),
          ),
        ),
      ),
      error: (error, _) {
        final message = error is ApiException
            ? error.message
            : 'Não foi possível carregar os dados.';
        final code = error is ApiException ? error.code : 'NETWORK_ERROR';
        return Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 460),
            child: Container(
              margin: const EdgeInsets.all(24),
              padding: const EdgeInsets.all(28),
              decoration: BoxDecoration(
                color: folio.surface,
                border: Border.all(color: folio.hairline),
                borderRadius: BorderRadius.circular(2),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.cloud_off_outlined, size: 22, color: folio.accent),
                      const SizedBox(width: 10),
                      Text(code, style: context.monoStyle(size: 11, color: folio.accent)),
                    ],
                  ),
                  const SizedBox(height: 14),
                  Text('Erro ao carregar', style: context.displayStyle(size: 26)),
                  const SizedBox(height: 8),
                  Text(
                    message,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: folio.inkMuted),
                  ),
                  const SizedBox(height: 20),
                  Semantics(
                    button: true,
                    label: 'Tentar novamente',
                    child: FilledButton.icon(
                      onPressed: onRetry,
                      icon: const Icon(Icons.refresh, size: 17),
                      label: const Text('Tentar novamente'),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
      data: (data) {
        if (isEmpty != null && isEmpty!(data)) {
          return Center(
            child: Container(
              constraints: const BoxConstraints(maxWidth: 460),
              margin: const EdgeInsets.all(24),
              padding: const EdgeInsets.all(28),
              decoration: BoxDecoration(
                border: Border.all(color: folio.hairline),
                borderRadius: BorderRadius.circular(2),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(emptyIcon, size: 30, color: folio.inkMuted),
                  const SizedBox(height: 14),
                  Text(emptyTitle, style: context.displayStyle(size: 26)),
                  const SizedBox(height: 8),
                  Text(
                    emptyMessage,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: folio.inkMuted),
                  ),
                  if (emptyAction != null) ...[
                    const SizedBox(height: 20),
                    emptyAction!,
                  ],
                ],
              ),
            ),
          );
        }
        return builder(data);
      },
    );
  }
}
