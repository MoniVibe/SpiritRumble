import 'package:puredots_turn_engine/puredots_turn_engine.dart';

import '../domain/battle_defaults.dart';
import 'battle_view_state.dart';
import 'match_diagnostics.dart';

class BattleController {
  BattleController({
    TurnEngine engine = const TurnEngine(),
    MatchRules rules = defaultBattleRules,
    List<PieceDefinition>? catalog,
    MatchDiagnosticsStore? diagnosticsStore,
  }) : _engine = engine,
       _rules = rules,
       _catalog = List<PieceDefinition>.from(catalog ?? defaultBattleCatalog),
       _diagnosticsStore = diagnosticsStore ?? MatchDiagnosticsStore(),
       _state = engine.newMatch(
         draftCatalog: catalog ?? defaultBattleCatalog,
         rules: rules,
       ) {
    _recentDiagnostics = _diagnosticsStore.loadRecent();
  }

  final TurnEngine _engine;
  final MatchRules _rules;
  final List<PieceDefinition> _catalog;
  final MatchDiagnosticsStore _diagnosticsStore;

  late GameState _state;
  List<MatchDiagnosticsSnapshot> _recentDiagnostics =
      const <MatchDiagnosticsSnapshot>[];
  String? _selectedAttackerUnitId;
  String? _lastError;
  int _deniedCommandCount = 0;
  final Map<String, int> _deniedByType = <String, int>{};
  final Map<String, int> _deniedByReason = <String, int>{};
  bool _persistedCurrentMatch = false;

  BattleViewState get viewState => BattleViewState(
    gameState: _state,
    selectedAttackerUnitId: _selectedAttackerUnitId,
    lastError: _lastError,
    telemetry: _buildTelemetry(),
    recentDiagnostics: _recentDiagnostics,
    diagnosticsPath: _diagnosticsStore.filePath,
  );

  void resetMatch() {
    _state = _engine.newMatch(draftCatalog: _catalog, rules: _rules);
    _selectedAttackerUnitId = null;
    _lastError = null;
    _deniedCommandCount = 0;
    _deniedByType.clear();
    _deniedByReason.clear();
    _persistedCurrentMatch = false;
  }

  CommandCheck canApply(GameCommand command) {
    return _engine.canApply(
      _state,
      _state.activePlayerIndex,
      command,
      rules: _rules,
    );
  }

  bool dispatch(GameCommand command) {
    final hadWinnerBefore = _state.hasWinner;
    final result = _engine.applyCommand(
      _state,
      _state.activePlayerIndex,
      command,
      rules: _rules,
    );
    if (!result.applied) {
      _lastError = result.reason;
      _deniedCommandCount++;
      _deniedByType.update(
        command.type,
        (value) => value + 1,
        ifAbsent: () => 1,
      );
      if (result.reason != null && result.reason!.isNotEmpty) {
        _deniedByReason.update(
          result.reason!,
          (value) => value + 1,
          ifAbsent: () => 1,
        );
      }
      return false;
    }

    _state = result.state;
    _lastError = null;
    if (_selectedAttackerUnitId != null &&
        !_state.activePlayer.units.any(
          (u) => u.unitId == _selectedAttackerUnitId,
        )) {
      _selectedAttackerUnitId = null;
    }
    if (!hadWinnerBefore && _state.hasWinner && !_persistedCurrentMatch) {
      _recentDiagnostics = _diagnosticsStore.saveFinishedMatch(
        state: _state,
        deniedCommands: _deniedCommandCount,
        deniedByType: _deniedByType,
        deniedByReason: _deniedByReason,
      );
      _persistedCurrentMatch = true;
    }
    return true;
  }

  void selectAttackerUnit(String? unitId) {
    _selectedAttackerUnitId = unitId;
  }

  BattleTelemetry _buildTelemetry() {
    final appliedByType = <String, int>{};
    for (final entry in _state.history) {
      appliedByType.update(
        entry.commandType,
        (value) => value + 1,
        ifAbsent: () => 1,
      );
    }
    return BattleTelemetry(
      appliedCommands: _state.history.length,
      deniedCommands: _deniedCommandCount,
      attackDeclarations: _state.eventLog
          .where((line) => line.contains('declared an attack'))
          .length,
      destroyedEvents: _state.eventLog
          .where((line) => line.contains(' destroyed '))
          .length,
      directHitEvents: _state.eventLog
          .where((line) => line.contains(' directly for '))
          .length,
      appliedByType: appliedByType,
      deniedByType: Map<String, int>.from(_deniedByType),
    );
  }
}
