import 'json_codec.dart';
import 'models.dart';

class MatchmakingRequest {
  const MatchmakingRequest({
    required this.playerId,
    this.queue = 'casual',
  });

  final String playerId;
  final String queue;

  Map<String, Object?> toJson() {
    return <String, Object?>{'playerId': playerId, 'queue': queue};
  }

  static MatchmakingRequest fromJson(Map<String, Object?> json) {
    return MatchmakingRequest(
      playerId: (json['playerId'] ?? '').toString(),
      queue: (json['queue'] ?? 'casual').toString(),
    );
  }
}

class MatchAssignment {
  const MatchAssignment({
    required this.matchId,
    required this.playerIndex,
    required this.rules,
  });

  final String matchId;
  final int playerIndex;
  final MatchRules rules;

  Map<String, Object?> toJson() {
    return <String, Object?>{
      'matchId': matchId,
      'playerIndex': playerIndex,
      'rules': TurnEngineJsonCodec.encodeRules(rules),
    };
  }

  static MatchAssignment fromJson(Map<String, Object?> json) {
    return MatchAssignment(
      matchId: (json['matchId'] ?? '').toString(),
      playerIndex: (json['playerIndex'] as num?)?.toInt() ?? 0,
      rules: TurnEngineJsonCodec.decodeRules(
        (json['rules'] as Map).map(
          (dynamic key, dynamic value) =>
              MapEntry(key.toString(), value as Object?),
        ),
      ),
    );
  }
}

class CommandEnvelope {
  const CommandEnvelope({
    required this.matchId,
    required this.actorIndex,
    required this.clientRevision,
    required this.command,
  });

  final String matchId;
  final int actorIndex;
  final int clientRevision;
  final GameCommand command;

  Map<String, Object?> toJson() {
    return <String, Object?>{
      'matchId': matchId,
      'actorIndex': actorIndex,
      'clientRevision': clientRevision,
      'command': TurnEngineJsonCodec.encodeGameCommand(command),
    };
  }

  static CommandEnvelope fromJson(Map<String, Object?> json) {
    return CommandEnvelope(
      matchId: (json['matchId'] ?? '').toString(),
      actorIndex: (json['actorIndex'] as num?)?.toInt() ?? 0,
      clientRevision: (json['clientRevision'] as num?)?.toInt() ?? 0,
      command: TurnEngineJsonCodec.decodeGameCommand(
        (json['command'] as Map).map(
          (dynamic key, dynamic value) =>
              MapEntry(key.toString(), value as Object?),
        ),
      ),
    );
  }
}

class StateEnvelope {
  const StateEnvelope({
    required this.matchId,
    required this.revision,
    required this.serverTimestampUtc,
    required this.state,
    this.deniedReason,
  });

  final String matchId;
  final int revision;
  final DateTime serverTimestampUtc;
  final GameState state;
  final String? deniedReason;

  Map<String, Object?> toJson() {
    return <String, Object?>{
      'matchId': matchId,
      'revision': revision,
      'serverTimestampUtc': serverTimestampUtc.toUtc().toIso8601String(),
      'state': TurnEngineJsonCodec.encodeGameState(state),
      'deniedReason': deniedReason,
    };
  }

  static StateEnvelope fromJson(Map<String, Object?> json) {
    return StateEnvelope(
      matchId: (json['matchId'] ?? '').toString(),
      revision: (json['revision'] as num?)?.toInt() ?? 0,
      serverTimestampUtc: DateTime.parse(
        (json['serverTimestampUtc'] ?? DateTime.now().toUtc().toIso8601String())
            .toString(),
      ),
      state: TurnEngineJsonCodec.decodeGameState(
        (json['state'] as Map).map(
          (dynamic key, dynamic value) =>
              MapEntry(key.toString(), value as Object?),
        ),
      ),
      deniedReason: json['deniedReason']?.toString(),
    );
  }
}

