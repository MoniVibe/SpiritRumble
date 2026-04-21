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

  group('TurnEngine rule v1', () {
    test('players start with one totem on field and three in hand', () {
      final state = engine.newMatch(draftCatalog: catalog, rules: rules);

      expect(state.players[0].units.length, 1);
      expect(state.players[1].units.length, 1);
      expect(state.players[0].totemsInHand, 3);
      expect(state.players[1].totemsInHand, 3);
      expect(state.pool.length, 5);
      expect(state.phase, TurnPhase.draftFromPool);
    });

    test('turn 1 drafts 1 spirit then enters attack step', () {
      var state = engine.newMatch(draftCatalog: catalog, rules: rules);

      state = _apply(
        engine,
        state,
        DraftFromPoolMove(poolPieceId: state.pool.first.instanceId),
        rules: rules,
      );

      expect(state.activePlayer.hand.length, 1);
      expect(state.phase, TurnPhase.attackStep);
    });

    test('later turns draft 2 spirits', () {
      var state = engine.newMatch(draftCatalog: catalog, rules: rules);
      state = _apply(
        engine,
        state,
        DraftFromPoolMove(poolPieceId: state.pool.first.instanceId),
        rules: rules,
      );
      state = _apply(
        engine,
        state,
        EndTurnMove(),
        rules: rules,
      ); // attack->main
      state = _apply(engine, state, EndTurnMove(), rules: rules); // main->def
      state = _apply(
        engine,
        state,
        EndTurnMove(),
        rules: rules,
      ); // def->handoff

      expect(state.activePlayerIndex, 1);
      expect(state.phase, TurnPhase.draftFromPool);

      state = _apply(
        engine,
        state,
        DraftFromPoolMove(poolPieceId: state.pool.first.instanceId),
        rules: rules,
      );
      expect(state.phase, TurnPhase.draftFromPool);
      state = _apply(
        engine,
        state,
        DraftFromPoolMove(poolPieceId: state.pool.first.instanceId),
        rules: rules,
      );

      expect(state.phase, TurnPhase.attackStep);
      expect(state.activePlayer.hand.length, 2);
    });

    test('can summon totem and bind spirit during main actions', () {
      const localRules = MatchRules(
        poolSize: 5,
        firstPlayerOpeningDraft: 1,
        standardDraft: 1,
        startingTotemsOnField: 1,
        startingTotemsInHand: 3,
        poolSeed: 77,
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
        EndTurnMove(),
        rules: localRules,
      ); // to main

      state = _apply(engine, state, SummonTotemMove(), rules: localRules);
      expect(state.activePlayer.units.length, 2);
      expect(state.activePlayer.totemsInHand, 2);

      final unitId = state.activePlayer.units.first.unitId;
      final spiritId = state.activePlayer.hand.first.instanceId;
      state = _apply(
        engine,
        state,
        AddToExistingUnitMove(handPieceId: spiritId, unitId: unitId),
        rules: localRules,
      );

      expect(state.activePlayer.hand, isEmpty);
      expect(state.activePlayer.units.first.pieces.length, 1);
    });

    test('attack step cannot be ended while mandatory attacks remain', () {
      final state = _stateWithAttackScenario(
        catalog: catalog,
        attacker: catalog[0],
        defender: catalog[1],
        defenderSelected: true,
      );

      final endResult = engine.applyCommand(
        state,
        state.activePlayerIndex,
        EndTurnMove(),
      );

      expect(endResult.applied, isFalse);
      expect(endResult.reason, contains('must attack'));
    });

    test('only totems with selected defenders can be targeted', () {
      final state = _stateWithAttackScenario(
        catalog: catalog,
        attacker: catalog[0],
        defender: catalog[1],
        defenderSelected: false,
      );

      final attackResult = engine.applyCommand(
        state,
        state.activePlayerIndex,
        AttackUnitMove(
          attackerUnitId: state.activePlayer.units.first.unitId,
          targetUnitId: state.opposingPlayer.units.first.unitId,
        ),
      );

      expect(attackResult.applied, isFalse);
      expect(attackResult.reason, contains('no defending spirit selected'));
    });

    test('direct attacks are not allowed in rule v1', () {
      final state = _stateWithAttackScenario(
        catalog: catalog,
        attacker: catalog[0],
        defender: catalog[1],
        defenderSelected: true,
      );

      final direct = engine.applyCommand(
        state,
        state.activePlayerIndex,
        AttackUnitMove(attackerUnitId: state.activePlayer.units.first.unitId),
      );

      expect(direct.applied, isFalse);
      expect(direct.reason, contains('target an enemy totem'));
    });

    test('combat destroys totem only when defender has no protection', () {
      final attacker = catalog[0]; // red physical
      final unprotected =
          catalog[1]; // green magical (no color/mode protection)
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

      final kill = engine.resolveAttack(
        attacker: attacker,
        defender: unprotected,
      );
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

    test('player loses when all totems are gone (field + hand)', () {
      final state = _stateWithAttackScenario(
        catalog: catalog,
        attacker: catalog[0],
        defender: catalog[1],
        defenderSelected: true,
        attackerTotemsInHand: 0,
        defenderTotemsInHand: 0,
      );

      final next = _apply(
        engine,
        state,
        AttackUnitMove(
          attackerUnitId: state.activePlayer.units.first.unitId,
          targetUnitId: state.opposingPlayer.units.first.unitId,
        ),
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
  );
  final p2 = state.players[1].copyWith(
    totemsInHand: defenderTotemsInHand,
    hand: const <PieceInstance>[],
    units: <UnitState>[defenderUnit],
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
