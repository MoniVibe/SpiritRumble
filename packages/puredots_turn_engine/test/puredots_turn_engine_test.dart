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
    poolSeed: 1234,
  );

  final catalog = <PieceDefinition>[
    const PieceDefinition(
      id: 'red_phys_mag',
      name: 'Red Duelist',
      element: SpiritElement.red,
      attackMode: CombatMode.physical,
      defenseMode: CombatMode.magical,
      attack: 3,
      defense: 2,
    ),
    const PieceDefinition(
      id: 'green_mag_mag',
      name: 'Green Oracle',
      element: SpiritElement.green,
      attackMode: CombatMode.magical,
      defenseMode: CombatMode.magical,
      attack: 2,
      defense: 3,
    ),
    const PieceDefinition(
      id: 'blue_mag_phys',
      name: 'Blue Guard',
      element: SpiritElement.blue,
      attackMode: CombatMode.magical,
      defenseMode: CombatMode.physical,
      attack: 2,
      defense: 3,
    ),
  ];

  group('TurnEngine rule v1.1', () {
    test('players start with 1 board totem, 3 in hand, and pool of 5', () {
      final state = engine.newMatch(draftCatalog: catalog, rules: rules);

      expect(state.players[0].units.length, 1);
      expect(state.players[1].units.length, 1);
      expect(state.players[0].totemsInHand, 3);
      expect(state.players[1].totemsInHand, 3);
      expect(state.pool.length, 5);
      expect(state.phase, TurnPhase.mainActions); // auto-skip attack if empty
    });

    test('pool refresh uses unique spirits and includes both mode types', () {
      final state = engine.newMatch(
        draftCatalog: canonicalPlaceholderCatalog,
        rules: rules,
      );

      final definitionIds = state.pool.map((p) => p.definition.id).toSet();
      final attackModes = state.pool.map((p) => p.definition.attackMode).toSet();
      final defenseModes = state.pool
          .map((p) => p.definition.defenseMode)
          .toSet();

      expect(definitionIds.length, 5);
      expect(attackModes, {CombatMode.physical, CombatMode.magical});
      expect(defenseModes, {CombatMode.physical, CombatMode.magical});
    });

    test('first turn allows binding only 1 spirit from pool', () {
      var state = engine.newMatch(draftCatalog: catalog, rules: rules);
      final unitId = state.activePlayer.units.first.unitId;

      state = _apply(
        engine,
        state,
        BindFromPoolMove(poolPieceId: state.pool.first.instanceId, unitId: unitId),
        rules: rules,
      );
      expect(state.activePlayer.units.first.pieces.length, 1);

      final denied = engine.applyCommand(
        state,
        state.activePlayerIndex,
        BindFromPoolMove(poolPieceId: state.pool.first.instanceId, unitId: unitId),
        rules: rules,
      );
      expect(denied.applied, isFalse);
      expect(denied.reason, contains('bind limit'));
    });

    test('later turns allow binding 2 spirits from pool', () {
      var state = engine.newMatch(draftCatalog: catalog, rules: rules);

      // Player 1: optional actions -> choose active spirit if needed -> handoff
      state = _apply(engine, state, EndTurnMove(), rules: rules); // main->def
      state = _apply(engine, state, EndTurnMove(), rules: rules); // def->handoff
      expect(state.activePlayerIndex, 1);
      expect(state.phase, TurnPhase.mainActions);

      final unitId = state.activePlayer.units.first.unitId;
      state = _apply(
        engine,
        state,
        BindFromPoolMove(poolPieceId: state.pool.first.instanceId, unitId: unitId),
        rules: rules,
      );
      state = _apply(
        engine,
        state,
        BindFromPoolMove(poolPieceId: state.pool.first.instanceId, unitId: unitId),
        rules: rules,
      );

      final deniedThird = engine.applyCommand(
        state,
        state.activePlayerIndex,
        BindFromPoolMove(poolPieceId: state.pool.first.instanceId, unitId: unitId),
        rules: rules,
      );
      expect(deniedThird.applied, isFalse);
      expect(deniedThird.reason, contains('bind limit'));
    });

    test('cannot end active-spirit phase until assigned on spirit-bearing totems', () {
      var state = engine.newMatch(draftCatalog: catalog, rules: rules);
      final unitId = state.activePlayer.units.first.unitId;

      state = _apply(
        engine,
        state,
        BindFromPoolMove(poolPieceId: state.pool.first.instanceId, unitId: unitId),
        rules: rules,
      );
      state = _apply(engine, state, EndTurnMove(), rules: rules); // main->def
      expect(state.phase, TurnPhase.chooseDefenders);

      final denied = engine.applyCommand(
        state,
        state.activePlayerIndex,
        EndTurnMove(),
        rules: rules,
      );
      expect(denied.applied, isFalse);
      expect(denied.reason, contains('active spirits'));

      state = _apply(
        engine,
        state,
        ChooseDefenderMove(unitId: unitId, pieceIndex: 0),
        rules: rules,
      );
      state = _apply(engine, state, EndTurnMove(), rules: rules);
      expect(state.activePlayerIndex, 1);
    });

    test('attack phase requires each spirit-bearing totem to attack once', () {
      final state = _stateWithAttackScenario(
        catalog: catalog,
        attacker: catalog[0],
        defender: catalog[1],
        defenderSelected: true,
      );

      final denied = engine.applyCommand(
        state,
        state.activePlayerIndex,
        EndTurnMove(),
        rules: rules,
      );
      expect(denied.applied, isFalse);
      expect(denied.reason, contains('must attack'));
    });

    test('totem with no active spirit is destroyed when attacked', () {
      final state = _stateWithAttackScenario(
        catalog: catalog,
        attacker: catalog[0],
        defender: catalog[1],
        defenderSelected: false,
      );

      final next = _apply(
        engine,
        state,
        AttackUnitMove(
          attackerUnitId: state.activePlayer.units.first.unitId,
          targetUnitId: state.opposingPlayer.units.first.unitId,
        ),
        rules: rules,
      );

      expect(next.phase, TurnPhase.gameOver);
      expect(next.winnerIndex, 0);
    });

    test('color or mode protection prevents destruction', () {
      final attacker = catalog[0]; // red physical
      final unprotected = catalog[1]; // green magical
      final protectedByColor = catalog[2]; // blue protects vs red
      final protectedByMode = const PieceDefinition(
        id: 'mode_guard',
        name: 'Mode Guard',
        element: SpiritElement.green,
        attackMode: CombatMode.magical,
        defenseMode: CombatMode.physical,
        attack: 1,
        defense: 1,
      );

      final kill = engine.resolveAttack(attacker: attacker, defender: unprotected);
      final colorSave = engine.resolveAttack(
        attacker: attacker,
        defender: protectedByColor,
      );
      final modeSave = engine.resolveAttack(
        attacker: attacker,
        defender: protectedByMode,
      );

      expect(kill.destroyed, isTrue);
      expect(colorSave.destroyed, isFalse);
      expect(modeSave.destroyed, isFalse);
    });

    test('player loses immediately when board has no totems', () {
      final state = _stateWithAttackScenario(
        catalog: catalog,
        attacker: catalog[0],
        defender: catalog[1],
        defenderSelected: false,
        attackerTotemsInHand: 3,
        defenderTotemsInHand: 3,
      );

      final next = _apply(
        engine,
        state,
        AttackUnitMove(
          attackerUnitId: state.activePlayer.units.first.unitId,
          targetUnitId: state.opposingPlayer.units.first.unitId,
        ),
        rules: rules,
      );
      expect(next.phase, TurnPhase.gameOver);
      expect(next.winnerIndex, 0);
    });
  });
}

GameState _stateWithAttackScenario({
  required List<PieceDefinition> catalog,
  required PieceDefinition attacker,
  required PieceDefinition defender,
  required bool defenderSelected,
  int attackerTotemsInHand = 2,
  int defenderTotemsInHand = 2,
}) {
  const engine = TurnEngine();
  const rules = MatchRules(
    poolSize: 5,
    firstPlayerOpeningDraft: 1,
    standardDraft: 2,
    startingTotemsOnField: 1,
    startingTotemsInHand: 3,
    poolSeed: 987,
  );

  var state = engine.newMatch(draftCatalog: catalog, rules: rules);

  final attackerUnit = state.players[0].units.first.copyWith(
    pieces: <PieceInstance>[
      PieceInstance(instanceId: 'atk-1', ownerIndex: 0, definition: attacker),
    ],
    attackingPieceIndex: 0,
    defendingPieceIndex: 0,
    attackedThisTurn: false,
    summonedTurn: 1,
  );

  final defenderUnit = state.players[1].units.first.copyWith(
    pieces: <PieceInstance>[
      PieceInstance(instanceId: 'def-1', ownerIndex: 1, definition: defender),
    ],
    attackingPieceIndex: 0,
    defendingPieceIndex: defenderSelected ? 0 : null,
    attackedThisTurn: false,
    summonedTurn: 1,
  );

  final p1 = state.players[0].copyWith(
    totemsInHand: attackerTotemsInHand,
    hand: const <PieceInstance>[],
    units: <UnitState>[attackerUnit],
    poolPicksThisTurn: 0,
  );
  final p2 = state.players[1].copyWith(
    totemsInHand: defenderTotemsInHand,
    hand: const <PieceInstance>[],
    units: <UnitState>[defenderUnit],
    poolPicksThisTurn: 0,
  );

  state = state.copyWith(
    turnNumber: 2,
    activePlayerIndex: 0,
    phase: TurnPhase.attackStep,
    players: <PlayerState>[p1, p2],
    clearPendingCombat: true,
    clearWinnerIndex: true,
  );

  return state;
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
