import '../../domain/entities/portfolio_entities.dart';
import '../../domain/repositories/portfolio_repository.dart';
import '../datasources/portfolio_api_client.dart';

class PortfolioRepositoryImpl implements PortfolioRepository {
  const PortfolioRepositoryImpl(this._apiClient);

  final PortfolioApiClient _apiClient;

  @override
  Future<ProjectsFeed> getProjects() async {
    final json = await _apiClient.getJson('/projects');
    final ownerJson = Map<String, dynamic>.from(
      (json['owner'] as Map?) ?? const <String, dynamic>{},
    );
    final rawProjects = (json['projects'] as List?) ?? const [];

    return ProjectsFeed(
      owner: OwnerProfile(
        username: ownerJson['username']?.toString() ?? '',
        name: ownerJson['name']?.toString() ?? '',
        bio: ownerJson['bio']?.toString() ?? '',
        avatarUrl: ownerJson['avatar_url']?.toString() ?? '',
        profileUrl: ownerJson['profile_url']?.toString() ?? '',
        blogUrl: ownerJson['blog_url']?.toString() ?? '',
      ),
      projects: rawProjects.map((item) {
        final map = Map<String, dynamic>.from(item as Map);
        final langs = ((map['languages'] as List?) ?? const [])
            .map((e) => e.toString())
            .where((e) => e.isNotEmpty)
            .toList(growable: false);
        return Project(
          name: map['name']?.toString() ?? '',
          description: map['description']?.toString() ?? '',
          languages: langs,
          stars: (map['stars'] as num?)?.toInt() ?? 0,
          lastCommit: _tryParseDate(map['last_commit']),
          url: map['url']?.toString() ?? '',
          previewUrl: map['preview_url']?.toString(),
        );
      }).toList(growable: false),
    );
  }

  @override
  Future<ProjectDetail> getProjectDetail(String name) async {
    final encoded = Uri.encodeComponent(name);
    final json = await _apiClient.getJson('/projects/$encoded');
    final rawLangBytes = (json['language_bytes'] as Map?) ?? const {};
    return ProjectDetail(
      name: json['name']?.toString() ?? name,
      description: json['description']?.toString() ?? '',
      languages: ((json['languages'] as List?) ?? const [])
          .map((e) => e.toString())
          .toList(growable: false),
      languageBytes: rawLangBytes.map(
        (k, v) => MapEntry(k.toString(), (v as num).toInt()),
      ),
      stars: (json['stars'] as num?)?.toInt() ?? 0,
      forks: (json['forks'] as num?)?.toInt() ?? 0,
      defaultBranch: json['default_branch']?.toString() ?? 'main',
      lastCommit: _tryParseDate(json['last_commit']),
      lastCommitMessage: json['last_commit_message']?.toString() ?? '',
      lastCommitSha: json['last_commit_sha']?.toString() ?? '',
      url: json['url']?.toString() ?? '',
      homepage: json['homepage']?.toString() ?? '',
      previewUrl: json['preview_url']?.toString(),
    );
  }

  @override
  Future<PortfolioStats> getStats() async {
    final json = await _apiClient.getJson('/stats');
    final rawLangs = (json['languages'] as List?) ?? const [];
    final rawActivity = (json['activity'] as List?) ?? const [];

    return PortfolioStats(
      totalProjects: (json['total_projects'] as num?)?.toInt() ?? 0,
      totalStars: (json['total_stars'] as num?)?.toInt() ?? 0,
      languages: rawLangs.map((item) {
        final map = Map<String, dynamic>.from(item as Map);
        return LanguageStat(
          name: map['name']?.toString() ?? '',
          count: (map['count'] as num?)?.toInt() ?? 0,
          percentage: (map['percentage'] as num?)?.toDouble() ?? 0,
        );
      }).toList(growable: false),
      activity: rawActivity.map((item) {
        final map = Map<String, dynamic>.from(item as Map);
        return ActivityPoint(
          date: map['date']?.toString() ?? '',
          commits: (map['commits'] as num?)?.toInt() ?? 0,
        );
      }).toList(growable: false),
    );
  }

  @override
  Future<ContactReceipt> submitContact(ContactSubmission submission) async {
    final json = await _apiClient.postJson('/contact', {
      'name': submission.name,
      'email': submission.email,
      'message': submission.message,
    });
    return ContactReceipt(
      id: json['id']?.toString() ?? '',
      status: json['status']?.toString() ?? 'received',
      createdAt: _tryParseDate(json['created_at']) ?? DateTime.now().toUtc(),
    );
  }

  DateTime? _tryParseDate(Object? value) {
    if (value == null) return null;
    return DateTime.tryParse(value.toString())?.toLocal();
  }
}
