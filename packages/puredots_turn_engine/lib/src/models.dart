enum SpiritElement { red, green, blue }

enum CombatMode { physical, magical }

enum TurnPhase {
  startTurn,
  draftFromPool,
  attackStep,
  mainActions,
  resolveCombat,
  chooseDefenders,
  endTurn,
  gameOver,
}

class PieceDefinition {
  const PieceDefinition({
    required this.id,
    required this.name,
    required this.element,
    required this.attackMode,
    required this.defenseMode,
    required this.attack,
    required this.defense,
  });

  final String id;
  final String name;
  final SpiritElement element;
  final CombatMode attackMode;
  final CombatMode defenseMode;
  final int attack;
  final int defense;
}

class PieceInstance {
  const PieceInstance({
    required this.instanceId,
    required this.ownerIndex,
    required this.definition,
  });

  final String instanceId;
  final int ownerIndex;
  final PieceDefinition definition;

  PieceInstance copyWith({
    String? instanceId,
    int? ownerIndex,
    PieceDefinition? definition,
  }) {
    return PieceInstance(
      instanceId: instanceId ?? this.instanceId,
      ownerIndex: ownerIndex ?? this.ownerIndex,
      definition: definition ?? this.definition,
    );
  }
}

class UnitState {
  const UnitState({
    required this.unitId,
    required this.ownerIndex,
    required this.pieces,
    required this.summonedTurn,
    required this.attackingPieceIndex,
    required this.defendingPieceIndex,
    required this.attackedThisTurn,
  });

  final String unitId;
  final int ownerIndex;
  final List<PieceInstance> pieces;
  final int summonedTurn;
  final int? attackingPieceIndex;
  final int? defendingPieceIndex;
  final bool attackedThisTurn;

  UnitState copyWith({
    String? unitId,
    int? ownerIndex,
    List<PieceInstance>? pieces,
    int? summonedTurn,
    int? attackingPieceIndex,
    bool clearAttackingPieceIndex = false,
    int? defendingPieceIndex,
    bool clearDefendingPieceIndex = false,
    bool? attackedThisTurn,
  }) {
    return UnitState(
      unitId: unitId ?? this.unitId,
      ownerIndex: ownerIndex ?? this.ownerIndex,
      pieces: pieces ?? this.pieces,
      summonedTurn: summonedTurn ?? this.summonedTurn,
      attackingPieceIndex: clearAttackingPieceIndex
          ? null
          : (attackingPieceIndex ?? this.attackingPieceIndex),
      defendingPieceIndex: clearDefendingPieceIndex
          ? null
          : (defendingPieceIndex ?? this.defendingPieceIndex),
      attackedThisTurn: attackedThisTurn ?? this.attackedThisTurn,
    );
  }
}

class PlayerState {
  const PlayerState({
    required this.id,
    required this.health,
    required this.totemsInHand,
    required this.hand,
    required this.units,
    required this.turnsTaken,
    required this.poolPicksThisTurn,
    required this.hadUnitsEver,
  });

  final String id;
  final int health;
  final int totemsInHand;
  final List<PieceInstance> hand;
  final List<UnitState> units;
  final int turnsTaken;
  final int poolPicksThisTurn;
  final bool hadUnitsEver;

  PlayerState copyWith({
    String? id,
    int? health,
    int? totemsInHand,
    List<PieceInstance>? hand,
    List<UnitState>? units,
    int? turnsTaken,
    int? poolPicksThisTurn,
    bool? hadUnitsEver,
  }) {
    return PlayerState(
      id: id ?? this.id,
      health: health ?? this.health,
      totemsInHand: totemsInHand ?? this.totemsInHand,
      hand: hand ?? this.hand,
      units: units ?? this.units,
      turnsTaken: turnsTaken ?? this.turnsTaken,
      poolPicksThisTurn: poolPicksThisTurn ?? this.poolPicksThisTurn,
      hadUnitsEver: hadUnitsEver ?? this.hadUnitsEver,
    );
  }
}

class PendingCombat {
  const PendingCombat({
    required this.attackerPlayerIndex,
    required this.attackerUnitId,
    required this.attackerPieceIndex,
    required this.targetUnitId,
  });

  final int attackerPlayerIndex;
  final String attackerUnitId;
  final int attackerPieceIndex;
  final String? targetUnitId;
}

class CombatResult {
  const CombatResult({
    required this.attackerPieceId,
    required this.defenderPieceId,
    required this.elementAdvantage,
    required this.modeAdvantage,
    required this.powerAdvantage,
    required this.destroyed,
    required this.reason,
  });

  final String attackerPieceId;
  final String defenderPieceId;
  final bool elementAdvantage;
  final bool modeAdvantage;
  final bool powerAdvantage;
  final bool destroyed;
  final String reason;
}

class CommandLogEntry {
  const CommandLogEntry({
    required this.turnNumber,
    required this.actorIndex,
    required this.commandType,
    required this.summary,
  });

  final int turnNumber;
  final int actorIndex;
  final String commandType;
  final String summary;
}

class MatchRules {
  const MatchRules({
    this.startingHealth = 24,
    this.poolSize = 5,
    this.firstPlayerOpeningDraft = 1,
    this.standardDraft = 2,
    this.startingTotemsOnField = 1,
    this.startingTotemsInHand = 3,
    this.poolSeed = 1337,
  });

  final int startingHealth;
  final int poolSize;
  final int firstPlayerOpeningDraft;
  final int standardDraft;
  final int startingTotemsOnField;
  final int startingTotemsInHand;
  final int poolSeed;
}

class CommandCheck {
  const CommandCheck._(this.allowed, this.reason);

  const CommandCheck.allowed() : this._(true, null);

  const CommandCheck.denied(String reason) : this._(false, reason);

  final bool allowed;
  final String? reason;
}

abstract class GameCommand {
  String get type;

  String summary();
}

class DraftFromPoolMove extends GameCommand {
  DraftFromPoolMove({required this.poolPieceId});

  final String poolPieceId;

  @override
  String get type => 'draft_from_pool';

  @override
  String summary() => 'draft pool piece $poolPieceId';
}

class PlayToNewUnitMove extends GameCommand {
  PlayToNewUnitMove({required this.handPieceId});

  final String handPieceId;

  @override
  String get type => 'play_to_new_unit';

  @override
  String summary() => 'play hand piece $handPieceId to new unit';
}

class SummonTotemMove extends GameCommand {
  SummonTotemMove();

  @override
  String get type => 'summon_totem';

  @override
  String summary() => 'summon totem from hand';
}

class AddToExistingUnitMove extends GameCommand {
  AddToExistingUnitMove({required this.handPieceId, required this.unitId});

  final String handPieceId;
  final String unitId;

  @override
  String get type => 'add_to_existing_unit';

  @override
  String summary() => 'add hand piece $handPieceId to unit $unitId';
}

class ChooseAttackerMove extends GameCommand {
  ChooseAttackerMove({required this.unitId, required this.pieceIndex});

  final String unitId;
  final int pieceIndex;

  @override
  String get type => 'choose_attacker';

  @override
  String summary() => 'choose attacker piece[$pieceIndex] in unit $unitId';
}

class AttackUnitMove extends GameCommand {
  AttackUnitMove({required this.attackerUnitId, this.targetUnitId});

  final String attackerUnitId;
  final String? targetUnitId;

  @override
  String get type => 'attack_unit';

  @override
  String summary() => targetUnitId == null
      ? 'attack shaman directly with unit $attackerUnitId'
      : 'attack unit $targetUnitId with unit $attackerUnitId';
}

class ChooseDefenderMove extends GameCommand {
  ChooseDefenderMove({required this.unitId, required this.pieceIndex});

  final String unitId;
  final int pieceIndex;

  @override
  String get type => 'choose_defender';

  @override
  String summary() => 'choose defender piece[$pieceIndex] in unit $unitId';
}

class EndTurnMove extends GameCommand {
  EndTurnMove();

  @override
  String get type => 'end_turn';

  @override
  String summary() => 'end turn';
}

class GameState {
  const GameState({
    required this.turnNumber,
    required this.activePlayerIndex,
    required this.phase,
    required this.players,
    required this.pool,
    required this.draftCatalog,
    required this.catalogCursor,
    required this.pendingCombat,
    required this.winnerIndex,
    required this.nextPieceInstanceId,
    required this.nextUnitId,
    required this.history,
    required this.eventLog,
  });

  final int turnNumber;
  final int activePlayerIndex;
  final TurnPhase phase;
  final List<PlayerState> players;
  final List<PieceInstance> pool;
  final List<PieceDefinition> draftCatalog;
  final int catalogCursor;
  final PendingCombat? pendingCombat;
  final int? winnerIndex;
  final int nextPieceInstanceId;
  final int nextUnitId;
  final List<CommandLogEntry> history;
  final List<String> eventLog;

  PlayerState get activePlayer => players[activePlayerIndex];

  int get opposingPlayerIndex => (activePlayerIndex + 1) % players.length;

  PlayerState get opposingPlayer => players[opposingPlayerIndex];

  bool get hasWinner => winnerIndex != null;

  GameState copyWith({
    int? turnNumber,
    int? activePlayerIndex,
    TurnPhase? phase,
    List<PlayerState>? players,
    List<PieceInstance>? pool,
    List<PieceDefinition>? draftCatalog,
    int? catalogCursor,
    PendingCombat? pendingCombat,
    bool clearPendingCombat = false,
    int? winnerIndex,
    bool clearWinnerIndex = false,
    int? nextPieceInstanceId,
    int? nextUnitId,
    List<CommandLogEntry>? history,
    List<String>? eventLog,
  }) {
    return GameState(
      turnNumber: turnNumber ?? this.turnNumber,
      activePlayerIndex: activePlayerIndex ?? this.activePlayerIndex,
      phase: phase ?? this.phase,
      players: players ?? this.players,
      pool: pool ?? this.pool,
      draftCatalog: draftCatalog ?? this.draftCatalog,
      catalogCursor: catalogCursor ?? this.catalogCursor,
      pendingCombat: clearPendingCombat
          ? null
          : (pendingCombat ?? this.pendingCombat),
      winnerIndex: clearWinnerIndex ? null : (winnerIndex ?? this.winnerIndex),
      nextPieceInstanceId: nextPieceInstanceId ?? this.nextPieceInstanceId,
      nextUnitId: nextUnitId ?? this.nextUnitId,
      history: history ?? this.history,
      eventLog: eventLog ?? this.eventLog,
    );
  }
}
