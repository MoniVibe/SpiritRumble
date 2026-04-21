import 'dart:async';

import 'package:puredots_turn_engine/puredots_turn_engine.dart';

import 'multiplayer_backend.dart';

class MultiplayerClientState {
  const MultiplayerClientState({
    required this.matchId,
    required this.localPlayerIndex,
    required this.revision,
    required this.rules,
    required this.gameState,
    this.lastDeniedReason,
  });

  final String matchId;
  final int localPlayerIndex;
  final int revision;
  final MatchRules rules;
  final GameState gameState;
  final String? lastDeniedReason;

  bool get isMyTurn => gameState.activePlayerIndex == localPlayerIndex;
}

class MultiplayerClient {
  MultiplayerClient(this._backend);

  final MultiplayerBackend _backend;
  final StreamController<MultiplayerClientState> _updates =
      StreamController<MultiplayerClientState>.broadcast();

  StreamSubscription<StateEnvelope>? _matchSubscription;
  MultiplayerClientState? _state;

  Stream<MultiplayerClientState> get updates => _updates.stream;

  MultiplayerClientState? get state => _state;

  Future<MultiplayerClientState> findAndJoin({
    required String playerId,
    String queue = 'casual',
  }) async {
    final assignment = await _backend.findMatch(
      MatchmakingRequest(playerId: playerId, queue: queue),
    );
    final joined = await _backend.joinMatch(
      matchId: assignment.matchId,
      playerIndex: assignment.playerIndex,
    );

    await _matchSubscription?.cancel();
    _matchSubscription = _backend
        .watchMatch(assignment.matchId)
        .listen(_onRemoteSnapshot);

    final next = MultiplayerClientState(
      matchId: assignment.matchId,
      localPlayerIndex: assignment.playerIndex,
      revision: joined.revision,
      rules: assignment.rules,
      gameState: joined.state,
      lastDeniedReason: joined.deniedReason,
    );
    _setState(next);
    return next;
  }

  CommandCheck canSubmit(GameCommand command) {
    final current = _state;
    if (current == null) {
      return const CommandCheck.denied('not connected to a match');
    }
    return const TurnEngine().canApply(
      current.gameState,
      current.localPlayerIndex,
      command,
      rules: current.rules,
    );
  }

  Future<bool> submit(GameCommand command) async {
    final current = _state;
    if (current == null) {
      return false;
    }

    final response = await _backend.submitCommand(
      CommandEnvelope(
        matchId: current.matchId,
        actorIndex: current.localPlayerIndex,
        clientRevision: current.revision,
        command: command,
      ),
    );

    final next = MultiplayerClientState(
      matchId: current.matchId,
      localPlayerIndex: current.localPlayerIndex,
      revision: response.revision,
      rules: current.rules,
      gameState: response.state,
      lastDeniedReason: response.deniedReason,
    );
    _setState(next);
    return response.deniedReason == null;
  }

  Future<void> dispose() async {
    await _matchSubscription?.cancel();
    await _updates.close();
  }

  void _onRemoteSnapshot(StateEnvelope snapshot) {
    final current = _state;
    if (current == null) {
      return;
    }
    _setState(
      MultiplayerClientState(
        matchId: current.matchId,
        localPlayerIndex: current.localPlayerIndex,
        revision: snapshot.revision,
        rules: current.rules,
        gameState: snapshot.state,
        lastDeniedReason: snapshot.deniedReason,
      ),
    );
  }

  void _setState(MultiplayerClientState next) {
    _state = next;
    if (!_updates.isClosed) {
      _updates.add(next);
    }
  }
}
