import 'package:puredots_turn_engine/puredots_turn_engine.dart';

class BattleViewState {
  const BattleViewState({
    required this.gameState,
    required this.selectedAttackerUnitId,
    required this.lastError,
  });

  final GameState gameState;
  final String? selectedAttackerUnitId;
  final String? lastError;

  PlayerState get activePlayer => gameState.activePlayer;

  PlayerState get opposingPlayer => gameState.opposingPlayer;

  int? get winnerIndex => gameState.winnerIndex;

  bool get isDraftPhase => gameState.phase == TurnPhase.draftFromPool;

  bool get isMainPhase => gameState.phase == TurnPhase.mainActions;

  bool get isChooseDefendersPhase =>
      gameState.phase == TurnPhase.chooseDefenders;
}
