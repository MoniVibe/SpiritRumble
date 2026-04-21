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

    var state = GameState(
      turnNumber: 1,
      activePlayerIndex: 0,
      phase: TurnPhase.startTurn,
      players: const <PlayerState>[
        PlayerState(
          id: 'Shaman 1',
          health: 24,
          hand: <PieceInstance>[],
          units: <UnitState>[],
          turnsTaken: 0,
          poolPicksThisTurn: 0,
          hadUnitsEver: false,
        ),
        PlayerState(
          id: 'Shaman 2',
          health: 24,
          hand: <PieceInstance>[],
          units: <UnitState>[],
          turnsTaken: 0,
          poolPicksThisTurn: 0,
          hadUnitsEver: false,
        ),
      ],
      pool: const <PieceInstance>[],
      draftCatalog: List<PieceDefinition>.from(draftCatalog),
      catalogCursor: 0,
      pendingCombat: null,
      winnerIndex: null,
      nextPieceInstanceId: 1,
      nextUnitId: 1,
      history: const <CommandLogEntry>[],
      eventLog: const <String>['Match created'],
    );

    state = _replacePlayer(
      state,
      0,
      state.players[0].copyWith(health: rules.startingHealth),
    );
    state = _replacePlayer(
      state,
      1,
      state.players[1].copyWith(health: rules.startingHealth),
    );
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
      case DraftFromPoolMove _:
        return _canApplyDraftFromPool(state, command, rules: rules);
      case PlayToNewUnitMove _:
        return _canApplyPlayToNewUnit(state, command);
      case AddToExistingUnitMove _:
        return _canApplyAddToExistingUnit(state, command);
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
      case DraftFromPoolMove _:
        next = _applyDraftFromPool(next, command, rules: rules);
      case PlayToNewUnitMove _:
        next = _applyPlayToNewUnit(next, command);
      case AddToExistingUnitMove _:
        next = _applyAddToExistingUnit(next, command);
      case ChooseAttackerMove _:
        next = _applyChooseAttacker(next, command);
      case AttackUnitMove _:
        next = _applyAttackUnit(next, command);
      case ChooseDefenderMove _:
        next = _applyChooseDefender(next, command, rules: rules);
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
    final elementAdvantage = _hasElementAdvantage(
      attacker.element,
      defender.element,
    );
    final modeAdvantage = _hasModeAdvantage(
      attacker.attackMode,
      defender.defenseMode,
    );
    final powerAdvantage = attacker.attack >= defender.defense;
    final destroyed = elementAdvantage && modeAdvantage && powerAdvantage;

    final reason =
        'element=${elementAdvantage ? 'win' : 'lose'}, '
        'mode=${modeAdvantage ? 'win' : 'lose'}, '
        'power=${powerAdvantage ? 'win' : 'lose'}';
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

  CommandCheck _canApplyDraftFromPool(
    GameState state,
    DraftFromPoolMove command, {
    required MatchRules rules,
  }) {
    if (state.phase != TurnPhase.draftFromPool) {
      return const CommandCheck.denied('not in draft phase');
    }
    if (_findPoolIndex(state, command.poolPieceId) == -1) {
      return const CommandCheck.denied('requested piece is not in pool');
    }
    final requiredPicks = _requiredDraftPicks(state, rules: rules);
    if (state.activePlayer.poolPicksThisTurn >= requiredPicks) {
      return const CommandCheck.denied(
        'draft picks for this turn are complete',
      );
    }
    return const CommandCheck.allowed();
  }

  CommandCheck _canApplyPlayToNewUnit(
    GameState state,
    PlayToNewUnitMove command,
  ) {
    if (state.phase != TurnPhase.mainActions) {
      return const CommandCheck.denied('not in main actions phase');
    }
    if (_findHandIndex(state.activePlayer, command.handPieceId) == -1) {
      return const CommandCheck.denied('piece is not in hand');
    }
    return const CommandCheck.allowed();
  }

  CommandCheck _canApplyAddToExistingUnit(
    GameState state,
    AddToExistingUnitMove command,
  ) {
    if (state.phase != TurnPhase.mainActions) {
      return const CommandCheck.denied('not in main actions phase');
    }
    if (_findHandIndex(state.activePlayer, command.handPieceId) == -1) {
      return const CommandCheck.denied('piece is not in hand');
    }
    final unitIndex = _findUnitIndex(state.activePlayer, command.unitId);
    if (unitIndex == -1) {
      return const CommandCheck.denied('target unit does not exist');
    }
    return const CommandCheck.allowed();
  }

  CommandCheck _canApplyChooseAttacker(
    GameState state,
    ChooseAttackerMove command,
  ) {
    if (state.phase != TurnPhase.mainActions) {
      return const CommandCheck.denied('not in main actions phase');
    }
    final unitIndex = _findUnitIndex(state.activePlayer, command.unitId);
    if (unitIndex == -1) {
      return const CommandCheck.denied('unit not found');
    }
    final unit = state.activePlayer.units[unitIndex];
    if (command.pieceIndex < 0 || command.pieceIndex >= unit.pieces.length) {
      return const CommandCheck.denied('attacker index out of range');
    }
    return const CommandCheck.allowed();
  }

  CommandCheck _canApplyAttackUnit(GameState state, AttackUnitMove command) {
    if (state.phase != TurnPhase.mainActions) {
      return const CommandCheck.denied('not in main actions phase');
    }
    final attackerUnitIndex = _findUnitIndex(
      state.activePlayer,
      command.attackerUnitId,
    );
    if (attackerUnitIndex == -1) {
      return const CommandCheck.denied('attacker unit not found');
    }
    final attackerUnit = state.activePlayer.units[attackerUnitIndex];
    if (attackerUnit.summonedTurn == state.turnNumber) {
      return const CommandCheck.denied(
        'unit cannot attack on the same turn it was summoned',
      );
    }
    if (attackerUnit.attackedThisTurn) {
      return const CommandCheck.denied('unit already attacked this turn');
    }
    if (attackerUnit.attackingPieceIndex == null) {
      return const CommandCheck.denied('attacking piece has not been chosen');
    }
    if (attackerUnit.attackingPieceIndex! >= attackerUnit.pieces.length) {
      return const CommandCheck.denied('attacking piece index out of range');
    }

    if (command.targetUnitId == null) {
      if (state.opposingPlayer.units.isNotEmpty) {
        return const CommandCheck.denied(
          'direct shaman attacks are allowed only when no defender units remain',
        );
      }
      return const CommandCheck.allowed();
    }

    final targetIndex = _findUnitIndex(
      state.opposingPlayer,
      command.targetUnitId!,
    );
    if (targetIndex == -1) {
      return const CommandCheck.denied('target unit not found');
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
      return const CommandCheck.denied('unit not found');
    }
    final unit = state.activePlayer.units[unitIndex];
    if (command.pieceIndex < 0 || command.pieceIndex >= unit.pieces.length) {
      return const CommandCheck.denied('defender index out of range');
    }
    return const CommandCheck.allowed();
  }

  CommandCheck _canApplyEndTurn(GameState state) {
    if (state.phase != TurnPhase.mainActions) {
      return const CommandCheck.denied(
        'end turn is only valid in main actions',
      );
    }
    return const CommandCheck.allowed();
  }

  GameState _applyDraftFromPool(
    GameState state,
    DraftFromPoolMove command, {
    required MatchRules rules,
  }) {
    final pool = List<PieceInstance>.from(state.pool);
    final poolIndex = pool.indexWhere(
      (piece) => piece.instanceId == command.poolPieceId,
    );
    final drafted = pool
        .removeAt(poolIndex)
        .copyWith(ownerIndex: state.activePlayerIndex);

    final active = state.activePlayer;
    final hand = List<PieceInstance>.from(active.hand)..add(drafted);
    var next = _replacePlayer(
      state.copyWith(pool: pool),
      state.activePlayerIndex,
      active.copyWith(
        hand: hand,
        poolPicksThisTurn: active.poolPicksThisTurn + 1,
      ),
    );

    next = _appendEvent(
      next,
      '${active.id} drafted ${drafted.definition.name} from pool.',
    );

    final requiredPicks = _requiredDraftPicks(next, rules: rules);
    if (next.activePlayer.poolPicksThisTurn >= requiredPicks) {
      next = next.copyWith(phase: TurnPhase.mainActions);
      next = _appendEvent(next, '${active.id} completed drafting.');
    }
    return next;
  }

  GameState _applyPlayToNewUnit(GameState state, PlayToNewUnitMove command) {
    final active = state.activePlayer;
    final hand = List<PieceInstance>.from(active.hand);
    final handIndex = hand.indexWhere(
      (piece) => piece.instanceId == command.handPieceId,
    );
    final piece = hand
        .removeAt(handIndex)
        .copyWith(ownerIndex: state.activePlayerIndex);
    final units = List<UnitState>.from(active.units)
      ..add(
        UnitState(
          unitId: 'u${state.nextUnitId}',
          ownerIndex: state.activePlayerIndex,
          pieces: <PieceInstance>[piece],
          summonedTurn: state.turnNumber,
          attackingPieceIndex: 0,
          defendingPieceIndex: null,
          attackedThisTurn: false,
        ),
      );

    var next = state.copyWith(nextUnitId: state.nextUnitId + 1);
    next = _replacePlayer(
      next,
      state.activePlayerIndex,
      active.copyWith(hand: hand, units: units, hadUnitsEver: true),
    );
    return _appendEvent(
      next,
      '${active.id} played ${piece.definition.name} to a new unit.',
    );
  }

  GameState _applyAddToExistingUnit(
    GameState state,
    AddToExistingUnitMove command,
  ) {
    final active = state.activePlayer;
    final hand = List<PieceInstance>.from(active.hand);
    final handIndex = hand.indexWhere(
      (piece) => piece.instanceId == command.handPieceId,
    );
    final piece = hand
        .removeAt(handIndex)
        .copyWith(ownerIndex: state.activePlayerIndex);

    final unitIndex = _findUnitIndex(active, command.unitId);
    final units = List<UnitState>.from(active.units);
    final unit = units[unitIndex];
    final pieces = List<PieceInstance>.from(unit.pieces)..add(piece);
    units[unitIndex] = unit.copyWith(pieces: pieces);

    var next = _replacePlayer(
      state,
      state.activePlayerIndex,
      active.copyWith(hand: hand, units: units),
    );
    return _appendEvent(
      next,
      '${active.id} added ${piece.definition.name} to unit ${unit.unitId}.',
    );
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
      '${active.id} selected attacker piece ${command.pieceIndex} in ${command.unitId}.',
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

  GameState _applyChooseDefender(
    GameState state,
    ChooseDefenderMove command, {
    required MatchRules rules,
  }) {
    final active = state.activePlayer;
    final unitIndex = _findUnitIndex(active, command.unitId);
    final units = List<UnitState>.from(active.units);
    units[unitIndex] = units[unitIndex].copyWith(
      defendingPieceIndex: command.pieceIndex,
    );
    var next = _replacePlayer(
      state,
      state.activePlayerIndex,
      active.copyWith(units: units),
    );
    next = _appendEvent(
      next,
      '${active.id} set defender piece ${command.pieceIndex} for ${command.unitId}.',
    );
    return _advanceAfterDefenderSelection(next, rules: rules);
  }

  GameState _applyEndTurn(GameState state, {required MatchRules rules}) {
    var next = state.copyWith(phase: TurnPhase.chooseDefenders);
    next = _appendEvent(
      next,
      '${state.activePlayer.id} entered defender selection.',
    );
    return _advanceAfterDefenderSelection(next, rules: rules);
  }

  GameState _advanceAfterDefenderSelection(
    GameState state, {
    required MatchRules rules,
  }) {
    if (!_allUnitsHaveDefenders(state.activePlayer)) {
      return state;
    }
    var next = state.copyWith(phase: TurnPhase.endTurn);
    next = _appendEvent(
      next,
      '${state.activePlayer.id} completed defender selection.',
    );
    return _handoffTurn(next, rules: rules);
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
    return _beginTurn(next, rules: rules);
  }

  GameState _beginTurn(GameState state, {required MatchRules rules}) {
    final activeIndex = state.activePlayerIndex;
    final active = state.activePlayer;

    var units = List<UnitState>.from(active.units);
    units = units
        .map(
          (unit) => unit.copyWith(
            attackedThisTurn: false,
            clearAttackingPieceIndex: unit.attackingPieceIndex == null,
          ),
        )
        .toList(growable: false);

    var next = _replacePlayer(
      state,
      activeIndex,
      active.copyWith(poolPicksThisTurn: 0, units: units),
    );
    next = _refillPool(next, rules: rules);
    next = next.copyWith(phase: TurnPhase.draftFromPool);
    return _appendEvent(
      next,
      'Turn ${next.turnNumber}: ${next.activePlayer.id} drafts ${_requiredDraftPicks(next, rules: rules)} from pool.',
    );
  }

  GameState _refillPool(GameState state, {required MatchRules rules}) {
    var pool = List<PieceInstance>.from(state.pool);
    var cursor = state.catalogCursor;
    var nextPieceId = state.nextPieceInstanceId;

    while (pool.length < rules.poolSize) {
      final definition = state.draftCatalog[cursor % state.draftCatalog.length];
      pool.add(
        PieceInstance(
          instanceId: 'p$nextPieceId',
          ownerIndex: -1,
          definition: definition,
        ),
      );
      cursor++;
      nextPieceId++;
    }

    return state.copyWith(
      pool: pool,
      catalogCursor: cursor,
      nextPieceInstanceId: nextPieceId,
    );
  }

  GameState _resolvePendingCombat(GameState state) {
    final pending = state.pendingCombat;
    if (pending == null) {
      return state.copyWith(phase: TurnPhase.mainActions);
    }

    final attackerPlayerIndex = pending.attackerPlayerIndex;
    final defenderPlayerIndex =
        (attackerPlayerIndex + 1) % state.players.length;
    final attackerPlayer = state.players[attackerPlayerIndex];
    final defenderPlayer = state.players[defenderPlayerIndex];

    final attackerUnitIndex = _findUnitIndex(
      attackerPlayer,
      pending.attackerUnitId,
    );
    if (attackerUnitIndex == -1) {
      return _appendEvent(
        state.copyWith(phase: TurnPhase.mainActions, clearPendingCombat: true),
        'Attack fizzled: attacker unit disappeared.',
      );
    }
    final attackerUnit = attackerPlayer.units[attackerUnitIndex];
    final attackerPiece = attackerUnit.pieces[pending.attackerPieceIndex];

    var next = state;
    if (pending.targetUnitId == null) {
      final nextHealth =
          (defenderPlayer.health - attackerPiece.definition.attack).clamp(
            0,
            1 << 30,
          );
      next = _replacePlayer(
        next,
        defenderPlayerIndex,
        defenderPlayer.copyWith(health: nextHealth),
      );
      next = _markUnitAsAttacked(
        next,
        ownerIndex: attackerPlayerIndex,
        unitId: attackerUnit.unitId,
      );
      next = _appendEvent(
        next,
        '${attackerPiece.definition.name} hit ${defenderPlayer.id} directly for ${attackerPiece.definition.attack}.',
      );
      return _finishCombatAndCheckWinner(
        next,
        attackerPlayerIndex: attackerPlayerIndex,
      );
    }

    final defenderUnitIndex = _findUnitIndex(
      defenderPlayer,
      pending.targetUnitId!,
    );
    if (defenderUnitIndex == -1) {
      return _appendEvent(
        state.copyWith(phase: TurnPhase.mainActions, clearPendingCombat: true),
        'Attack fizzled: target unit disappeared.',
      );
    }
    final defenderUnit = defenderPlayer.units[defenderUnitIndex];
    final defenderPieceIndex =
        (defenderUnit.defendingPieceIndex != null &&
            defenderUnit.defendingPieceIndex! < defenderUnit.pieces.length)
        ? defenderUnit.defendingPieceIndex!
        : 0;
    final defenderPiece = defenderUnit.pieces[defenderPieceIndex];

    final result = resolveAttack(
      attacker: attackerPiece.definition,
      defender: defenderPiece.definition,
    );
    if (result.destroyed) {
      next = _removePieceFromUnit(
        next,
        ownerIndex: defenderPlayerIndex,
        unitId: defenderUnit.unitId,
        pieceIndex: defenderPieceIndex,
      );
      next = _appendEvent(
        next,
        '${attackerPiece.definition.name} destroyed ${defenderPiece.definition.name} (${result.reason}).',
      );
    } else {
      next = _appendEvent(
        next,
        '${attackerPiece.definition.name} failed to break ${defenderPiece.definition.name} (${result.reason}).',
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
    final defenderPlayerIndex =
        (attackerPlayerIndex + 1) % state.players.length;
    final defender = state.players[defenderPlayerIndex];
    final attacker = state.players[attackerPlayerIndex];

    if (defender.health <= 0 ||
        (defender.hadUnitsEver && defender.units.isEmpty)) {
      var next = state.copyWith(
        phase: TurnPhase.gameOver,
        winnerIndex: attackerPlayerIndex,
        clearPendingCombat: true,
      );
      next = _appendEvent(next, 'Winner: ${attacker.id}');
      return next;
    }

    return state.copyWith(
      phase: TurnPhase.mainActions,
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

  GameState _removePieceFromUnit(
    GameState state, {
    required int ownerIndex,
    required String unitId,
    required int pieceIndex,
  }) {
    final player = state.players[ownerIndex];
    final unitIndex = _findUnitIndex(player, unitId);
    if (unitIndex == -1) {
      return state;
    }

    final units = List<UnitState>.from(player.units);
    final unit = units[unitIndex];
    final pieces = List<PieceInstance>.from(unit.pieces)..removeAt(pieceIndex);
    if (pieces.isEmpty) {
      units.removeAt(unitIndex);
    } else {
      final safeAttackerIndex =
          (unit.attackingPieceIndex != null &&
              unit.attackingPieceIndex! < pieces.length)
          ? unit.attackingPieceIndex
          : 0;
      final safeDefenderIndex =
          (unit.defendingPieceIndex != null &&
              unit.defendingPieceIndex! < pieces.length)
          ? unit.defendingPieceIndex
          : 0;
      units[unitIndex] = unit.copyWith(
        pieces: pieces,
        attackingPieceIndex: safeAttackerIndex,
        defendingPieceIndex: safeDefenderIndex,
      );
    }
    return _replacePlayer(state, ownerIndex, player.copyWith(units: units));
  }

  bool _allUnitsHaveDefenders(PlayerState player) {
    for (final unit in player.units) {
      if (unit.pieces.isEmpty) {
        continue;
      }
      final index = unit.defendingPieceIndex;
      if (index == null || index < 0 || index >= unit.pieces.length) {
        return false;
      }
    }
    return true;
  }

  int _requiredDraftPicks(GameState state, {required MatchRules rules}) {
    final active = state.activePlayer;
    if (state.activePlayerIndex == 0 && active.turnsTaken == 0) {
      return rules.firstPlayerOpeningDraft;
    }
    return rules.standardDraft;
  }

  bool _hasElementAdvantage(SpiritElement attacker, SpiritElement defender) {
    return (attacker == SpiritElement.blue && defender == SpiritElement.red) ||
        (attacker == SpiritElement.red && defender == SpiritElement.green) ||
        (attacker == SpiritElement.green && defender == SpiritElement.blue);
  }

  bool _hasModeAdvantage(CombatMode attackMode, CombatMode defenseMode) {
    return (attackMode == CombatMode.physical &&
            defenseMode == CombatMode.magical) ||
        (attackMode == CombatMode.magical &&
            defenseMode == CombatMode.physical);
  }

  int _findPoolIndex(GameState state, String poolPieceId) {
    return state.pool.indexWhere((piece) => piece.instanceId == poolPieceId);
  }

  int _findHandIndex(PlayerState player, String handPieceId) {
    return player.hand.indexWhere((piece) => piece.instanceId == handPieceId);
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
