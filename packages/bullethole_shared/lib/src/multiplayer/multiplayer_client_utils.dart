import 'dart:convert';

/// Shared client-side helpers for multiplayer transport and payload parsing.
class MultiplayerClientUtils {
  const MultiplayerClientUtils._();

  static Uri parseApiBaseUri(String raw) {
    final uri = Uri.parse(raw.trim());
    if (!uri.hasScheme || uri.host.isEmpty) {
      throw Exception('Use a full URL like https://your-host');
    }
    return uri;
  }

  static Uri websocketUriFromBase({
    required Uri baseUri,
    required String wsPath,
    Map<String, String> queryParameters = const <String, String>{},
  }) {
    final scheme = baseUri.scheme == 'https' ? 'wss' : 'ws';
    final normalizedPath = wsPath.startsWith('/') ? wsPath : '/$wsPath';
    return baseUri.replace(
      scheme: scheme,
      path: normalizedPath,
      queryParameters: queryParameters.isEmpty ? null : queryParameters,
    );
  }

  static Map<String, dynamic> decodeJsonMap(String body) {
    if (body.trim().isEmpty) {
      return <String, dynamic>{};
    }
    try {
      final decoded = jsonDecode(body);
      if (decoded is Map) {
        return Map<String, dynamic>.from(decoded);
      }
    } catch (_) {
      // Invalid payloads should not crash UI flow.
    }
    return <String, dynamic>{};
  }

  static int? readInt(dynamic value) {
    if (value is int) {
      return value;
    }
    if (value is num) {
      return value.toInt();
    }
    if (value is String) {
      return int.tryParse(value);
    }
    return null;
  }

  static String? sanitizeIdentifier(dynamic value, {int maxLength = 40}) {
    if (value is! String) {
      return null;
    }
    final normalized = value.trim();
    if (normalized.isEmpty || normalized.length > maxLength) {
      return null;
    }
    final valid = RegExp(r'^[a-z0-9_-]+$');
    if (!valid.hasMatch(normalized)) {
      return null;
    }
    return normalized;
  }
}
