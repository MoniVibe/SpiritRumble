import 'package:bullethole_cards/battle/application/multiplayer/in_memory_multiplayer_backend.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:puredots_turn_engine/puredots_turn_engine.dart';

void main() {
  group('InMemoryMultiplayerBackend', () {
    test('pairs two tickets into the same match with opposite seats', () async {
      final backend = InMemoryMultiplayerBackend();

      final waiting = backend.findMatch(
        const MatchmakingRequest(playerId: 'alice', queue: 'casual'),
      );
      final second = await backend.findMatch(
        const MatchmakingRequest(playerId: 'bob', queue: 'casual'),
      );
      final first = await waiting;

      expect(first.matchId, second.matchId);
      expect(<int>{first.playerIndex, second.playerIndex}, {0, 1});
    });

    test('uses authoritative turn validation on submitted commands', () async {
      final backend = InMemoryMultiplayerBackend();
      final waiting = backend.findMatch(
        const MatchmakingRequest(playerId: 'alice', queue: 'ranked'),
      );
      final second = await backend.findMatch(
        const MatchmakingRequest(playerId: 'bob', queue: 'ranked'),
      );
      final first = await waiting;

      final p0 = first.playerIndex == 0 ? first : second;
      final p1 = first.playerIndex == 1 ? first : second;

      final joined0 = await backend.joinMatch(
        matchId: p0.matchId,
        playerIndex: p0.playerIndex,
      );
      final joined1 = await backend.joinMatch(
        matchId: p1.matchId,
        playerIndex: p1.playerIndex,
      );
      expect(joined0.revision, 0);
      expect(joined1.revision, 0);

      final draft = DraftFromPoolMove(
        poolPieceId: joined0.state.pool.first.instanceId,
      );
      final accepted = await backend.submitCommand(
        CommandEnvelope(
          matchId: p0.matchId,
          actorIndex: 0,
          clientRevision: 0,
          command: draft,
        ),
      );
      expect(accepted.deniedReason, isNull);
      expect(accepted.revision, 1);

      final denied = await backend.submitCommand(
        CommandEnvelope(
          matchId: p1.matchId,
          actorIndex: 1,
          clientRevision: 1,
          command: EndTurnMove(),
        ),
      );
      expect(denied.deniedReason, isNotNull);
      expect(denied.deniedReason, contains('not actor turn'));
    });
  });
}
