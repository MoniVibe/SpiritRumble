import 'multiplayer_client_utils.dart';

/// Canonical relay events for non-authoritative multiplayer game types.
class RelayEventName {
  const RelayEventName._();

  static const String ready = 'ready';
  static const String action = 'action';
  static const String complete = 'complete';
}

/// Structured payload for relay-mode websocket messages.
class RelayEnvelope {
  const RelayEnvelope({
    required this.event,
    this.payload = const <String, Object?>{},
    this.stateHash,
    this.result,
  });

  final String event;
  final Map<String, Object?> payload;
  final String? stateHash;
  final String? result;

  Map<String, dynamic> toSocketPayload() {
    return <String, dynamic>{
      'type': 'relay',
      'event': event,
      'payload': payload,
      'stateHash': _normalizedText(stateHash),
      'result': _normalizedText(result),
    };
  }

  Map<String, Object?> toStateRelayState() {
    return <String, Object?>{
      'event': event,
      'payload': payload,
      'stateHash': _normalizedText(stateHash),
      'result': _normalizedText(result),
    };
  }

  static RelayEnvelope? fromRelayMessage(Map<String, dynamic> message) {
    final type = message['type']?.toString().trim().toLowerCase();
    if (type != 'relay') {
      return null;
    }
    return fromRawRelayState(message);
  }

  static RelayEnvelope? fromState(Map<String, dynamic> state) {
    final raw = state['relayState'];
    if (raw is! Map) {
      return null;
    }
    return fromRawRelayState(Map<String, dynamic>.from(raw));
  }

  static RelayEnvelope? fromRawRelayState(Map<String, dynamic> relayState) {
    final event = MultiplayerClientUtils.sanitizeIdentifier(
      relayState['event'],
    );
    if (event == null) {
      return null;
    }
    final rawPayload = relayState['payload'];
    final payload = rawPayload is Map
        ? Map<String, Object?>.from(rawPayload)
        : const <String, Object?>{};
    return RelayEnvelope(
      event: event,
      payload: payload,
      stateHash: _normalizedText(relayState['stateHash']),
      result: _normalizedText(relayState['result']),
    );
  }
}

/// Explicit server acknowledgement for relay submissions.
class RelayAck {
  const RelayAck({
    required this.sequence,
    required this.event,
    this.fromColor,
    this.stateHash,
  });

  final int sequence;
  final String event;
  final String? fromColor;
  final String? stateHash;

  static RelayAck? fromMessage(Map<String, dynamic> message) {
    final type = message['type']?.toString().trim().toLowerCase();
    if (type != 'relay_ack') {
      return null;
    }

    final sequence = MultiplayerClientUtils.readInt(message['sequence']);
    final event = MultiplayerClientUtils.sanitizeIdentifier(message['event']);
    if (sequence == null || event == null) {
      return null;
    }

    final fromColorRaw = message['fromColor']?.toString().trim().toLowerCase();
    final fromColor = fromColorRaw == 'w' || fromColorRaw == 'b'
        ? fromColorRaw
        : null;
    return RelayAck(
      sequence: sequence,
      event: event,
      fromColor: fromColor,
      stateHash: _normalizedText(message['stateHash']),
    );
  }
}

/// Shared relay-mode session metadata surfaced in state snapshots.
class RelaySessionMeta {
  const RelaySessionMeta({
    required this.whiteReady,
    required this.blackReady,
    required this.actionCount,
  });

  final bool whiteReady;
  final bool blackReady;
  final int actionCount;

  bool get allReady => whiteReady && blackReady;

  Map<String, Object?> toJson() {
    return <String, Object?>{
      'whiteReady': whiteReady,
      'blackReady': blackReady,
      'actionCount': actionCount,
    };
  }

  static RelaySessionMeta fromState(Map<String, dynamic> state) {
    final raw = state['relayMeta'];
    if (raw is! Map) {
      return const RelaySessionMeta(
        whiteReady: false,
        blackReady: false,
        actionCount: 0,
      );
    }
    final map = Map<String, dynamic>.from(raw);
    return RelaySessionMeta(
      whiteReady: _readBool(map['readyW']),
      blackReady: _readBool(map['readyB']),
      actionCount: MultiplayerClientUtils.readInt(map['actionCount']) ?? 0,
    );
  }
}

String? _normalizedText(dynamic value) {
  if (value is! String) {
    return null;
  }
  final normalized = value.trim();
  if (normalized.isEmpty) {
    return null;
  }
  return normalized;
}

bool _readBool(dynamic value) {
  if (value is bool) {
    return value;
  }
  if (value is num) {
    return value != 0;
  }
  if (value is String) {
    final normalized = value.trim().toLowerCase();
    return normalized == 'true' || normalized == '1' || normalized == 'yes';
  }
  return false;
}
