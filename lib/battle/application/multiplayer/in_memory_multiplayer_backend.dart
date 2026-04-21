import 'dart:async';

import 'package:puredots_turn_engine/puredots_turn_engine.dart';

import '../../domain/battle_defaults.dart';
import 'multiplayer_backend.dart';

class InMemoryMultiplayerBackend implements MultiplayerBackend {
  InMemoryMultiplayerBackend({
    TurnEngine engine = const TurnEngine(),
    MatchRules rules = defaultBattleRules,
    List<PieceDefinition>? catalog,
  }) : _engine = engine,
       _rules = rules,
       _catalog = List<PieceDefinition>.from(catalog ?? defaultBattleCatalog);

  final TurnEngine _engine;
  final MatchRules _rules;
  final List<PieceDefinition> _catalog;

  final Map<String, _PendingTicket> _pendingByQueue = <String, _PendingTicket>{};
  final Map<String, _ServerMatch> _matches = <String, _ServerMatch>{};
  int _nextMatchId = 1;

  @override
  Future<MatchAssignment> findMatch(MatchmakingRequest request) async {
    final queue = request.queue.trim().isEmpty ? 'casual' : request.queue.trim();
    final pending = _pendingByQueue.remove(queue);
    if (pending == null) {
      final completer = Completer<MatchAssignment>();
      _pendingByQueue[queue] = _PendingTicket(
        completer: completer,
      );
      return completer.future;
    }

    final match = _createMatch();
    pending.completer.complete(
      MatchAssignment(matchId: match.matchId, playerIndex: 0, rules: _rules),
    );
    return MatchAssignment(matchId: match.matchId, playerIndex: 1, rules: _rules);
  }

  @override
  Future<StateEnvelope> joinMatch({
    required String matchId,
    required int playerIndex,
  }) async {
    final match = _requireMatch(matchId);
    if (playerIndex < 0 || playerIndex >= match.state.players.length) {
      throw StateError('invalid player index $playerIndex for match $matchId');
    }
    return match.snapshot();
  }

  @override
  Stream<StateEnvelope> watchMatch(String matchId) {
    final match = _requireMatch(matchId);
    return match.updates.stream;
  }

  @override
  Future<StateEnvelope> submitCommand(CommandEnvelope envelope) async {
    final match = _requireMatch(envelope.matchId);

    if (envelope.clientRevision != match.revision) {
      return match.snapshot(
        deniedReason:
            'revision mismatch (client=${envelope.clientRevision}, server=${match.revision})',
      );
    }

    if (envelope.actorIndex != match.state.activePlayerIndex) {
      return match.snapshot(
        deniedReason:
            'not actor turn (actor=${envelope.actorIndex}, active=${match.state.activePlayerIndex})',
      );
    }

    final result = _engine.applyCommand(
      match.state,
      envelope.actorIndex,
      envelope.command,
      rules: _rules,
    );
    if (!result.applied) {
      return match.snapshot(deniedReason: result.reason ?? 'command denied');
    }

    match.state = result.state;
    match.revision++;
    final snapshot = match.snapshot();
    match.updates.add(snapshot);
    return snapshot;
  }

  _ServerMatch _createMatch() {
    final matchId = 'm${_nextMatchId++}';
    final state = _engine.newMatch(draftCatalog: _catalog, rules: _rules);
    final match = _ServerMatch(matchId: matchId, state: state);
    _matches[matchId] = match;
    return match;
  }

  _ServerMatch _requireMatch(String matchId) {
    final match = _matches[matchId];
    if (match == null) {
      throw StateError('match not found: $matchId');
    }
    return match;
  }
}

class _PendingTicket {
  const _PendingTicket({
    required this.completer,
  });

  final Completer<MatchAssignment> completer;
}

class _ServerMatch {
  _ServerMatch({
    required this.matchId,
    required this.state,
  });

  final String matchId;
  int revision = 0;
  GameState state;
  final StreamController<StateEnvelope> updates =
      StreamController<StateEnvelope>.broadcast();

  StateEnvelope snapshot({String? deniedReason}) {
    return StateEnvelope(
      matchId: matchId,
      revision: revision,
      serverTimestampUtc: DateTime.now().toUtc(),
      state: state,
      deniedReason: deniedReason,
    );
  }
}
