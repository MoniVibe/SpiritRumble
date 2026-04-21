import 'package:puredots_turn_engine/puredots_turn_engine.dart';

class OpponentAi {
  const OpponentAi._();

  static GameCommand? pickNextCommand(
    GameState state,
    bool Function(GameCommand command) isAllowed,
  ) {
    switch (state.phase) {
      case TurnPhase.attackStep:
        return _pickAttack(state, isAllowed);
      case TurnPhase.mainActions:
        return _pickMainAction(state, isAllowed);
      case TurnPhase.chooseDefenders:
        return _pickDefender(state, isAllowed);
      case TurnPhase.draftFromPool:
      case TurnPhase.startTurn:
      case TurnPhase.resolveCombat:
      case TurnPhase.endTurn:
      case TurnPhase.gameOver:
        return null;
    }
  }

  static GameCommand? _pickAttack(
    GameState state,
    bool Function(GameCommand command) isAllowed,
  ) {
    final active = state.activePlayer;
    final enemy = state.opposingPlayer;

    for (final unit in active.units) {
      if (unit.pieces.isEmpty || unit.attackedThisTurn) {
        continue;
      }

      final bestAttackerIndex = _bestAttackIndex(unit);
      final chooseAttacker = ChooseAttackerMove(
        unitId: unit.unitId,
        pieceIndex: bestAttackerIndex,
      );
      if (isAllowed(chooseAttacker) &&
          unit.attackingPieceIndex != bestAttackerIndex) {
        return chooseAttacker;
      }

      for (final target in enemy.units) {
        final attack = AttackUnitMove(
          attackerUnitId: unit.unitId,
          targetUnitId: target.unitId,
        );
        if (isAllowed(attack)) {
          return attack;
        }
      }
    }

    final endAttack = EndTurnMove();
    if (isAllowed(endAttack)) {
      return endAttack;
    }
    return null;
  }

  static GameCommand? _pickMainAction(
    GameState state,
    bool Function(GameCommand command) isAllowed,
  ) {
    final active = state.activePlayer;
    final bindCap = _bindCapForTurn(state);

    if (active.poolPicksThisTurn < bindCap &&
        state.pool.isNotEmpty &&
        active.units.isNotEmpty) {
      final bestPoolSpirit = _bestPoolSpirit(state.pool);
      final targetUnit = _bestBindingTarget(active.units);
      final bind = BindFromPoolMove(
        poolPieceId: bestPoolSpirit.instanceId,
        unitId: targetUnit.unitId,
      );
      if (isAllowed(bind)) {
        return bind;
      }
    }

    if (active.totemsInHand > 0 && active.units.length < 6) {
      final summon = SummonTotemMove();
      if (isAllowed(summon)) {
        return summon;
      }
    }

    final endTurn = EndTurnMove();
    if (isAllowed(endTurn)) {
      return endTurn;
    }
    return null;
  }

  static GameCommand? _pickDefender(
    GameState state,
    bool Function(GameCommand command) isAllowed,
  ) {
    var needsAssignment = false;
    for (final unit in state.activePlayer.units) {
      if (unit.pieces.isEmpty) {
        continue;
      }
      final current = unit.defendingPieceIndex;
      if (current != null && current >= 0 && current < unit.pieces.length) {
        continue;
      }
      needsAssignment = true;
      final index = _bestDefenseIndex(unit);
      final command = ChooseDefenderMove(
        unitId: unit.unitId,
        pieceIndex: index,
      );
      if (isAllowed(command)) {
        return command;
      }
    }
    if (!needsAssignment) {
      final validate = EndTurnMove();
      if (isAllowed(validate)) {
        return validate;
      }
    }
    return null;
  }

  static int _bindCapForTurn(GameState state) {
    return state.turnNumber == 1 && state.activePlayerIndex == 0 ? 1 : 2;
  }

  static UnitState _bestBindingTarget(List<UnitState> units) {
    final sorted = List<UnitState>.from(units)
      ..sort((a, b) => a.pieces.length.compareTo(b.pieces.length));
    return sorted.first;
  }

  static PieceInstance _bestPoolSpirit(List<PieceInstance> pool) {
    final sorted = List<PieceInstance>.from(pool)
      ..sort(
        (a, b) => (b.definition.attack + b.definition.defense).compareTo(
          a.definition.attack + a.definition.defense,
        ),
      );
    return sorted.first;
  }

  static int _bestAttackIndex(UnitState unit) {
    var bestIndex = 0;
    var bestAttack = unit.pieces.first.definition.attack;
    for (var i = 1; i < unit.pieces.length; i++) {
      final attack = unit.pieces[i].definition.attack;
      if (attack > bestAttack) {
        bestAttack = attack;
        bestIndex = i;
      }
    }
    return bestIndex;
  }

  static int _bestDefenseIndex(UnitState unit) {
    var bestIndex = 0;
    var bestDefense = unit.pieces.first.definition.defense;
    for (var i = 1; i < unit.pieces.length; i++) {
      final defense = unit.pieces[i].definition.defense;
      if (defense > bestDefense) {
        bestDefense = defense;
        bestIndex = i;
      }
    }
    return bestIndex;
  }
}

