import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import 'multiplayer_client_utils.dart';

/// Transport-agnostic backend health helper shared by multiple game clients.
class BackendHealthChecker {
  BackendHealthChecker({
    http.Client? httpClient,
    this.healthPath = '/healthz',
    this.defaultTimeout = const Duration(seconds: 5),
    this.wakeTimeout = const Duration(seconds: 15),
  }) : _httpClient = httpClient ?? http.Client(),
       _ownsClient = httpClient == null;

  final http.Client _httpClient;
  final bool _ownsClient;
  final String healthPath;
  final Duration defaultTimeout;
  final Duration wakeTimeout;

  Future<BackendHealthResult> check({
    required String apiBaseUrl,
    Duration? timeout,
  }) async {
    return _request(
      apiBaseUrl: apiBaseUrl,
      wake: false,
      timeout: timeout ?? defaultTimeout,
    );
  }

  Future<BackendHealthResult> wake({required String apiBaseUrl}) async {
    return _request(apiBaseUrl: apiBaseUrl, wake: true, timeout: wakeTimeout);
  }

  Future<BackendHealthResult> _request({
    required String apiBaseUrl,
    required bool wake,
    required Duration timeout,
  }) async {
    final checkedAt = DateTime.now();
    try {
      final baseUri = MultiplayerClientUtils.parseApiBaseUri(apiBaseUrl);
      final uri = baseUri
          .resolve(healthPath)
          .replace(
            queryParameters: wake ? const <String, String>{'wake': '1'} : null,
          );
      final response = await _httpClient.get(uri).timeout(timeout);
      final isOk = response.statusCode >= 200 && response.statusCode < 300;
      return BackendHealthResult(
        ok: isOk,
        statusCode: response.statusCode,
        message: _responseMessage(response),
        checkedAt: checkedAt,
      );
    } on TimeoutException {
      return BackendHealthResult(
        ok: false,
        statusCode: null,
        message: 'Request timed out after ${timeout.inSeconds}s.',
        checkedAt: checkedAt,
      );
    } catch (error) {
      return BackendHealthResult(
        ok: false,
        statusCode: null,
        message: error.toString(),
        checkedAt: checkedAt,
      );
    }
  }

  void dispose() {
    if (_ownsClient) {
      _httpClient.close();
    }
  }

  static String _responseMessage(http.Response response) {
    final body = response.body.trim();
    if (body.isEmpty) {
      return response.statusCode >= 200 && response.statusCode < 300
          ? 'Healthy.'
          : 'Health endpoint failed (${response.statusCode}).';
    }

    try {
      final decoded = jsonDecode(body);
      if (decoded is Map && decoded['message'] is String) {
        return decoded['message'] as String;
      }
    } catch (_) {
      // Keep raw body fallback for observability.
    }
    return body;
  }
}

class BackendHealthResult {
  const BackendHealthResult({
    required this.ok,
    required this.statusCode,
    required this.message,
    required this.checkedAt,
  });

  final bool ok;
  final int? statusCode;
  final String message;
  final DateTime checkedAt;
}
