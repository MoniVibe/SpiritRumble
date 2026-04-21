import 'models.dart';

class ApplyCommandResult {
  const ApplyCommandResult({
    required this.state,
    required this.applied,
    this.reason,
  });

  final GameState state;
  final bool applied;
  final String? reason;
}

class TurnEngine {
  const TurnEngine();

  GameState newMatch({
    required List<PieceDefinition> draftCatalog,
    MatchRules rules = const MatchRules(),
    int players = 2,
  }) {
    if (players != 2) {
      throw ArgumentError.value(
        players,
        'players',
        'only 2 players are currently supported',
      );
    }
    if (draftCatalog.isEmpty) {
      throw ArgumentError.value(
        draftCatalog,
        'draftCatalog',
        'must contain at least one piece definition',
      );
    }

    var nextUnitId = 1;
    List<UnitState> startingTotemsFor(int ownerIndex) {
      final units = <UnitState>[];
      for (var i = 0; i < rules.startingTotemsOnField; i++) {
        units.add(
          UnitState(
            unitId: 'u$nextUnitId',
            ownerIndex: ownerIndex,
            pieces: const <PieceInstance>[],
            summonedTurn: 0,
            attackingPieceIndex: null,
            defendingPieceIndex: null,
            attackedThisTurn: false,
          ),
        );
        nextUnitId++;
      }
      return units;
    }

    var state = GameState(
      turnNumber: 1,
      activePlayerIndex: 0,
      phase: TurnPhase.startTurn,
      players: <PlayerState>[
        PlayerState(
          id: 'Shaman 1',
          health: rules.startingHealth,
          totemsInHand: rules.startingTotemsInHand,
          hand: const <PieceInstance>[],
          units: startingTotemsFor(0),
          turnsTaken: 0,
          poolPicksThisTurn: 0,
          hadUnitsEver: rules.startingTotemsOnField > 0,
        ),
        PlayerState(
          id: 'Shaman 2',
          health: rules.startingHealth,
          totemsInHand: rules.startingTotemsInHand,
          hand: const <PieceInstance>[],
          units: startingTotemsFor(1),
          turnsTaken: 0,
          poolPicksThisTurn: 0,
          hadUnitsEver: rules.startingTotemsOnField > 0,
        ),
      ],
      pool: const <PieceInstance>[],
      draftCatalog: List<PieceDefinition>.from(draftCatalog),
      catalogCursor: rules.poolSeed,
      pendingCombat: null,
      winnerIndex: null,
      nextPieceInstanceId: 1,
      nextUnitId: nextUnitId,
      history: const <CommandLogEntry>[],
      eventLog: const <String>['Match created'],
    );

    state = _refreshPool(state, rules: rules);
    return _beginTurn(state, rules: rules);
  }

  CommandCheck canApply(
    GameState state,
    int actorIndex,
    GameCommand command, {
    MatchRules rules = const MatchRules(),
  }) {
    if (state.phase == TurnPhase.gameOver || state.hasWinner) {
      return const CommandCheck.denied('game is already over');
    }
    if (actorIndex != state.activePlayerIndex) {
      return const CommandCheck.denied('only the active player may act');
    }

    switch (command) {
      case BindFromPoolMove _:
        return _canApplyBindFromPool(state, command, rules: rules);
      case DraftFromPoolMove _:
        return const CommandCheck.denied(
          'draft phase was removed; use bind_from_pool in action phase',
        );
      case SummonTotemMove _:
        return _canApplySummonTotem(state);
      case PlayToNewUnitMove _:
        return const CommandCheck.denied(
          'play_to_new_unit is not used in the current rule set',
        );
      case AddToExistingUnitMove _:
        return const CommandCheck.denied(
          'add_to_existing_unit is not used in the current rule set',
        );
      case ChooseAttackerMove _:
        return _canApplyChooseAttacker(state, command);
      case AttackUnitMove _:
        return _canApplyAttackUnit(state, command);
      case ChooseDefenderMove _:
        return _canApplyChooseDefender(state, command);
      case EndTurnMove _:
        return _canApplyEndTurn(state);
      default:
        return const CommandCheck.denied('unknown command');
    }
  }

  ApplyCommandResult applyCommand(
    GameState state,
    int actorIndex,
    GameCommand command, {
    MatchRules rules = const MatchRules(),
  }) {
    final check = canApply(state, actorIndex, command, rules: rules);
    if (!check.allowed) {
      return ApplyCommandResult(
        state: state,
        applied: false,
        reason: check.reason,
      );
    }

    var next = state;
    switch (command) {
      case BindFromPoolMove _:
        next = _applyBindFromPool(next, command);
      case DraftFromPoolMove _:
        return ApplyCommandResult(
          state: state,
          applied: false,
          reason: 'draft phase was removed; use bind_from_pool',
        );
      case SummonTotemMove _:
        next = _applySummonTotem(next);
      case PlayToNewUnitMove _:
        return ApplyCommandResult(
          state: state,
          applied: false,
          reason: 'play_to_new_unit is not used in the current rule set',
        );
      case AddToExistingUnitMove _:
        return ApplyCommandResult(
          state: state,
          applied: false,
          reason: 'add_to_existing_unit is not used in the current rule set',
        );
      case ChooseAttackerMove _:
        next = _applyChooseAttacker(next, command);
      case AttackUnitMove _:
        next = _applyAttackUnit(next, command);
      case ChooseDefenderMove _:
        next = _applyChooseDefender(next, command);
      case EndTurnMove _:
        next = _applyEndTurn(next, rules: rules);
    }

    next = _appendHistory(next, actorIndex, command);
    return ApplyCommandResult(state: next, applied: true);
  }

  CombatResult resolveAttack({
    required PieceDefinition attacker,
    required PieceDefinition defender,
  }) {
    final defenderColorProtected = _isColorProtected(
      defenderElement: defender.element,
      attackerElement: attacker.element,
    );
    final defenderModeProtected = _isModeProtected(
      defenderDefenseMode: defender.defenseMode,
      attackerAttackMode: attacker.attackMode,
    );

    final elementAdvantage = !defenderColorProtected;
    final modeAdvantage = !defenderModeProtected;
    final powerAdvantage = true;
    final destroyed = elementAdvantage && modeAdvantage;

    final reason =
        'defenderColorProtected=${defenderColorProtected ? 'yes' : 'no'}, '
        'defenderModeProtected=${defenderModeProtected ? 'yes' : 'no'}';

    return CombatResult(
      attackerPieceId: attacker.id,
      defenderPieceId: defender.id,
      elementAdvantage: elementAdvantage,
      modeAdvantage: modeAdvantage,
      powerAdvantage: powerAdvantage,
      destroyed: destroyed,
      reason: reason,
    );
  }

  CommandCheck _canApplyBindFromPool(
    GameState state,
    BindFromPoolMove command, {
    required MatchRules rules,
  }) {
    if (state.phase != TurnPhase.mainActions) {
      return const CommandCheck.denied('not in main actions phase');
    }
    if (_findPoolIndex(state, command.poolPieceId) == -1) {
      return const CommandCheck.denied('requested spirit is not in pool');
    }
    if (_findUnitIndex(state.activePlayer, command.unitId) == -1) {
      return const CommandCheck.denied('target totem does not exist');
    }
    final cap = _requiredPoolBindsThisTurn(state, rules: rules);
    if (state.activePlayer.poolPicksThisTurn >= cap) {
      return const CommandCheck.denied('spirit bind limit reached for this turn');
    }
    return const CommandCheck.allowed();
  }

  CommandCheck _canApplySummonTotem(GameState state) {
    if (state.phase != TurnPhase.mainActions) {
      return const CommandCheck.denied('not in main actions phase');
    }
    if (state.activePlayer.totemsInHand <= 0) {
      return const CommandCheck.denied('no totems left in hand');
    }
    return const CommandCheck.allowed();
  }

  CommandCheck _canApplyChooseAttacker(
    GameState state,
    ChooseAttackerMove command,
  ) {
    if (state.phase != TurnPhase.attackStep) {
      return const CommandCheck.denied('not in attack step');
    }
    final unitIndex = _findUnitIndex(state.activePlayer, command.unitId);
    if (unitIndex == -1) {
      return const CommandCheck.denied('totem not found');
    }
    final unit = state.activePlayer.units[unitIndex];
    if (command.pieceIndex < 0 || command.pieceIndex >= unit.pieces.length) {
      return const CommandCheck.denied('attacker index out of range');
    }
    return const CommandCheck.allowed();
  }

  CommandCheck _canApplyAttackUnit(GameState state, AttackUnitMove command) {
    if (state.phase != TurnPhase.attackStep) {
      return const CommandCheck.denied('not in attack step');
    }

    final attackerUnitIndex = _findUnitIndex(
      state.activePlayer,
      command.attackerUnitId,
    );
    if (attackerUnitIndex == -1) {
      return const CommandCheck.denied('attacking totem not found');
    }

    final attackerUnit = state.activePlayer.units[attackerUnitIndex];
    if (!_canUnitAttackThisStep(attackerUnit)) {
      return const CommandCheck.denied('selected totem cannot attack now');
    }
    if (attackerUnit.attackingPieceIndex == null) {
      return const CommandCheck.denied('attacking spirit has not been chosen');
    }

    if (command.targetUnitId == null) {
      return const CommandCheck.denied('attacks must target an enemy totem');
    }
    final targetIndex = _findUnitIndex(
      state.opposingPlayer,
      command.targetUnitId!,
    );
    if (targetIndex == -1) {
      return const CommandCheck.denied('target totem not found');
    }
    return const CommandCheck.allowed();
  }

  CommandCheck _canApplyChooseDefender(
    GameState state,
    ChooseDefenderMove command,
  ) {
    if (state.phase != TurnPhase.chooseDefenders) {
      return const CommandCheck.denied('not in choose defenders phase');
    }
    final unitIndex = _findUnitIndex(state.activePlayer, command.unitId);
    if (unitIndex == -1) {
      return const CommandCheck.denied('totem not found');
    }
    final unit = state.activePlayer.units[unitIndex];
    if (unit.pieces.isEmpty) {
      return const CommandCheck.denied('cannot choose active spirit for empty totem');
    }
    if (command.pieceIndex < 0 || command.pieceIndex >= unit.pieces.length) {
      return const CommandCheck.denied('defender index out of range');
    }
    return const CommandCheck.allowed();
  }

  CommandCheck _canApplyEndTurn(GameState state) {
    if (state.phase == TurnPhase.attackStep) {
      if (_hasPendingMandatoryAttacks(state)) {
        return const CommandCheck.denied(
          'all attack-ready totems must attack before ending attack phase',
        );
      }
      return const CommandCheck.allowed();
    }
    if (state.phase == TurnPhase.mainActions) {
      return const CommandCheck.allowed();
    }
    if (state.phase == TurnPhase.chooseDefenders) {
      if (!_allActiveSpiritsAssignedForSpiritTotems(state.activePlayer)) {
        return const CommandCheck.denied(
          'choose active spirits for all totems with bound spirits',
        );
      }
      return const CommandCheck.allowed();
    }
    return const CommandCheck.denied(
      'end turn is only valid in attack, action, or active-spirit phase',
    );
  }

  GameState _applyBindFromPool(GameState state, BindFromPoolMove command) {
    final pool = List<PieceInstance>.from(state.pool);
    final poolIndex = _findPoolIndex(state, command.poolPieceId);
    final spirit = pool
        .removeAt(poolIndex)
        .copyWith(ownerIndex: state.activePlayerIndex);

    final active = state.activePlayer;
    final unitIndex = _findUnitIndex(active, command.unitId);
    final units = List<UnitState>.from(active.units);
    final unit = units[unitIndex];
    final pieces = List<PieceInstance>.from(unit.pieces)..add(spirit);

    units[unitIndex] = unit.copyWith(
      pieces: pieces,
      attackingPieceIndex: unit.attackingPieceIndex ?? 0,
    );

    var next = _replacePlayer(
      state.copyWith(pool: pool),
      state.activePlayerIndex,
      active.copyWith(
        units: units,
        poolPicksThisTurn: active.poolPicksThisTurn + 1,
      ),
    );

    return _appendEvent(
      next,
      '${active.id} bound ${spirit.definition.name} from pool to ${unit.unitId}.',
    );
  }

  GameState _applySummonTotem(GameState state) {
    final active = state.activePlayer;
    final units = List<UnitState>.from(active.units)
      ..add(
        UnitState(
          unitId: 'u${state.nextUnitId}',
          ownerIndex: state.activePlayerIndex,
          pieces: const <PieceInstance>[],
          summonedTurn: state.turnNumber,
          attackingPieceIndex: null,
          defendingPieceIndex: null,
          attackedThisTurn: false,
        ),
      );

    var next = state.copyWith(nextUnitId: state.nextUnitId + 1);
    next = _replacePlayer(
      next,
      state.activePlayerIndex,
      active.copyWith(
        totemsInHand: active.totemsInHand - 1,
        units: units,
        hadUnitsEver: true,
      ),
    );

    return _appendEvent(next, '${active.id} summoned a totem to the field.');
  }

  GameState _applyChooseAttacker(GameState state, ChooseAttackerMove command) {
    final active = state.activePlayer;
    final unitIndex = _findUnitIndex(active, command.unitId);
    final units = List<UnitState>.from(active.units);
    units[unitIndex] = units[unitIndex].copyWith(
      attackingPieceIndex: command.pieceIndex,
    );

    final next = _replacePlayer(
      state,
      state.activePlayerIndex,
      active.copyWith(units: units),
    );
    return _appendEvent(
      next,
      '${active.id} selected attacker spirit ${command.pieceIndex} in ${command.unitId}.',
    );
  }

  GameState _applyAttackUnit(GameState state, AttackUnitMove command) {
    final active = state.activePlayer;
    final attackerUnitIndex = _findUnitIndex(active, command.attackerUnitId);
    final attackerUnit = active.units[attackerUnitIndex];
    final pending = PendingCombat(
      attackerPlayerIndex: state.activePlayerIndex,
      attackerUnitId: attackerUnit.unitId,
      attackerPieceIndex: attackerUnit.attackingPieceIndex!,
      targetUnitId: command.targetUnitId,
    );

    var next = state.copyWith(
      phase: TurnPhase.resolveCombat,
      pendingCombat: pending,
    );
    next = _appendEvent(
      next,
      '${active.id} declared an attack with ${attackerUnit.unitId}.',
    );
    return _resolvePendingCombat(next);
  }

  GameState _applyChooseDefender(GameState state, ChooseDefenderMove command) {
    final active = state.activePlayer;
    final unitIndex = _findUnitIndex(active, command.unitId);
    final units = List<UnitState>.from(active.units);
    units[unitIndex] = units[unitIndex].copyWith(
      defendingPieceIndex: command.pieceIndex,
    );

    final next = _replacePlayer(
      state,
      state.activePlayerIndex,
      active.copyWith(units: units),
    );
    return _appendEvent(
      next,
      '${active.id} set active spirit ${command.pieceIndex} for ${command.unitId}.',
    );
  }

  GameState _applyEndTurn(GameState state, {required MatchRules rules}) {
    if (state.phase == TurnPhase.attackStep) {
      var next = state.copyWith(phase: TurnPhase.mainActions);
      next = _appendEvent(next, '${state.activePlayer.id} completed attack phase.');
      return next;
    }

    if (state.phase == TurnPhase.mainActions) {
      var next = state.copyWith(phase: TurnPhase.chooseDefenders);
      next = _appendEvent(next, '${state.activePlayer.id} entered active spirit assignment.');
      return next;
    }

    if (state.phase == TurnPhase.chooseDefenders) {
      var next = _appendEvent(
        state,
        '${state.activePlayer.id} completed active spirit assignment.',
      );
      return _handoffTurn(next, rules: rules);
    }

    return state;
  }

  GameState _handoffTurn(GameState state, {required MatchRules rules}) {
    final outgoingIndex = state.activePlayerIndex;
    final outgoing = state.players[outgoingIndex];

    var next = _replacePlayer(
      state,
      outgoingIndex,
      outgoing.copyWith(turnsTaken: outgoing.turnsTaken + 1),
    );

    next = next.copyWith(
      turnNumber: next.turnNumber + 1,
      activePlayerIndex: next.opposingPlayerIndex,
      phase: TurnPhase.startTurn,
      clearPendingCombat: true,
    );

    next = _refreshPool(next, rules: rules);
    return _beginTurn(next, rules: rules);
  }

  GameState _beginTurn(GameState state, {required MatchRules rules}) {
    final activeIndex = state.activePlayerIndex;
    final active = state.activePlayer;
    final opposing = state.opposingPlayer;

    if (active.units.isEmpty) {
      final winner = state.opposingPlayerIndex;
      var next = state.copyWith(phase: TurnPhase.gameOver, winnerIndex: winner);
      next = _appendEvent(next, 'Winner: ${opposing.id}');
      return next;
    }

    final units = List<UnitState>.from(active.units)
        .map((unit) => unit.copyWith(attackedThisTurn: false))
        .toList(growable: false);

    var next = _replacePlayer(
      state,
      activeIndex,
      active.copyWith(poolPicksThisTurn: 0, units: units),
    );

    next = next.copyWith(phase: TurnPhase.attackStep);
    next = _appendEvent(next, 'Turn ${next.turnNumber}: ${next.activePlayer.id} attack phase.');

    if (!_hasPendingMandatoryAttacks(next)) {
      next = next.copyWith(phase: TurnPhase.mainActions);
      next = _appendEvent(
        next,
        '${next.activePlayer.id} has no available attacks and entered action phase.',
      );
    }
    return next;
  }

  GameState _refreshPool(GameState state, {required MatchRules rules}) {
    if (state.draftCatalog.isEmpty) {
      return state;
    }

    var rng = state.catalogCursor;
    var nextPieceId = state.nextPieceInstanceId;
    final pool = <PieceInstance>[];

    for (var i = 0; i < rules.poolSize; i++) {
      rng = _nextRng(rng);
      final definition = state.draftCatalog[rng % state.draftCatalog.length];
      pool.add(
        PieceInstance(
          instanceId: 'p$nextPieceId',
          ownerIndex: -1,
          definition: definition,
        ),
      );
      nextPieceId++;
    }

    return state.copyWith(
      pool: pool,
      catalogCursor: rng,
      nextPieceInstanceId: nextPieceId,
    );
  }

  GameState _resolvePendingCombat(GameState state) {
    final pending = state.pendingCombat;
    if (pending == null) {
      return state.copyWith(phase: TurnPhase.attackStep);
    }

    final attackerPlayerIndex = pending.attackerPlayerIndex;
    final defenderPlayerIndex = (attackerPlayerIndex + 1) % state.players.length;
    final attackerPlayer = state.players[attackerPlayerIndex];
    final defenderPlayer = state.players[defenderPlayerIndex];

    final attackerUnitIndex = _findUnitIndex(attackerPlayer, pending.attackerUnitId);
    if (attackerUnitIndex == -1) {
      return _appendEvent(
        state.copyWith(phase: TurnPhase.attackStep, clearPendingCombat: true),
        'Attack fizzled: attacker totem disappeared.',
      );
    }

    final attackerUnit = attackerPlayer.units[attackerUnitIndex];
    final attackerIndex =
        (pending.attackerPieceIndex >= 0 &&
            pending.attackerPieceIndex < attackerUnit.pieces.length)
        ? pending.attackerPieceIndex
        : 0;
    if (attackerUnit.pieces.isEmpty) {
      return _appendEvent(
        state.copyWith(phase: TurnPhase.attackStep, clearPendingCombat: true),
        'Attack fizzled: attacker has no bound spirits.',
      );
    }

    final attackerPiece = attackerUnit.pieces[attackerIndex];
    if (pending.targetUnitId == null) {
      return _appendEvent(
        state.copyWith(phase: TurnPhase.attackStep, clearPendingCombat: true),
        'Attack fizzled: no enemy totem target selected.',
      );
    }

    final defenderUnitIndex = _findUnitIndex(defenderPlayer, pending.targetUnitId!);
    if (defenderUnitIndex == -1) {
      return _appendEvent(
        state.copyWith(phase: TurnPhase.attackStep, clearPendingCombat: true),
        'Attack fizzled: target totem disappeared.',
      );
    }

    final defenderUnit = defenderPlayer.units[defenderUnitIndex];
    var destroyed = false;
    var reason = 'target had no active spirit';

    if (_hasValidDefendingPiece(defenderUnit)) {
      final defenderPiece = defenderUnit.pieces[defenderUnit.defendingPieceIndex!];
      final result = resolveAttack(
        attacker: attackerPiece.definition,
        defender: defenderPiece.definition,
      );
      destroyed = result.destroyed;
      reason = result.reason;
    } else {
      destroyed = true;
    }

    var next = state;
    if (destroyed) {
      next = _removeUnit(
        next,
        ownerIndex: defenderPlayerIndex,
        unitId: defenderUnit.unitId,
      );
      next = _appendEvent(
        next,
        '${attackerPiece.definition.name} destroyed totem ${defenderUnit.unitId} ($reason).',
      );
    } else {
      next = _appendEvent(
        next,
        '${attackerPiece.definition.name} failed to break totem ${defenderUnit.unitId} ($reason).',
      );
    }

    next = _markUnitAsAttacked(
      next,
      ownerIndex: attackerPlayerIndex,
      unitId: attackerUnit.unitId,
    );

    return _finishCombatAndCheckWinner(
      next,
      attackerPlayerIndex: attackerPlayerIndex,
    );
  }

  GameState _finishCombatAndCheckWinner(
    GameState state, {
    required int attackerPlayerIndex,
  }) {
    final defenderPlayerIndex = (attackerPlayerIndex + 1) % state.players.length;
    final defender = state.players[defenderPlayerIndex];
    final attacker = state.players[attackerPlayerIndex];

    if (!_hasBoardTotem(defender)) {
      var next = state.copyWith(
        phase: TurnPhase.gameOver,
        winnerIndex: attackerPlayerIndex,
        clearPendingCombat: true,
      );
      next = _appendEvent(next, 'Winner: ${attacker.id}');
      return next;
    }

    return state.copyWith(
      phase: TurnPhase.attackStep,
      clearPendingCombat: true,
    );
  }

  GameState _markUnitAsAttacked(
    GameState state, {
    required int ownerIndex,
    required String unitId,
  }) {
    final player = state.players[ownerIndex];
    final unitIndex = _findUnitIndex(player, unitId);
    if (unitIndex == -1) {
      return state;
    }

    final units = List<UnitState>.from(player.units);
    units[unitIndex] = units[unitIndex].copyWith(attackedThisTurn: true);
    return _replacePlayer(state, ownerIndex, player.copyWith(units: units));
  }

  GameState _removeUnit(
    GameState state, {
    required int ownerIndex,
    required String unitId,
  }) {
    final player = state.players[ownerIndex];
    final unitIndex = _findUnitIndex(player, unitId);
    if (unitIndex == -1) {
      return state;
    }

    final units = List<UnitState>.from(player.units)..removeAt(unitIndex);
    return _replacePlayer(state, ownerIndex, player.copyWith(units: units));
  }

  bool _hasPendingMandatoryAttacks(GameState state) {
    if (state.phase != TurnPhase.attackStep) {
      return false;
    }
    if (!_hasLegalAttackTarget(state)) {
      return false;
    }

    for (final unit in state.activePlayer.units) {
      if (_canUnitAttackThisStep(unit)) {
        return true;
      }
    }
    return false;
  }

  bool _hasLegalAttackTarget(GameState state) {
    return state.opposingPlayer.units.isNotEmpty;
  }

  bool _canUnitAttackThisStep(UnitState unit) {
    return unit.pieces.isNotEmpty && unit.attackedThisTurn == false;
  }

  bool _hasValidDefendingPiece(UnitState unit) {
    final index = unit.defendingPieceIndex;
    return index != null && index >= 0 && index < unit.pieces.length;
  }

  bool _allActiveSpiritsAssignedForSpiritTotems(PlayerState player) {
    for (final unit in player.units) {
      if (unit.pieces.isEmpty) {
        continue;
      }
      if (!_hasValidDefendingPiece(unit)) {
        return false;
      }
    }
    return true;
  }

  bool _hasBoardTotem(PlayerState player) => player.units.isNotEmpty;

  int _requiredPoolBindsThisTurn(GameState state, {required MatchRules rules}) {
    if (state.turnNumber == 1 && state.activePlayerIndex == 0) {
      return rules.firstPlayerOpeningDraft;
    }
    return rules.standardDraft;
  }

  bool _isColorProtected({
    required SpiritElement defenderElement,
    required SpiritElement attackerElement,
  }) {
    return (defenderElement == SpiritElement.red &&
            attackerElement == SpiritElement.green) ||
        (defenderElement == SpiritElement.green &&
            attackerElement == SpiritElement.blue) ||
        (defenderElement == SpiritElement.blue &&
            attackerElement == SpiritElement.red);
  }

  bool _isModeProtected({
    required CombatMode defenderDefenseMode,
    required CombatMode attackerAttackMode,
  }) {
    return defenderDefenseMode == attackerAttackMode;
  }

  int _nextRng(int state) {
    return (state * 1103515245 + 12345) & 0x7fffffff;
  }

  int _findPoolIndex(GameState state, String poolPieceId) {
    return state.pool.indexWhere((piece) => piece.instanceId == poolPieceId);
  }

  int _findUnitIndex(PlayerState player, String unitId) {
    return player.units.indexWhere((unit) => unit.unitId == unitId);
  }

  GameState _replacePlayer(
    GameState state,
    int playerIndex,
    PlayerState player,
  ) {
    final players = List<PlayerState>.from(state.players);
    players[playerIndex] = player;
    return state.copyWith(players: players);
  }

  GameState _appendHistory(
    GameState state,
    int actorIndex,
    GameCommand command,
  ) {
    final history = List<CommandLogEntry>.from(state.history)
      ..add(
        CommandLogEntry(
          turnNumber: state.turnNumber,
          actorIndex: actorIndex,
          commandType: command.type,
          summary: command.summary(),
        ),
      );
    return state.copyWith(history: history);
  }

  GameState _appendEvent(GameState state, String line) {
    final log = List<String>.from(state.eventLog)..add(line);
    return state.copyWith(eventLog: log);
  }
}
