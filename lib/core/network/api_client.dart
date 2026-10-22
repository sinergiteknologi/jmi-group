import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../config/app_config.dart';

class ApiException implements Exception {
  ApiException(this.message);
  final String message;
  @override
  String toString() => message;
}

/// REST client for NewAPIVenusERPJMGroup (Node.js facade over the ASMX
/// services). Keeps the legacy flattened result shape (`Pref1..PrefN`,
/// `Code`/`Name`, `Status`, ...) so callers stay unchanged.
class ApiClient {
  ApiClient({http.Client? client}) : _client = client ?? http.Client();

  final http.Client _client;

  Future<Map<String, String>> call({
    required String host,
    required String operation,
    required Map<String, String> parameters,
  }) async {
    http.Response response;
    try {
      response = await _client
          .post(
            Uri.parse(_endpoint(operation)),
            headers: {'Content-Type': 'application/json; charset=utf-8'},
            body: jsonEncode({
              ...parameters,
              'host': host,
              if (AppConfig.implementServer.isNotEmpty)
                'ImplementServer': AppConfig.implementServer,
            }),
          )
          .timeout(const Duration(seconds: 60));
    } on TimeoutException {
      throw ApiException('Koneksi ke server timeout. Coba lagi.');
    } catch (_) {
      throw ApiException(
        'Gagal terhubung ke server. Periksa koneksi internet Anda.',
      );
    }

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw ApiException(_errorMessage(response));
    }
    return decodeResult(response.body);
  }

  String _endpoint(String operation) {
    final base = AppConfig.apiBase.replaceAll(RegExp(r'/+$'), '');
    final direct = '$base/api/mobile/$operation';
    if (!kIsWeb) return direct;
    if (AppConfig.corsProxy.isNotEmpty) return '${AppConfig.corsProxy}$direct';
    final uri = Uri.parse(base);
    if (uri.scheme == 'https') return direct;
    if (uri.hasScheme && uri.host.isNotEmpty) {
      return AppConfig.proxiedUrl(
        uri.host,
        '${uri.path}/api/mobile/$operation',
      );
    }
    return direct;
  }

  String _errorMessage(http.Response response) {
    try {
      final decoded = jsonDecode(response.body);
      if (decoded is Map && decoded['error'] != null) {
        return decoded['error'].toString();
      }
    } catch (_) {}
    return 'Server merespons ${response.statusCode}.';
  }

  static Map<String, String> decodeResult(String body) {
    Object? decoded;
    try {
      decoded = jsonDecode(body);
    } catch (_) {
      throw ApiException('Respons server tidak valid.');
    }
    if (decoded is! Map) throw ApiException('Respons server tidak valid.');
    if (decoded['error'] != null) {
      throw ApiException(decoded['error'].toString());
    }
    return decoded.map((key, value) => MapEntry('$key', '${value ?? ''}'));
  }
}
