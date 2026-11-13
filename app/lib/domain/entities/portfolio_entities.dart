class OwnerProfile {
  const OwnerProfile({
    required this.username,
    required this.name,
    required this.bio,
    required this.avatarUrl,
    required this.profileUrl,
    required this.blogUrl,
  });

  final String username;
  final String name;
  final String bio;
  final String avatarUrl;
  final String profileUrl;
  final String blogUrl;
}

class Project {
  const Project({
    required this.name,
    required this.description,
    required this.languages,
    required this.stars,
    required this.lastCommit,
    required this.url,
  });

  final String name;
  final String description;
  final List<String> languages;
  final int stars;
  final DateTime? lastCommit;
  final String url;
}

class ProjectsFeed {
  const ProjectsFeed({
    required this.owner,
    required this.projects,
  });

  final OwnerProfile owner;
  final List<Project> projects;
}

class ProjectDetail {
  const ProjectDetail({
    required this.name,
    required this.description,
    required this.languages,
    required this.languageBytes,
    required this.stars,
    required this.forks,
    required this.defaultBranch,
    required this.lastCommit,
    required this.lastCommitMessage,
    required this.lastCommitSha,
    required this.url,
    required this.homepage,
  });

  final String name;
  final String description;
  final List<String> languages;
  final Map<String, int> languageBytes;
  final int stars;
  final int forks;
  final String defaultBranch;
  final DateTime? lastCommit;
  final String lastCommitMessage;
  final String lastCommitSha;
  final String url;
  final String homepage;
}

class LanguageStat {
  const LanguageStat({
    required this.name,
    required this.count,
    required this.percentage,
  });

  final String name;
  final int count;
  final double percentage;
}

class ActivityPoint {
  const ActivityPoint({
    required this.date,
    required this.commits,
  });

  final String date;
  final int commits;
}

class PortfolioStats {
  const PortfolioStats({
    required this.totalProjects,
    required this.totalStars,
    required this.languages,
    required this.activity,
  });

  final int totalProjects;
  final int totalStars;
  final List<LanguageStat> languages;
  final List<ActivityPoint> activity;
}

class ContactSubmission {
  const ContactSubmission({
    required this.name,
    required this.email,
    required this.message,
  });

  final String name;
  final String email;
  final String message;
}

class ContactReceipt {
  const ContactReceipt({
    required this.id,
    required this.status,
    required this.createdAt,
  });

  final String id;
  final String status;
  final DateTime createdAt;
}

class TimelineMilestone {
  const TimelineMilestone({
    required this.period,
    required this.title,
    required this.subtitle,
    required this.highlights,
  });

  final String period;
  final String title;
  final String subtitle;
  final List<String> highlights;
}
