import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:web_socket_channel/web_socket_channel.dart';

import 'multiplayer_client_utils.dart';

/// Shared transport client for matchmaking + websocket wiring.
///
/// This intentionally stays game-agnostic so chess/backgammon can share the
/// same lifecycle and error handling.
class MultiplayerTransportClient {
  MultiplayerTransportClient({
    http.Client? httpClient,
    this.joinEndpointPath = '/api/matches/join',
    this.debugLogsPath = '/debug/logs',
    this.requestTimeout = const Duration(seconds: 5),
  }) : _httpClient = httpClient ?? http.Client(),
       _ownsClient = httpClient == null;

  final http.Client _httpClient;
  final bool _ownsClient;
  final String joinEndpointPath;
  final String debugLogsPath;
  final Duration requestTimeout;

  WebSocketChannel? _channel;
  StreamSubscription<dynamic>? _subscription;

  bool get isSocketConnected => _channel != null;

  Future<MatchJoinResult> joinMatch({
    required String apiBaseUrl,
    required String displayName,
    String? pieceSkinId,
    int? cooldownSeconds,
    String? gameType,
    Map<String, dynamic>? metadata,
  }) async {
    final normalizedName = displayName.trim();
    if (normalizedName.isEmpty) {
      throw const MultiplayerTransportException(
        message: 'Display name is required.',
      );
    }

    final baseUri = MultiplayerClientUtils.parseApiBaseUri(apiBaseUrl);
    final payload = <String, dynamic>{'name': normalizedName};
    if (pieceSkinId != null && pieceSkinId.trim().isNotEmpty) {
      payload['pieceSkinId'] = pieceSkinId.trim();
    }
    if (cooldownSeconds != null) {
      payload['cooldownSeconds'] = cooldownSeconds;
    }
    final normalizedGameType = MultiplayerClientUtils.sanitizeIdentifier(
      gameType,
    );
    if (normalizedGameType != null) {
      payload['gameType'] = normalizedGameType;
    }
    if (metadata != null && metadata.isNotEmpty) {
      payload['metadata'] = metadata;
    }

    final response = await _httpClient
        .post(
          baseUri.resolve(joinEndpointPath),
          headers: const <String, String>{'content-type': 'application/json'},
          body: jsonEncode(payload),
        )
        .timeout(requestTimeout);

    final body = MultiplayerClientUtils.decodeJsonMap(response.body);
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw MultiplayerHttpException(
        statusCode: response.statusCode,
        message:
            body['error']?.toString() ??
            'Matchmaking failed (${response.statusCode}).',
      );
    }

    final matchId = body['matchId'] as String?;
    final playerId = body['playerId'] as String?;
    final wsPath = body['wsPath'] as String? ?? '/ws';
    if (matchId == null || playerId == null) {
      throw const MultiplayerTransportException(
        message: 'Invalid match response from server.',
      );
    }

    return MatchJoinResult(
      baseUri: baseUri,
      matchId: matchId,
      playerId: playerId,
      wsPath: wsPath,
      cooldownSeconds: MultiplayerClientUtils.readInt(body['cooldownSeconds']),
      payload: body,
    );
  }

  Future<Uri> connectSocket({
    required Uri baseUri,
    required String wsPath,
    required String matchId,
    required String playerId,
    required void Function(dynamic raw) onMessage,
    required void Function(Object error) onError,
    required void Function() onDone,
  }) async {
    final wsUri = MultiplayerClientUtils.websocketUriFromBase(
      baseUri: baseUri,
      wsPath: wsPath,
      queryParameters: <String, String>{
        'matchId': matchId,
        'playerId': playerId,
      },
    );
    await connectToUri(
      uri: wsUri,
      onMessage: onMessage,
      onError: onError,
      onDone: onDone,
    );
    return wsUri;
  }

  Future<void> connectToUri({
    required Uri uri,
    required void Function(dynamic raw) onMessage,
    required void Function(Object error) onError,
    required void Function() onDone,
  }) async {
    await disconnect();
    final channel = WebSocketChannel.connect(uri);
    _channel = channel;
    _subscription = channel.stream.listen(
      onMessage,
      onError: onError,
      onDone: onDone,
      cancelOnError: true,
    );
  }

  bool sendJson(Map<String, dynamic> payload) {
    final channel = _channel;
    if (channel == null) {
      return false;
    }
    channel.sink.add(jsonEncode(payload));
    return true;
  }

  Future<List<Map<String, dynamic>>> fetchServerDebugLogs({
    required String apiBaseUrl,
    String? matchId,
    int limit = 120,
  }) async {
    final normalizedLimit = limit.clamp(1, 500);
    final baseUri = MultiplayerClientUtils.parseApiBaseUri(apiBaseUrl);
    final query = <String, String>{'limit': '$normalizedLimit'};
    if (matchId != null && matchId.trim().isNotEmpty) {
      query['matchId'] = matchId.trim();
    }

    final response = await _httpClient
        .get(baseUri.resolve(debugLogsPath).replace(queryParameters: query))
        .timeout(requestTimeout);
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw MultiplayerHttpException(
        statusCode: response.statusCode,
        message: 'Server debug logs failed (${response.statusCode}).',
      );
    }

    final body = MultiplayerClientUtils.decodeJsonMap(response.body);
    final items = body['items'];
    if (items is! List) {
      return const <Map<String, dynamic>>[];
    }

    final parsed = <Map<String, dynamic>>[];
    for (final raw in items) {
      if (raw is! Map) {
        continue;
      }
      parsed.add(Map<String, dynamic>.from(raw));
    }
    return parsed;
  }

  Future<void> disconnect() async {
    await _subscription?.cancel();
    _subscription = null;
    await _channel?.sink.close();
    _channel = null;
  }

  void dispose() {
    unawaited(disconnect());
    if (_ownsClient) {
      _httpClient.close();
    }
  }
}

class MatchJoinResult {
  const MatchJoinResult({
    required this.baseUri,
    required this.matchId,
    required this.playerId,
    required this.wsPath,
    required this.payload,
    this.cooldownSeconds,
  });

  final Uri baseUri;
  final String matchId;
  final String playerId;
  final String wsPath;
  final int? cooldownSeconds;
  final Map<String, dynamic> payload;
}

class MultiplayerTransportException implements Exception {
  const MultiplayerTransportException({required this.message});

  final String message;

  @override
  String toString() => 'MultiplayerTransportException: $message';
}

class MultiplayerHttpException extends MultiplayerTransportException {
  const MultiplayerHttpException({
    required this.statusCode,
    required super.message,
  });

  final int statusCode;

  @override
  String toString() => 'MultiplayerHttpException($statusCode): $message';
}
