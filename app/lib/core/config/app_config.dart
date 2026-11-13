class AppConfig {
  const AppConfig._();

  static const String apiBaseUrl = String.fromEnvironment('API_BASE_URL');
  static const String resumeUrl = String.fromEnvironment('RESUME_URL');
  static const String linkedInUrl =
      'https://www.linkedin.com/in/kau%C3%A3-oliveira-43b07b268/';
  static const String defaultPublicResumeUrl =
      'https://dev-hikari.vercel.app/curriculo.pdf';

  static bool get hasApiBaseUrl => apiBaseUrl.trim().isNotEmpty;
}
