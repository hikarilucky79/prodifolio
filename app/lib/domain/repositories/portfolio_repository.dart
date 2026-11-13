import '../entities/portfolio_entities.dart';

class ApiException implements Exception {
  const ApiException({
    required this.statusCode,
    required this.code,
    required this.message,
    this.fieldErrors = const {},
  });

  final int statusCode;
  final String code;
  final String message;
  final Map<String, String> fieldErrors;

  @override
  String toString() => 'ApiException($statusCode, $code): $message';
}

abstract interface class PortfolioRepository {
  Future<ProjectsFeed> getProjects();
  Future<ProjectDetail> getProjectDetail(String name);
  Future<PortfolioStats> getStats();
  Future<ContactReceipt> submitContact(ContactSubmission submission);
}
