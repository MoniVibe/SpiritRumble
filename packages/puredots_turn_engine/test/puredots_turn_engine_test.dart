import 'package:puredots_turn_engine/puredots_turn_engine.dart';
import 'package:test/test.dart';

void main() {
  const engine = TurnEngine();
  const rules = MatchRules(
    startingHealth: 24,
    poolSize: 5,
    firstPlayerOpeningDraft: 1,
    standardDraft: 2,
  );

  final catalog = <PieceDefinition>[
    const PieceDefinition(
      id: 'flame_alpha',
      name: 'Flame Alpha',
      element: SpiritElement.red,
      attackMode: CombatMode.physical,
      defenseMode: CombatMode.magical,
      attack: 4,
      defense: 2,
    ),
    const PieceDefinition(
      id: 'grove_wall',
      name: 'Grove Wall',
      element: SpiritElement.green,
      attackMode: CombatMode.magical,
      defenseMode: CombatMode.magical,
      attack: 1,
      defense: 3,
    ),
    const PieceDefinition(
      id: 'tide_guard',
      name: 'Tide Guard',
      element: SpiritElement.blue,
      attackMode: CombatMode.magical,
      defenseMode: CombatMode.physical,
      attack: 2,
      defense: 3,
    ),
  ];

  group('TurnEngine command flow', () {
    test('turn 1 draft gives 1, later turns draft gives 2', () {
      var state = engine.newMatch(draftCatalog: catalog, rules: rules);

      state = _apply(
        engine,
        state,
        DraftFromPoolMove(poolPieceId: state.pool.first.instanceId),
      );
      expect(state.activePlayer.hand.length, 1);
      expect(state.phase, TurnPhase.mainActions);

      state = _apply(engine, state, EndTurnMove());
      expect(state.activePlayerIndex, 1);
      expect(state.phase, TurnPhase.draftFromPool);

      state = _apply(
        engine,
        state,
        DraftFromPoolMove(poolPieceId: state.pool.first.instanceId),
      );
      expect(state.activePlayer.hand.length, 1);
      expect(state.phase, TurnPhase.draftFromPool);

      state = _apply(
        engine,
        state,
        DraftFromPoolMove(poolPieceId: state.pool.first.instanceId),
      );
      expect(state.activePlayer.hand.length, 2);
      expect(state.phase, TurnPhase.mainActions);
    });

    test('pool refills to 5 at turn start', () {
      var state = engine.newMatch(draftCatalog: catalog, rules: rules);
      expect(state.pool.length, 5);

      state = _apply(
        engine,
        state,
        DraftFromPoolMove(poolPieceId: state.pool.first.instanceId),
      );
      expect(state.pool.length, 4);

      state = _apply(engine, state, EndTurnMove());
      expect(state.pool.length, 5);
    });

    test('play to new unit works', () {
      var state = engine.newMatch(draftCatalog: catalog, rules: rules);
      state = _apply(
        engine,
        state,
        DraftFromPoolMove(poolPieceId: state.pool.first.instanceId),
      );

      final pieceId = state.activePlayer.hand.first.instanceId;
      state = _apply(engine, state, PlayToNewUnitMove(handPieceId: pieceId));

      expect(state.activePlayer.hand, isEmpty);
      expect(state.activePlayer.units.length, 1);
      expect(state.activePlayer.units.first.pieces.length, 1);
    });

    test('add to existing unit works', () {
      const localRules = MatchRules(
        firstPlayerOpeningDraft: 2,
        standardDraft: 2,
      );
      var state = engine.newMatch(draftCatalog: catalog, rules: localRules);
      state = _apply(
        engine,
        state,
        DraftFromPoolMove(poolPieceId: state.pool.first.instanceId),
        rules: localRules,
      );
      state = _apply(
        engine,
        state,
        DraftFromPoolMove(poolPieceId: state.pool.first.instanceId),
        rules: localRules,
      );

      final firstPiece = state.activePlayer.hand[0].instanceId;
      final secondPiece = state.activePlayer.hand[1].instanceId;
      state = _apply(
        engine,
        state,
        PlayToNewUnitMove(handPieceId: firstPiece),
        rules: localRules,
      );
      final unitId = state.activePlayer.units.first.unitId;
      state = _apply(
        engine,
        state,
        AddToExistingUnitMove(handPieceId: secondPiece, unitId: unitId),
        rules: localRules,
      );

      expect(state.activePlayer.units.first.pieces.length, 2);
      expect(state.activePlayer.hand, isEmpty);
    });

    test('invalid add-to-enemy-unit fails', () {
      const localRules = MatchRules(
        firstPlayerOpeningDraft: 2,
        standardDraft: 2,
      );
      var state = engine.newMatch(draftCatalog: catalog, rules: localRules);
      state = _apply(
        engine,
        state,
        DraftFromPoolMove(poolPieceId: state.pool.first.instanceId),
        rules: localRules,
      );
      state = _apply(
        engine,
        state,
        DraftFromPoolMove(poolPieceId: state.pool.first.instanceId),
        rules: localRules,
      );
      final p1Piece = state.activePlayer.hand.first.instanceId;
      state = _apply(
        engine,
        state,
        PlayToNewUnitMove(handPieceId: p1Piece),
        rules: localRules,
      );
      final p1UnitId = state.activePlayer.units.first.unitId;
      state = _apply(engine, state, EndTurnMove(), rules: localRules);
      state = _apply(
        engine,
        state,
        ChooseDefenderMove(unitId: p1UnitId, pieceIndex: 0),
        rules: localRules,
      );

      state = _apply(
        engine,
        state,
        DraftFromPoolMove(poolPieceId: state.pool.first.instanceId),
        rules: localRules,
      );
      state = _apply(
        engine,
        state,
        DraftFromPoolMove(poolPieceId: state.pool.first.instanceId),
        rules: localRules,
      );
      final p2Piece = state.activePlayer.hand.first.instanceId;

      final result = engine.applyCommand(
        state,
        state.activePlayerIndex,
        AddToExistingUnitMove(handPieceId: p2Piece, unitId: p1UnitId),
        rules: localRules,
      );

      expect(result.applied, isFalse);
      expect(result.reason, contains('target unit does not exist'));
    });

    test('attack selection per unit works', () {
      const localRules = MatchRules(
        firstPlayerOpeningDraft: 2,
        standardDraft: 2,
      );
      var state = engine.newMatch(draftCatalog: catalog, rules: localRules);
      state = _apply(
        engine,
        state,
        DraftFromPoolMove(poolPieceId: state.pool.first.instanceId),
        rules: localRules,
      );
      state = _apply(
        engine,
        state,
        DraftFromPoolMove(poolPieceId: state.pool.first.instanceId),
        rules: localRules,
      );
      state = _apply(
        engine,
        state,
        PlayToNewUnitMove(
          handPieceId: state.activePlayer.hand.first.instanceId,
        ),
        rules: localRules,
      );
      final unitId = state.activePlayer.units.first.unitId;
      state = _apply(
        engine,
        state,
        AddToExistingUnitMove(
          handPieceId: state.activePlayer.hand.first.instanceId,
          unitId: unitId,
        ),
        rules: localRules,
      );
      state = _apply(
        engine,
        state,
        ChooseAttackerMove(unitId: unitId, pieceIndex: 1),
        rules: localRules,
      );
      expect(state.activePlayer.units.first.attackingPieceIndex, 1);
    });

    test('combat destroys only when element+mode+power all win', () {
      final attacker = catalog.first;
      final defenderStrong = catalog[1];
      final defenderModeTie = const PieceDefinition(
        id: 'mode_tie',
        name: 'Mode Tie',
        element: SpiritElement.green,
        attackMode: CombatMode.physical,
        defenseMode: CombatMode.physical,
        attack: 1,
        defense: 2,
      );

      final kill = engine.resolveAttack(
        attacker: attacker,
        defender: defenderStrong,
      );
      final noKill = engine.resolveAttack(
        attacker: attacker,
        defender: defenderModeTie,
      );

      expect(kill.destroyed, isTrue);
      expect(noKill.destroyed, isFalse);
    });

    test('freshly summoned units cannot attack until the next turn', () {
      const localRules = MatchRules(
        firstPlayerOpeningDraft: 1,
        standardDraft: 1,
      );
      var state = engine.newMatch(draftCatalog: catalog, rules: localRules);

      state = _draftByDefinition(
        engine,
        state,
        'flame_alpha',
        rules: localRules,
      );
      state = _apply(
        engine,
        state,
        PlayToNewUnitMove(
          handPieceId: state.activePlayer.hand.first.instanceId,
        ),
        rules: localRules,
      );
      final attackerUnitId = state.activePlayer.units.first.unitId;
      state = _apply(
        engine,
        state,
        ChooseAttackerMove(unitId: attackerUnitId, pieceIndex: 0),
        rules: localRules,
      );

      final deniedAttack = engine.applyCommand(
        state,
        state.activePlayerIndex,
        AttackUnitMove(attackerUnitId: attackerUnitId),
        rules: localRules,
      );
      expect(deniedAttack.applied, isFalse);
      expect(deniedAttack.reason, contains('same turn it was summoned'));

      state = _apply(engine, state, EndTurnMove(), rules: localRules);
      state = _apply(
        engine,
        state,
        ChooseDefenderMove(unitId: attackerUnitId, pieceIndex: 0),
        rules: localRules,
      );

      state = _apply(
        engine,
        state,
        DraftFromPoolMove(poolPieceId: state.pool.first.instanceId),
        rules: localRules,
      );
      state = _apply(engine, state, EndTurnMove(), rules: localRules);

      state = _apply(
        engine,
        state,
        DraftFromPoolMove(poolPieceId: state.pool.first.instanceId),
        rules: localRules,
      );
      state = _apply(
        engine,
        state,
        ChooseAttackerMove(unitId: attackerUnitId, pieceIndex: 0),
        rules: localRules,
      );
      state = _apply(
        engine,
        state,
        AttackUnitMove(attackerUnitId: attackerUnitId),
        rules: localRules,
      );

      expect(state.winnerIndex, isNull);
      expect(state.players[1].health, 20);
    });

    test('defender choice persists through opponent turn', () {
      var state = engine.newMatch(draftCatalog: catalog, rules: rules);
      state = _draftByDefinition(engine, state, 'flame_alpha', rules: rules);
      state = _apply(
        engine,
        state,
        PlayToNewUnitMove(
          handPieceId: state.activePlayer.hand.first.instanceId,
        ),
        rules: rules,
      );
      final p1UnitId = state.activePlayer.units.first.unitId;
      state = _apply(engine, state, EndTurnMove(), rules: rules);
      state = _apply(
        engine,
        state,
        ChooseDefenderMove(unitId: p1UnitId, pieceIndex: 0),
        rules: rules,
      );

      expect(state.activePlayerIndex, 1);
      expect(state.players[0].units.first.defendingPieceIndex, 0);
    });

    test('win triggers when opponent has zero field pieces', () {
      const localRules = MatchRules(
        firstPlayerOpeningDraft: 1,
        standardDraft: 1,
      );
      var state = engine.newMatch(draftCatalog: catalog, rules: localRules);

      state = _draftByDefinition(
        engine,
        state,
        'flame_alpha',
        rules: localRules,
      );
      state = _apply(
        engine,
        state,
        PlayToNewUnitMove(
          handPieceId: state.activePlayer.hand.first.instanceId,
        ),
        rules: localRules,
      );
      final attackerUnitId = state.activePlayer.units.first.unitId;
      state = _apply(
        engine,
        state,
        ChooseAttackerMove(unitId: attackerUnitId, pieceIndex: 0),
        rules: localRules,
      );
      state = _apply(engine, state, EndTurnMove(), rules: localRules);
      state = _apply(
        engine,
        state,
        ChooseDefenderMove(unitId: attackerUnitId, pieceIndex: 0),
        rules: localRules,
      );

      state = _draftByDefinition(
        engine,
        state,
        'grove_wall',
        rules: localRules,
      );
      state = _apply(
        engine,
        state,
        PlayToNewUnitMove(
          handPieceId: state.activePlayer.hand.first.instanceId,
        ),
        rules: localRules,
      );
      final defenderUnitId = state.activePlayer.units.first.unitId;
      state = _apply(engine, state, EndTurnMove(), rules: localRules);
      state = _apply(
        engine,
        state,
        ChooseDefenderMove(unitId: defenderUnitId, pieceIndex: 0),
        rules: localRules,
      );
      state = _apply(
        engine,
        state,
        DraftFromPoolMove(poolPieceId: state.pool.first.instanceId),
        rules: localRules,
      );

      state = _apply(
        engine,
        state,
        AttackUnitMove(
          attackerUnitId: attackerUnitId,
          targetUnitId: defenderUnitId,
        ),
        rules: localRules,
      );

      expect(state.winnerIndex, 0);
      expect(state.phase, TurnPhase.gameOver);
    });
  });
}

GameState _draftByDefinition(
  TurnEngine engine,
  GameState state,
  String definitionId, {
  MatchRules rules = const MatchRules(),
}) {
  final piece = state.pool.firstWhere(
    (entry) => entry.definition.id == definitionId,
  );
  return _apply(
    engine,
    state,
    DraftFromPoolMove(poolPieceId: piece.instanceId),
    rules: rules,
  );
}

GameState _apply(
  TurnEngine engine,
  GameState state,
  GameCommand command, {
  MatchRules rules = const MatchRules(),
}) {
  final result = engine.applyCommand(
    state,
    state.activePlayerIndex,
    command,
    rules: rules,
  );
  expect(result.applied, isTrue, reason: result.reason);
  return result.state;
}
