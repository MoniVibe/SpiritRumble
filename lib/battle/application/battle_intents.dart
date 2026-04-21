import 'package:puredots_turn_engine/puredots_turn_engine.dart';

class BattleIntents {
  const BattleIntents._();

  static DraftFromPoolMove draftFromPool(String pieceId) =>
      DraftFromPoolMove(poolPieceId: pieceId);

  static BindFromPoolMove bindFromPool(String pieceId, String unitId) =>
      BindFromPoolMove(poolPieceId: pieceId, unitId: unitId);

  static SummonTotemMove summonTotem() => SummonTotemMove();

  static PlayToNewUnitMove playToNewUnit(String handPieceId) =>
      PlayToNewUnitMove(handPieceId: handPieceId);

  static AddToExistingUnitMove addToUnit(String handPieceId, String unitId) =>
      AddToExistingUnitMove(handPieceId: handPieceId, unitId: unitId);

  static ChooseAttackerMove chooseAttacker(String unitId, int pieceIndex) =>
      ChooseAttackerMove(unitId: unitId, pieceIndex: pieceIndex);

  static AttackUnitMove attack(String attackerUnitId, {String? targetUnitId}) =>
      AttackUnitMove(
        attackerUnitId: attackerUnitId,
        targetUnitId: targetUnitId,
      );

  static ChooseDefenderMove chooseDefender(String unitId, int pieceIndex) =>
      ChooseDefenderMove(unitId: unitId, pieceIndex: pieceIndex);

  static EndTurnMove endTurn() => EndTurnMove();
}
