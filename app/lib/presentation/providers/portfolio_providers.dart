import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;

import '../../core/config/app_config.dart';
import '../../data/datasources/portfolio_api_client.dart';
import '../../data/repositories/portfolio_repository_impl.dart';
import '../../domain/entities/portfolio_entities.dart';
import '../../domain/repositories/portfolio_repository.dart';

final httpClientProvider = Provider<http.Client>((ref) {
  final client = http.Client();
  ref.onDispose(client.close);
  return client;
});

final apiBaseUrlProvider = Provider<String>((ref) => AppConfig.apiBaseUrl);

final portfolioRepositoryProvider = Provider<PortfolioRepository>((ref) {
  final apiClient = PortfolioApiClient(
    baseUrl: ref.watch(apiBaseUrlProvider),
    client: ref.watch(httpClientProvider),
  );
  return PortfolioRepositoryImpl(apiClient);
});

final themeModeProvider = StateProvider<ThemeMode>((ref) => ThemeMode.dark);
final selectedTabProvider = StateProvider<int>((ref) => 0);
final contactBriefingContextProvider = StateProvider<String?>((ref) => null);

final projectsFeedProvider = FutureProvider<ProjectsFeed>((ref) {
  return ref.watch(portfolioRepositoryProvider).getProjects();
});

final projectDetailProvider = FutureProvider.family<ProjectDetail, String>((ref, name) {
  return ref.watch(portfolioRepositoryProvider).getProjectDetail(name);
});

final projectSearchQueryProvider = StateProvider<String>((ref) => '');
final selectedLanguageProvider = StateProvider<String?>((ref) => null);

final availableLanguagesProvider = Provider<List<String>>((ref) {
  final feed = ref.watch(projectsFeedProvider).valueOrNull;
  if (feed == null) return const [];
  final set = <String>{};
  for (final project in feed.projects) {
    set.addAll(project.languages);
  }
  final list = set.toList()..sort();
  return list;
});

final filteredProjectsProvider = Provider<AsyncValue<List<Project>>>((ref) {
  final feedAsync = ref.watch(projectsFeedProvider);
  final query = ref.watch(projectSearchQueryProvider).trim().toLowerCase();
  final language = ref.watch(selectedLanguageProvider);

  return feedAsync.whenData((feed) {
    return feed.projects.where((project) {
      final matchesLang = language == null || project.languages.contains(language);
      if (!matchesLang) return false;
      if (query.isEmpty) return true;
      return project.name.toLowerCase().contains(query) ||
          project.description.toLowerCase().contains(query) ||
          project.languages.any((l) => l.toLowerCase().contains(query));
    }).toList(growable: false);
  });
});

final statsProvider = FutureProvider<PortfolioStats>((ref) {
  return ref.watch(portfolioRepositoryProvider).getStats();
});

final aboutTimelineProvider = FutureProvider<List<TimelineMilestone>>((ref) async {
  final feed = await ref.watch(projectsFeedProvider.future);
  final langs = feed.projects.expand((p) => p.languages).toSet().toList()..sort();
  final topStack = langs.isEmpty ? 'Go, Flutter & Web' : langs.take(5).join(', ');
  final repoCount = feed.projects.length;

  return [
    TimelineMilestone(
      period: '2026 · Atual',
      title: 'Prodifolio & Engenharia Full-Stack',
      subtitle: '${feed.owner.name} (@${feed.owner.username})',
      highlights: [
        '$repoCount repositórios públicos sincronizados direto do GitHub',
        'Stack ativa: $topStack',
      ],
    ),
    const TimelineMilestone(
      period: '2026 · Backend & Dados',
      title: 'APIs resilientes em Go + PostgreSQL/Supabase',
      subtitle: 'Arquitetura limpa e modelagem relacional',
      highlights: [
        'Cache TTL em memória, rate limiting por IP e logs estruturados',
        'Banco normalizado até 3FN com transações atômicas e RLS',
      ],
    ),
    const TimelineMilestone(
      period: '2026 · Interfaces',
      title: 'Apps multiplataforma com Flutter Material 3',
      subtitle: 'UI elegante, responsiva e acessível',
      highlights: [
        'Layouts adaptativos para celular, tablet e desktop',
        'Visualizações autorais desenhadas em CustomPainter',
      ],
    ),
  ];
});

class ContactSubmitNotifier extends StateNotifier<AsyncValue<ContactReceipt?>> {
  ContactSubmitNotifier(this._repo) : super(const AsyncData(null));

  final PortfolioRepository _repo;

  Future<void> submit(ContactSubmission submission) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() => _repo.submitContact(submission));
  }

  void reset() {
    state = const AsyncData(null);
  }
}

final contactSubmitProvider =
    StateNotifierProvider<ContactSubmitNotifier, AsyncValue<ContactReceipt?>>((ref) {
  return ContactSubmitNotifier(ref.watch(portfolioRepositoryProvider));
});
