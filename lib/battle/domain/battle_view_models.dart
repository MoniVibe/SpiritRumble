import 'package:puredots_turn_engine/puredots_turn_engine.dart';

String phaseLabel(TurnPhase phase) {
  switch (phase) {
    case TurnPhase.startTurn:
      return 'Start';
    case TurnPhase.draftFromPool:
      return 'Draft';
    case TurnPhase.attackStep:
      return 'Attack';
    case TurnPhase.mainActions:
      return 'Action';
    case TurnPhase.resolveCombat:
      return 'Combat';
    case TurnPhase.chooseDefenders:
      return 'Active Spirits';
    case TurnPhase.endTurn:
      return 'End';
    case TurnPhase.gameOver:
      return 'Game Over';
  }
}

String pieceLabel(PieceDefinition piece) {
  return '${piece.name}\n${elementLabel(piece.element)} '
      'ATK ${piece.attack}/${modeLabel(piece.attackMode)} '
      'DEF ${piece.defense}/${modeLabel(piece.defenseMode)}';
}

String modeLabel(CombatMode mode) {
  switch (mode) {
    case CombatMode.physical:
      return 'PHY';
    case CombatMode.magical:
      return 'MAG';
  }
}

String elementLabel(SpiritElement element) {
  switch (element) {
    case SpiritElement.red:
      return 'RED';
    case SpiritElement.green:
      return 'GREEN';
    case SpiritElement.blue:
      return 'BLUE';
  }
}
