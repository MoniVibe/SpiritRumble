import 'package:puredots_turn_engine/puredots_turn_engine.dart';

import 'match_diagnostics.dart';

class BattleTelemetry {
  const BattleTelemetry({
    required this.appliedCommands,
    required this.deniedCommands,
    required this.attackDeclarations,
    required this.destroyedEvents,
    required this.directHitEvents,
    required this.appliedByType,
    required this.deniedByType,
  });

  final int appliedCommands;
  final int deniedCommands;
  final int attackDeclarations;
  final int destroyedEvents;
  final int directHitEvents;
  final Map<String, int> appliedByType;
  final Map<String, int> deniedByType;
}

class BattleViewState {
  const BattleViewState({
    required this.gameState,
    required this.selectedAttackerUnitId,
    required this.lastError,
    required this.telemetry,
    required this.recentDiagnostics,
    required this.diagnosticsPath,
  });

  final GameState gameState;
  final String? selectedAttackerUnitId;
  final String? lastError;
  final BattleTelemetry telemetry;
  final List<MatchDiagnosticsSnapshot> recentDiagnostics;
  final String diagnosticsPath;

  PlayerState get activePlayer => gameState.activePlayer;

  PlayerState get opposingPlayer => gameState.opposingPlayer;

  int? get winnerIndex => gameState.winnerIndex;

  bool get isDraftPhase => gameState.phase == TurnPhase.draftFromPool;

  bool get isAttackPhase => gameState.phase == TurnPhase.attackStep;

  bool get isMainPhase => gameState.phase == TurnPhase.mainActions;

  bool get isChooseDefendersPhase =>
      gameState.phase == TurnPhase.chooseDefenders;
}
