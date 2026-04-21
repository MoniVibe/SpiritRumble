import 'package:puredots_turn_engine/puredots_turn_engine.dart';

abstract class MultiplayerBackend {
  Future<MatchAssignment> findMatch(MatchmakingRequest request);

  Future<StateEnvelope> joinMatch({
    required String matchId,
    required int playerIndex,
  });

  Stream<StateEnvelope> watchMatch(String matchId);

  Future<StateEnvelope> submitCommand(CommandEnvelope envelope);
}

