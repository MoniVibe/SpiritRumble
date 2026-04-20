import 'package:puredots_turn_engine/puredots_turn_engine.dart';

import '../domain/battle_defaults.dart';
import 'battle_view_state.dart';

class BattleController {
  BattleController({
    TurnEngine engine = const TurnEngine(),
    MatchRules rules = defaultBattleRules,
    List<PieceDefinition> catalog = defaultBattleCatalog,
  }) : _engine = engine,
       _rules = rules,
       _catalog = List<PieceDefinition>.from(catalog),
       _state = engine.newMatch(draftCatalog: catalog, rules: rules);

  final TurnEngine _engine;
  final MatchRules _rules;
  final List<PieceDefinition> _catalog;

  late GameState _state;
  String? _selectedAttackerUnitId;
  String? _lastError;

  BattleViewState get viewState => BattleViewState(
    gameState: _state,
    selectedAttackerUnitId: _selectedAttackerUnitId,
    lastError: _lastError,
  );

  void resetMatch() {
    _state = _engine.newMatch(draftCatalog: _catalog, rules: _rules);
    _selectedAttackerUnitId = null;
    _lastError = null;
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
    final result = _engine.applyCommand(
      _state,
      _state.activePlayerIndex,
      command,
      rules: _rules,
    );
    if (!result.applied) {
      _lastError = result.reason;
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
    return true;
  }

  void selectAttackerUnit(String? unitId) {
    _selectedAttackerUnitId = unitId;
  }
}
