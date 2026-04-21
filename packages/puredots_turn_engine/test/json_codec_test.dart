import 'package:puredots_turn_engine/puredots_turn_engine.dart';
import 'package:test/test.dart';

void main() {
  const engine = TurnEngine();
  const rules = MatchRules(
    poolSize: 5,
    firstPlayerOpeningDraft: 1,
    standardDraft: 2,
    startingTotemsOnField: 1,
    startingTotemsInHand: 3,
    poolSeed: 42,
  );

  group('TurnEngineJsonCodec', () {
    test('round-trips all command variants', () {
      final commands = <GameCommand>[
        DraftFromPoolMove(poolPieceId: 'p1'),
        BindFromPoolMove(poolPieceId: 'p2', unitId: 'u1'),
        PlayToNewUnitMove(handPieceId: 'h1'),
        SummonTotemMove(),
        AddToExistingUnitMove(handPieceId: 'h2', unitId: 'u1'),
        ChooseAttackerMove(unitId: 'u1', pieceIndex: 1),
        AttackUnitMove(attackerUnitId: 'u1', targetUnitId: 'u9'),
        ChooseDefenderMove(unitId: 'u2', pieceIndex: 0),
        EndTurnMove(),
      ];

      for (final command in commands) {
        final json = TurnEngineJsonCodec.encodeGameCommand(command);
        final decoded = TurnEngineJsonCodec.decodeGameCommand(json);
        expect(decoded.type, command.type);
        expect(decoded.summary(), command.summary());
      }
    });

    test('round-trips game state', () {
      final state = engine.newMatch(
        draftCatalog: canonicalPlaceholderCatalog,
        rules: rules,
      );
      final bind = BindFromPoolMove(
        poolPieceId: state.pool.first.instanceId,
        unitId: state.activePlayer.units.first.unitId,
      );
      final afterBind = engine.applyCommand(
        state,
        state.activePlayerIndex,
        bind,
        rules: rules,
      );
      expect(afterBind.applied, isTrue, reason: afterBind.reason);

      final encoded = TurnEngineJsonCodec.encodeGameState(afterBind.state);
      final decoded = TurnEngineJsonCodec.decodeGameState(encoded);
      final reEncoded = TurnEngineJsonCodec.encodeGameState(decoded);

      expect(reEncoded, equals(encoded));
    });

    test('round-trips multiplayer envelopes', () {
      final state = engine.newMatch(
        draftCatalog: canonicalPlaceholderCatalog,
        rules: rules,
      );
      final commandEnvelope = CommandEnvelope(
        matchId: 'm1',
        actorIndex: 0,
        clientRevision: 7,
        command: EndTurnMove(),
      );
      final decodedCommand = CommandEnvelope.fromJson(commandEnvelope.toJson());
      expect(decodedCommand.matchId, commandEnvelope.matchId);
      expect(decodedCommand.actorIndex, commandEnvelope.actorIndex);
      expect(decodedCommand.clientRevision, commandEnvelope.clientRevision);
      expect(decodedCommand.command.type, commandEnvelope.command.type);

      final stateEnvelope = StateEnvelope(
        matchId: 'm1',
        revision: 8,
        serverTimestampUtc: DateTime.utc(2026, 1, 1, 12, 30),
        state: state,
      );
      final decodedState = StateEnvelope.fromJson(stateEnvelope.toJson());
      expect(decodedState.matchId, stateEnvelope.matchId);
      expect(decodedState.revision, stateEnvelope.revision);
      expect(
        TurnEngineJsonCodec.encodeGameState(decodedState.state),
        TurnEngineJsonCodec.encodeGameState(stateEnvelope.state),
      );
    });
  });
}
