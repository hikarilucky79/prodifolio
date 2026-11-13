import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_theme.dart';
import '../../domain/entities/portfolio_entities.dart';
import '../../domain/repositories/portfolio_repository.dart';
import '../providers/portfolio_providers.dart';

class ContactScreen extends ConsumerStatefulWidget {
  const ContactScreen({super.key});

  @override
  ConsumerState<ContactScreen> createState() => _ContactScreenState();
}

class _ContactScreenState extends ConsumerState<ContactScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _messageController = TextEditingController();

  static final _emailRegex = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');
  static const _scopes = <String>[
    'Backend Go / API',
    'App Flutter Web & Mobile',
    'Full-Stack / Consultoria',
    'Oportunidade CLT / Remota',
  ];

  String? _selectedScope;

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _messageController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    final rawMessage = _messageController.text.trim();
    final refContext = ref.read(contactBriefingContextProvider);
    final tags = <String>[
      if (_selectedScope != null) 'Escopo: $_selectedScope',
      if (refContext != null && refContext.isNotEmpty) refContext,
    ];
    final payloadMessage = tags.isEmpty ? rawMessage : '[${tags.join(' | ')}]\n$rawMessage';

    await ref.read(contactSubmitProvider.notifier).submit(
          ContactSubmission(
            name: _nameController.text.trim(),
            email: _emailController.text.trim(),
            message: payloadMessage,
          ),
        );
  }

  void _resetForm() {
    _nameController.clear();
    _emailController.clear();
    _messageController.clear();
    setState(() => _selectedScope = null);
    ref.read(contactBriefingContextProvider.notifier).state = null;
    ref.read(contactSubmitProvider.notifier).reset();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(contactSubmitProvider);
    final briefingRef = ref.watch(contactBriefingContextProvider);
    final folio = context.folio;
    final receipt = state.valueOrNull;

    if (receipt != null) {
      return Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 540),
          child: Container(
            margin: const EdgeInsets.all(24),
            padding: const EdgeInsets.all(32),
            decoration: BoxDecoration(
              color: folio.contrastSurface,
              border: Border.all(color: folio.contrastHairline),
              borderRadius: BorderRadius.circular(2),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.check, size: 22, color: folio.contrastAccent),
                    const SizedBox(width: 10),
                    Text(
                      'PROTOCOLO REGISTRADO',
                      style: context.monoStyle(size: 11, color: folio.contrastAccent),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Text(
                  'Mensagem enviada!',
                  style: context.displayStyle(
                    size: 32,
                    color: folio.contrastInk,
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  'Obrigado pelo contato. Protocolo: ${receipt.id}',
                  style: context.monoStyle(size: 12, color: folio.contrastMuted),
                ),
                const SizedBox(height: 24),
                Semantics(
                  button: true,
                  label: 'Enviar outra mensagem',
                  child: FilledButton(
                    style: FilledButton.styleFrom(
                      backgroundColor: folio.contrastInk,
                      foregroundColor: folio.contrastSurface,
                    ),
                    onPressed: _resetForm,
                    child: const Text('Enviar outra mensagem'),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    final apiError = state.error is ApiException ? state.error as ApiException : null;
    final errorMessage = state.hasError
        ? (apiError?.message ?? 'Erro inesperado ao enviar mensagem.')
        : null;

    return LayoutBuilder(
      builder: (context, constraints) {
        final isWide = constraints.maxWidth >= 760;
        final isSpacious = constraints.maxWidth >= 900;
        final padH = isSpacious ? 40.0 : 20.0;

        final briefingPlate = Container(
          padding: EdgeInsets.all(isSpacious ? 32 : 22),
          decoration: BoxDecoration(
            color: folio.contrastSurface,
            border: Border.all(color: folio.contrastHairline),
            borderRadius: BorderRadius.circular(2),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Fale comigo',
                style: context.displayStyle(
                  size: isWide ? 40 : 32,
                  color: folio.contrastInk,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                'Envie uma mensagem para conversar sobre projetos ou oportunidades.',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: folio.contrastMuted,
                    ),
              ),
              const SizedBox(height: 24),
              Text(
                'ESCOPO DO BRIEFING (OPCIONAL)',
                style: context.monoStyle(size: 10, color: folio.contrastMuted),
              ),
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final scope in _scopes)
                    Semantics(
                      button: true,
                      selected: _selectedScope == scope,
                      label: 'Selecionar escopo $scope',
                      child: InkWell(
                        onTap: () {
                          setState(() {
                            _selectedScope = _selectedScope == scope ? null : scope;
                          });
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 8,
                          ),
                          decoration: BoxDecoration(
                            color: _selectedScope == scope
                                ? folio.contrastInk
                                : Colors.transparent,
                            border: Border.all(
                              color: _selectedScope == scope
                                  ? folio.contrastInk
                                  : folio.contrastHairline,
                            ),
                            borderRadius: BorderRadius.circular(2),
                          ),
                          child: Text(
                            scope,
                            style: TextStyle(
                              fontFamily: 'JetBrainsMono',
                              fontSize: 11,
                              color: _selectedScope == scope
                                  ? folio.contrastSurface
                                  : folio.contrastInk,
                            ),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
              if (briefingRef != null && briefingRef.isNotEmpty) ...[
                const SizedBox(height: 18),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  decoration: BoxDecoration(
                    border: Border.all(color: folio.accent),
                    borderRadius: BorderRadius.circular(2),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          briefingRef,
                          style: context.monoStyle(size: 11, color: folio.contrastInk),
                        ),
                      ),
                      IconButton(
                        tooltip: 'Remover referência',
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                        icon: Icon(Icons.close, size: 16, color: folio.contrastInk),
                        onPressed: () {
                          ref.read(contactBriefingContextProvider.notifier).state = null;
                        },
                      ),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: 24),
              Container(
                padding: const EdgeInsets.only(top: 14),
                decoration: BoxDecoration(
                  border: Border(top: BorderSide(color: folio.contrastHairline)),
                ),
                child: Text(
                  'ENVIO DIRETO E VALIDADO VIA API REST',
                  style: context.monoStyle(size: 10, color: folio.contrastMuted),
                ),
              ),
            ],
          ),
        );

        final formCard = Container(
          padding: EdgeInsets.all(isSpacious ? 32 : 22),
          decoration: BoxDecoration(
            color: folio.surface,
            border: Border.all(color: folio.hairline),
            borderRadius: BorderRadius.circular(2),
          ),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (errorMessage != null) ...[
                  Semantics(
                    liveRegion: true,
                    child: Container(
                      padding: const EdgeInsets.all(14),
                      margin: const EdgeInsets.only(bottom: 18),
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.errorContainer,
                        border: Border.all(color: Theme.of(context).colorScheme.error),
                        borderRadius: BorderRadius.circular(2),
                      ),
                      child: Text(
                        errorMessage,
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.onErrorContainer,
                        ),
                      ),
                    ),
                  ),
                ],
                Semantics(
                  textField: true,
                  label: 'Nome',
                  child: TextFormField(
                    controller: _nameController,
                    enabled: !state.isLoading,
                    textInputAction: TextInputAction.next,
                    decoration: InputDecoration(
                      labelText: 'Nome',
                      errorText: apiError?.fieldErrors['name'],
                    ),
                    validator: (value) {
                      final trimmed = value?.trim() ?? '';
                      if (trimmed.length < 2 || trimmed.length > 100) {
                        return 'Informe seu nome (2 a 100 caracteres)';
                      }
                      return null;
                    },
                  ),
                ),
                const SizedBox(height: 16),
                Semantics(
                  textField: true,
                  label: 'E-mail',
                  child: TextFormField(
                    controller: _emailController,
                    enabled: !state.isLoading,
                    keyboardType: TextInputType.emailAddress,
                    textInputAction: TextInputAction.next,
                    decoration: InputDecoration(
                      labelText: 'E-mail',
                      errorText: apiError?.fieldErrors['email'],
                    ),
                    validator: (value) {
                      final trimmed = value?.trim() ?? '';
                      if (trimmed.isEmpty || !_emailRegex.hasMatch(trimmed)) {
                        return 'Informe um e-mail válido';
                      }
                      return null;
                    },
                  ),
                ),
                const SizedBox(height: 16),
                Semantics(
                  textField: true,
                  label: 'Mensagem',
                  child: TextFormField(
                    controller: _messageController,
                    enabled: !state.isLoading,
                    minLines: 4,
                    maxLines: 6,
                    decoration: InputDecoration(
                      labelText: 'Mensagem',
                      alignLabelWithHint: true,
                      errorText: apiError?.fieldErrors['message'],
                    ),
                    validator: (value) {
                      final trimmed = value?.trim() ?? '';
                      if (trimmed.length < 10 || trimmed.length > 2000) {
                        return 'A mensagem deve ter entre 10 e 2000 caracteres';
                      }
                      return null;
                    },
                  ),
                ),
                const SizedBox(height: 22),
                Semantics(
                  button: true,
                  label: 'Enviar mensagem de contato',
                  child: FilledButton.icon(
                    onPressed: state.isLoading ? null : _submit,
                    icon: state.isLoading
                        ? SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: folio.contrastInk,
                            ),
                          )
                        : const Icon(Icons.north_east, size: 16),
                    label: Text(state.isLoading ? 'Enviando...' : 'Enviar mensagem'),
                  ),
                ),
              ],
            ),
          ),
        );

        return ListView(
          padding: EdgeInsets.fromLTRB(padH, isWide ? 28 : 20, padH, 36),
          children: [
            if (isWide)
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(flex: 5, child: briefingPlate),
                  const SizedBox(width: 24),
                  Expanded(flex: 6, child: formCard),
                ],
              )
            else ...[
              briefingPlate,
              const SizedBox(height: 20),
              formCard,
            ],
          ],
        );
      },
    );
  }
}
