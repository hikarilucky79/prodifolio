import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:prodifolio/data/datasources/portfolio_api_client.dart';
import 'package:prodifolio/data/repositories/portfolio_repository_impl.dart';
import 'package:prodifolio/domain/entities/portfolio_entities.dart';
import 'package:prodifolio/domain/repositories/portfolio_repository.dart';

void main() {
  group('PortfolioRepositoryImpl', () {
    test('getProjects decodes owner and projects from API', () async {
      final mockClient = MockClient((request) async {
        expect(request.url.toString(), 'https://api.example.com/projects');
        return http.Response(
          jsonEncode({
            'owner': {
              'username': 'hikarilucky79',
              'name': 'Hikari',
              'bio': 'Dev Go & Flutter',
              'avatar_url': '',
              'profile_url': 'https://github.com/hikarilucky79',
              'blog_url': 'https://hikari.dev',
            },
            'projects': [
              {
                'name': 'prodifolio',
                'description': 'Portfolio dinamico',
                'languages': ['Go', 'Dart'],
                'stars': 12,
                'last_commit': '2026-11-12T10:00:00Z',
                'url': 'https://github.com/hikarilucky79/prodifolio',
              },
            ],
          }),
          200,
        );
      });

      final repo = PortfolioRepositoryImpl(
        PortfolioApiClient(baseUrl: 'https://api.example.com/', client: mockClient),
      );

      final feed = await repo.getProjects();
      expect(feed.owner.username, 'hikarilucky79');
      expect(feed.projects, hasLength(1));
      expect(feed.projects.first.name, 'prodifolio');
      expect(feed.projects.first.languages, ['Go', 'Dart']);
      expect(feed.projects.first.stars, 12);
    });

    test('getStats decodes languages and recent activity', () async {
      final mockClient = MockClient((request) async {
        expect(request.url.path, '/stats');
        return http.Response(
          jsonEncode({
            'total_projects': 5,
            'total_stars': 20,
            'languages': [
              {'name': 'Go', 'count': 3, 'percentage': 60.0},
              {'name': 'Dart', 'count': 2, 'percentage': 40.0},
            ],
            'activity': [
              {'date': '2026-11-11', 'commits': 4},
              {'date': '2026-11-12', 'commits': 2},
            ],
          }),
          200,
        );
      });

      final repo = PortfolioRepositoryImpl(
        PortfolioApiClient(baseUrl: 'https://api.example.com', client: mockClient),
      );

      final stats = await repo.getStats();
      expect(stats.totalProjects, 5);
      expect(stats.languages.first.name, 'Go');
      expect(stats.activity.last.commits, 2);
    });

    test('submitContact parses 422 structured API validation errors', () async {
      final mockClient = MockClient((request) async {
        expect(request.method, 'POST');
        return http.Response(
          jsonEncode({
            'error': {
              'code': 'VALIDATION_ERROR',
              'message': 'invalid contact input',
              'fields': {'email': 'must be a valid email address'},
            },
          }),
          422,
        );
      });

      final repo = PortfolioRepositoryImpl(
        PortfolioApiClient(baseUrl: 'https://api.example.com', client: mockClient),
      );

      expect(
        () => repo.submitContact(
          const ContactSubmission(
            name: 'Hikari',
            email: 'bad@invalid',
            message: 'Mensagem longa o suficiente.',
          ),
        ),
        throwsA(
          isA<ApiException>()
              .having((e) => e.statusCode, 'statusCode', 422)
              .having((e) => e.code, 'code', 'VALIDATION_ERROR')
              .having((e) => e.fieldErrors['email'], 'email error', 'must be a valid email address'),
        ),
      );
    });

    test('throws MISSING_CONFIG when API base url is empty', () async {
      final repo = PortfolioRepositoryImpl(
        PortfolioApiClient(
          baseUrl: '',
          client: MockClient((_) async => http.Response('{}', 200)),
        ),
      );

      expect(
        repo.getProjects,
        throwsA(isA<ApiException>().having((e) => e.code, 'code', 'MISSING_CONFIG')),
      );
    });
  });
}
