import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:prodifolio/domain/entities/portfolio_entities.dart';
import 'package:prodifolio/domain/repositories/portfolio_repository.dart';
import 'package:prodifolio/presentation/providers/portfolio_providers.dart';
import 'package:prodifolio/presentation/screens/about_screen.dart';
import 'package:prodifolio/presentation/screens/contact_screen.dart';
import 'package:prodifolio/presentation/screens/home_screen.dart';
import 'package:prodifolio/presentation/screens/projects_screen.dart';
import 'package:prodifolio/presentation/screens/stats_screen.dart';

class FakePortfolioRepository implements PortfolioRepository {
  FakePortfolioRepository({this.failStats = false});

  final bool failStats;
  int submitCalls = 0;

  @override
  Future<ProjectsFeed> getProjects() async {
    return ProjectsFeed(
      owner: const OwnerProfile(
        username: 'hikarilucky79',
        name: 'Hikari',
        bio: 'Apaixonado por codigo',
        avatarUrl: '',
        profileUrl: 'https://github.com/hikarilucky79',
        blogUrl: 'https://hikari.dev',
      ),
      projects: [
        Project(
          name: 'KaorCount',
          description: 'Contador em JavaScript',
          languages: const ['JavaScript'],
          stars: 2,
          lastCommit: DateTime(2026, 11, 10),
          url: 'https://github.com/hikarilucky79/KaorCount',
        ),
        Project(
          name: 'prodifolio-api',
          description: 'Backend em Go com TiDB Cloud',
          languages: const ['Go'],
          stars: 8,
          lastCommit: DateTime(2026, 11, 12),
          url: 'https://github.com/hikarilucky79/prodifolio-api',
        ),
      ],
    );
  }

  @override
  Future<ProjectDetail> getProjectDetail(String name) async {
    return ProjectDetail(
      name: name,
      description: 'Detalhes do projeto $name',
      languages: const ['Go'],
      languageBytes: const {'Go': 12000},
      stars: 8,
      forks: 1,
      defaultBranch: 'main',
      lastCommit: DateTime(2026, 11, 12),
      lastCommitMessage: 'feat: initial release',
      lastCommitSha: 'abc123',
      url: 'https://github.com/hikarilucky79/$name',
      homepage: '',
    );
  }

  @override
  Future<PortfolioStats> getStats() async {
    if (failStats) {
      throw const ApiException(
        statusCode: 503,
        code: 'UPSTREAM_ERROR',
        message: 'GitHub indisponivel no momento',
      );
    }
    return const PortfolioStats(
      totalProjects: 2,
      totalStars: 10,
      languages: [
        LanguageStat(name: 'Go', count: 1, percentage: 50),
        LanguageStat(name: 'JavaScript', count: 1, percentage: 50),
      ],
      activity: [
        ActivityPoint(date: '2026-11-11', commits: 2),
        ActivityPoint(date: '2026-11-12', commits: 4),
      ],
    );
  }

  @override
  Future<ContactReceipt> submitContact(ContactSubmission submission) async {
    submitCalls++;
    return ContactReceipt(
      id: 'rec-123',
      status: 'received',
      createdAt: DateTime(2026, 11, 12),
    );
  }
}

void main() {
  testWidgets('ProjectsScreen filters projects by language chip and search', (tester) async {
    final fakeRepo = FakePortfolioRepository();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          portfolioRepositoryProvider.overrideWithValue(fakeRepo),
        ],
        child: const MaterialApp(home: Scaffold(body: ProjectsScreen())),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('KaorCount'), findsWidgets);
    expect(find.text('prodifolio-api'), findsWidgets);

    await tester.tap(find.widgetWithText(FilterChip, 'Go'));
    await tester.pumpAndSettle();

    expect(find.text('prodifolio-api'), findsWidgets);
    expect(find.text('KaorCount'), findsNothing);

    await tester.enterText(find.byType(TextField), 'inexistente');
    await tester.pumpAndSettle();

    expect(find.text('Nenhum projeto encontrado'), findsOneWidget);
    await tester.tap(find.text('Limpar filtros'));
    await tester.pumpAndSettle();

    expect(find.text('KaorCount'), findsWidgets);
    expect(find.text('prodifolio-api'), findsWidgets);
  });

  testWidgets('ContactScreen validates invalid fields before calling repository', (tester) async {
    final fakeRepo = FakePortfolioRepository();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          portfolioRepositoryProvider.overrideWithValue(fakeRepo),
        ],
        child: const MaterialApp(home: Scaffold(body: ContactScreen())),
      ),
    );
    await tester.pumpAndSettle();

    await tester.enterText(find.widgetWithText(TextFormField, 'Nome'), 'H');
    await tester.enterText(find.widgetWithText(TextFormField, 'E-mail'), 'email-invalido');
    await tester.enterText(find.widgetWithText(TextFormField, 'Mensagem'), 'Oi');

    await tester.tap(find.text('Enviar mensagem'));
    await tester.pumpAndSettle();

    expect(find.text('Informe seu nome (2 a 100 caracteres)'), findsOneWidget);
    expect(find.text('Informe um e-mail válido'), findsOneWidget);
    expect(find.text('A mensagem deve ter entre 10 e 2000 caracteres'), findsOneWidget);
    expect(fakeRepo.submitCalls, 0);

    await tester.enterText(find.widgetWithText(TextFormField, 'Nome'), 'Hikari');
    await tester.enterText(find.widgetWithText(TextFormField, 'E-mail'), 'hikari@example.com');
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Mensagem'),
      'Ola! Gostaria de conversar sobre um projeto em Go e Flutter.',
    );

    await tester.tap(find.text('Enviar mensagem'));
    await tester.pumpAndSettle();

    expect(fakeRepo.submitCalls, 1);
    expect(find.text('Mensagem enviada!'), findsOneWidget);
  });

  testWidgets('StatsScreen renders CustomPainter charts and handles API errors', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          portfolioRepositoryProvider.overrideWithValue(FakePortfolioRepository()),
        ],
        child: const MaterialApp(home: Scaffold(body: StatsScreen())),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Linguagens mais usadas'), findsOneWidget);
    expect(find.text('Atividade recente de commits'), findsOneWidget);
    expect(find.text('1 repo · 50.0%'), findsNWidgets(2));
    expect(find.byType(CustomPaint), findsAtLeastNWidgets(2));

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          portfolioRepositoryProvider.overrideWithValue(FakePortfolioRepository(failStats: true)),
        ],
        child: const MaterialApp(home: Scaffold(body: StatsScreen())),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('GitHub indisponivel no momento'), findsOneWidget);
    expect(find.text('Tentar novamente'), findsOneWidget);
  });

  testWidgets('HomeScreen shows profile, social buttons, and resume modal', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          portfolioRepositoryProvider.overrideWithValue(FakePortfolioRepository()),
        ],
        child: const MaterialApp(home: Scaffold(body: HomeScreen())),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Kauã Oliveira'), findsOneWidget);
    expect(find.text('@hikarilucky79'), findsOneWidget);
    expect(find.text('Currículo'), findsOneWidget);
    expect(find.text('LinkedIn'), findsOneWidget);
    expect(find.text('Contato'), findsOneWidget);
    expect(find.text('Website'), findsNothing);

    await tester.tap(find.text('Currículo'));
    await tester.pumpAndSettle();
    expect(find.text('Currículo · Kauã Oliveira'), findsOneWidget);
    expect(find.text('Baixar PDF'), findsOneWidget);
  });

  testWidgets('AboutScreen renders animated timeline milestones', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          portfolioRepositoryProvider.overrideWithValue(FakePortfolioRepository()),
        ],
        child: const MaterialApp(home: Scaffold(body: AboutScreen())),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Sobre & Trajetória'), findsOneWidget);
    expect(find.text('Prodifolio & Engenharia Full-Stack'), findsOneWidget);
    expect(find.text('Formação Técnica · CEEP Curitiba'), findsOneWidget);
  });

  testWidgets('ProjectsScreen opens technical lightbox and sets briefing context', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          portfolioRepositoryProvider.overrideWithValue(FakePortfolioRepository()),
        ],
        child: const MaterialApp(home: Scaffold(body: ProjectsScreen())),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Ficha').first);
    await tester.pumpAndSettle();

    expect(find.text('FICHA TÉCNICA · REPOSITÓRIO'), findsOneWidget);
    expect(find.text('BRANCH'), findsOneWidget);
    expect(find.text('Solicitar projeto similar'), findsOneWidget);

    await tester.ensureVisible(find.text('Solicitar projeto similar'));
    await tester.tap(find.text('Solicitar projeto similar'));
    await tester.pumpAndSettle();

    expect(find.text('FICHA TÉCNICA · REPOSITÓRIO'), findsNothing);
  });

  testWidgets('ContactScreen prefixes submitted message with selected scope tag', (
    tester,
  ) async {
    final repo = _CapturingPortfolioRepository();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          portfolioRepositoryProvider.overrideWithValue(repo),
        ],
        child: const MaterialApp(home: Scaffold(body: ContactScreen())),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Backend Go / API'));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextFormField).at(0), 'Hikari Tester');
    await tester.enterText(find.byType(TextFormField).at(1), 'hikari@example.com');
    await tester.enterText(
      find.byType(TextFormField).at(2),
      'Precisamos estruturar uma API REST em Go com alta disponibilidade.',
    );

    await tester.ensureVisible(find.text('Enviar mensagem'));
    await tester.tap(find.text('Enviar mensagem'));
    await tester.pumpAndSettle();

    expect(find.text('Mensagem enviada!'), findsOneWidget);
    expect(repo.lastSubmission, isNotNull);
    expect(repo.lastSubmission!.message, startsWith('[Escopo: Backend Go / API]'));
  });
}

class _CapturingPortfolioRepository extends FakePortfolioRepository {
  ContactSubmission? lastSubmission;

  @override
  Future<ContactReceipt> submitContact(ContactSubmission submission) {
    lastSubmission = submission;
    return super.submitContact(submission);
  }
}
