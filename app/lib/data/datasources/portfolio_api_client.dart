import 'dart:convert';
import 'package:http/http.dart' as http;

import '../../domain/repositories/portfolio_repository.dart';

class PortfolioApiClient {
  PortfolioApiClient({
    required this.baseUrl,
    required this.client,
  });

  final String baseUrl;
  final http.Client client;

  Uri _uri(String path) {
    final trimmed = baseUrl.trim().replaceAll(RegExp(r'/+$'), '');
    if (trimmed.isEmpty) {
      throw const ApiException(
        statusCode: 0,
        code: 'MISSING_CONFIG',
        message: 'API_BASE_URL não configurada. Execute com --dart-define=API_BASE_URL=...',
      );
    }
    return Uri.parse('$trimmed$path');
  }

  Future<Map<String, dynamic>> getJson(String path) async {
    final response = await _send(() => client.get(_uri(path)));
    return _decodeObject(response);
  }

  Future<Map<String, dynamic>> postJson(
    String path,
    Map<String, dynamic> body,
  ) async {
    final response = await _send(
      () => client.post(
        _uri(path),
        headers: const {'Content-Type': 'application/json'},
        body: jsonEncode(body),
      ),
    );
    return _decodeObject(response);
  }

  Future<http.Response> _send(Future<http.Response> Function() request) async {
    try {
      return await request().timeout(const Duration(seconds: 12));
    } on ApiException {
      rethrow;
    } catch (error) {
      throw ApiException(
        statusCode: 0,
        code: 'NETWORK_ERROR',
        message: 'Falha ao conectar com a API: $error',
      );
    }
  }

  Map<String, dynamic> _decodeObject(http.Response response) {
    final decoded = response.body.trim().isEmpty
        ? <String, dynamic>{}
        : jsonDecode(response.body);

    if (response.statusCode < 200 || response.statusCode >= 300) {
      if (decoded is Map<String, dynamic> && decoded['error'] is Map) {
        final err = Map<String, dynamic>.from(decoded['error'] as Map);
        final rawFields = err['fields'];
        final fields = rawFields is Map
            ? rawFields.map((k, v) => MapEntry(k.toString(), v.toString()))
            : const <String, String>{};
        throw ApiException(
          statusCode: response.statusCode,
          code: err['code']?.toString() ?? 'API_ERROR',
          message: err['message']?.toString() ?? 'Erro na requisicao',
          fieldErrors: fields,
        );
      }
      throw ApiException(
        statusCode: response.statusCode,
        code: 'HTTP_${response.statusCode}',
        message: 'Erro HTTP ${response.statusCode}',
      );
    }

    if (decoded is! Map<String, dynamic>) {
      throw const ApiException(
        statusCode: 500,
        code: 'INVALID_RESPONSE',
        message: 'Resposta JSON inesperada da API',
      );
    }
    return decoded;
  }
}
