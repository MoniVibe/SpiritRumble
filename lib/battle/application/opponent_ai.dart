import 'package:puredots_turn_engine/puredots_turn_engine.dart';

class OpponentAi {
  const OpponentAi._();

  static GameCommand? pickNextCommand(
    GameState state,
    bool Function(GameCommand command) isAllowed,
  ) {
    switch (state.phase) {
      case TurnPhase.draftFromPool:
        return _pickDraft(state, isAllowed);
      case TurnPhase.mainActions:
        return _pickMainAction(state, isAllowed);
      case TurnPhase.chooseDefenders:
        return _pickDefender(state, isAllowed);
      case TurnPhase.startTurn:
      case TurnPhase.resolveCombat:
      case TurnPhase.endTurn:
      case TurnPhase.gameOver:
        return null;
    }
  }

  static GameCommand? _pickDraft(
    GameState state,
    bool Function(GameCommand command) isAllowed,
  ) {
    final sorted = List<PieceInstance>.from(state.pool)
      ..sort(
        (a, b) => (b.definition.attack + b.definition.defense).compareTo(
          a.definition.attack + a.definition.defense,
        ),
      );
    for (final piece in sorted) {
      final command = DraftFromPoolMove(poolPieceId: piece.instanceId);
      if (isAllowed(command)) {
        return command;
      }
    }
    return null;
  }

  static GameCommand? _pickMainAction(
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

      if (enemy.units.isEmpty) {
        final direct = AttackUnitMove(attackerUnitId: unit.unitId);
        if (isAllowed(direct)) {
          return direct;
        }
        continue;
      }

      final sortedTargets = List<UnitState>.from(enemy.units)
        ..sort(
          (a, b) => _unitDefenderDefense(a).compareTo(_unitDefenderDefense(b)),
        );
      for (final target in sortedTargets) {
        final attack = AttackUnitMove(
          attackerUnitId: unit.unitId,
          targetUnitId: target.unitId,
        );
        if (isAllowed(attack)) {
          return attack;
        }
      }
    }

    if (active.hand.isNotEmpty) {
      final bestHandPiece = _bestHandPiece(active.hand);

      final playNew = PlayToNewUnitMove(handPieceId: bestHandPiece.instanceId);
      if (isAllowed(playNew)) {
        return playNew;
      }

      final sortedUnits = List<UnitState>.from(active.units)
        ..sort((a, b) => a.pieces.length.compareTo(b.pieces.length));
      for (final unit in sortedUnits) {
        final add = AddToExistingUnitMove(
          handPieceId: bestHandPiece.instanceId,
          unitId: unit.unitId,
        );
        if (isAllowed(add)) {
          return add;
        }
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
    for (final unit in state.activePlayer.units) {
      if (unit.pieces.isEmpty) {
        continue;
      }
      final current = unit.defendingPieceIndex;
      if (current != null && current >= 0 && current < unit.pieces.length) {
        continue;
      }
      final index = _bestDefenseIndex(unit);
      final command = ChooseDefenderMove(
        unitId: unit.unitId,
        pieceIndex: index,
      );
      if (isAllowed(command)) {
        return command;
      }
    }
    return null;
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

  static int _unitDefenderDefense(UnitState unit) {
    if (unit.pieces.isEmpty) {
      return 0;
    }
    final index =
        (unit.defendingPieceIndex != null &&
            unit.defendingPieceIndex! >= 0 &&
            unit.defendingPieceIndex! < unit.pieces.length)
        ? unit.defendingPieceIndex!
        : 0;
    return unit.pieces[index].definition.defense;
  }

  static PieceInstance _bestHandPiece(List<PieceInstance> hand) {
    final sorted = List<PieceInstance>.from(hand)
      ..sort(
        (a, b) => (b.definition.attack + b.definition.defense).compareTo(
          a.definition.attack + a.definition.defense,
        ),
      );
    return sorted.first;
  }
}
