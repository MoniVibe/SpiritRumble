import 'models.dart';

class TurnEngineJsonCodec {
  const TurnEngineJsonCodec._();

  static Map<String, Object?> encodeRules(MatchRules rules) {
    return <String, Object?>{
      'startingHealth': rules.startingHealth,
      'poolSize': rules.poolSize,
      'firstPlayerOpeningDraft': rules.firstPlayerOpeningDraft,
      'standardDraft': rules.standardDraft,
      'startingTotemsOnField': rules.startingTotemsOnField,
      'startingTotemsInHand': rules.startingTotemsInHand,
      'poolSeed': rules.poolSeed,
    };
  }

  static MatchRules decodeRules(Map<String, Object?> json) {
    return MatchRules(
      startingHealth: _requiredInt(json, 'startingHealth'),
      poolSize: _requiredInt(json, 'poolSize'),
      firstPlayerOpeningDraft: _requiredInt(json, 'firstPlayerOpeningDraft'),
      standardDraft: _requiredInt(json, 'standardDraft'),
      startingTotemsOnField: _requiredInt(json, 'startingTotemsOnField'),
      startingTotemsInHand: _requiredInt(json, 'startingTotemsInHand'),
      poolSeed: _requiredInt(json, 'poolSeed'),
    );
  }

  static Map<String, Object?> encodeGameCommand(GameCommand command) {
    final payload = switch (command) {
      DraftFromPoolMove c => <String, Object?>{'poolPieceId': c.poolPieceId},
      PlayToNewUnitMove c => <String, Object?>{'handPieceId': c.handPieceId},
      SummonTotemMove _ => const <String, Object?>{},
      AddToExistingUnitMove c => <String, Object?>{
        'handPieceId': c.handPieceId,
        'unitId': c.unitId,
      },
      ChooseAttackerMove c => <String, Object?>{
        'unitId': c.unitId,
        'pieceIndex': c.pieceIndex,
      },
      AttackUnitMove c => <String, Object?>{
        'attackerUnitId': c.attackerUnitId,
        'targetUnitId': c.targetUnitId,
      },
      ChooseDefenderMove c => <String, Object?>{
        'unitId': c.unitId,
        'pieceIndex': c.pieceIndex,
      },
      EndTurnMove _ => const <String, Object?>{},
      _ => throw FormatException('Unsupported command type: ${command.type}'),
    };

    return <String, Object?>{'type': command.type, 'payload': payload};
  }

  static GameCommand decodeGameCommand(Map<String, Object?> json) {
    final type = _requiredString(json, 'type');
    final payload = _map(json['payload'], key: 'payload');

    return switch (type) {
      'draft_from_pool' => DraftFromPoolMove(
        poolPieceId: _requiredString(payload, 'poolPieceId'),
      ),
      'play_to_new_unit' => PlayToNewUnitMove(
        handPieceId: _requiredString(payload, 'handPieceId'),
      ),
      'summon_totem' => SummonTotemMove(),
      'add_to_existing_unit' => AddToExistingUnitMove(
        handPieceId: _requiredString(payload, 'handPieceId'),
        unitId: _requiredString(payload, 'unitId'),
      ),
      'choose_attacker' => ChooseAttackerMove(
        unitId: _requiredString(payload, 'unitId'),
        pieceIndex: _requiredInt(payload, 'pieceIndex'),
      ),
      'attack_unit' => AttackUnitMove(
        attackerUnitId: _requiredString(payload, 'attackerUnitId'),
        targetUnitId: _optionalString(payload, 'targetUnitId'),
      ),
      'choose_defender' => ChooseDefenderMove(
        unitId: _requiredString(payload, 'unitId'),
        pieceIndex: _requiredInt(payload, 'pieceIndex'),
      ),
      'end_turn' => EndTurnMove(),
      _ => throw FormatException('Unsupported command type: $type'),
    };
  }

  static Map<String, Object?> encodeGameState(GameState state) {
    return <String, Object?>{
      'turnNumber': state.turnNumber,
      'activePlayerIndex': state.activePlayerIndex,
      'phase': state.phase.name,
      'players': state.players.map(encodePlayerState).toList(growable: false),
      'pool': state.pool.map(encodePieceInstance).toList(growable: false),
      'draftCatalog': state.draftCatalog
          .map(encodePieceDefinition)
          .toList(growable: false),
      'catalogCursor': state.catalogCursor,
      'pendingCombat': state.pendingCombat == null
          ? null
          : encodePendingCombat(state.pendingCombat!),
      'winnerIndex': state.winnerIndex,
      'nextPieceInstanceId': state.nextPieceInstanceId,
      'nextUnitId': state.nextUnitId,
      'history': state.history.map(encodeCommandLogEntry).toList(growable: false),
      'eventLog': List<String>.from(state.eventLog),
    };
  }

  static GameState decodeGameState(Map<String, Object?> json) {
    return GameState(
      turnNumber: _requiredInt(json, 'turnNumber'),
      activePlayerIndex: _requiredInt(json, 'activePlayerIndex'),
      phase: _parseTurnPhase(_requiredString(json, 'phase')),
      players: _list(
        json['players'],
        key: 'players',
      ).map((entry) => decodePlayerState(_map(entry))).toList(growable: false),
      pool: _list(
        json['pool'],
        key: 'pool',
      ).map((entry) => decodePieceInstance(_map(entry))).toList(growable: false),
      draftCatalog: _list(
        json['draftCatalog'],
        key: 'draftCatalog',
      ).map((entry) => decodePieceDefinition(_map(entry))).toList(growable: false),
      catalogCursor: _requiredInt(json, 'catalogCursor'),
      pendingCombat: json['pendingCombat'] == null
          ? null
          : decodePendingCombat(_map(json['pendingCombat'])),
      winnerIndex: _optionalInt(json, 'winnerIndex'),
      nextPieceInstanceId: _requiredInt(json, 'nextPieceInstanceId'),
      nextUnitId: _requiredInt(json, 'nextUnitId'),
      history: _list(
        json['history'],
        key: 'history',
      ).map((entry) => decodeCommandLogEntry(_map(entry))).toList(growable: false),
      eventLog: _list(
        json['eventLog'],
        key: 'eventLog',
      ).map((entry) => entry.toString()).toList(growable: false),
    );
  }

  static Map<String, Object?> encodePieceDefinition(PieceDefinition value) {
    return <String, Object?>{
      'id': value.id,
      'name': value.name,
      'element': value.element.name,
      'attackMode': value.attackMode.name,
      'defenseMode': value.defenseMode.name,
      'attack': value.attack,
      'defense': value.defense,
    };
  }

  static PieceDefinition decodePieceDefinition(Map<String, Object?> json) {
    return PieceDefinition(
      id: _requiredString(json, 'id'),
      name: _requiredString(json, 'name'),
      element: _parseSpiritElement(_requiredString(json, 'element')),
      attackMode: _parseCombatMode(_requiredString(json, 'attackMode')),
      defenseMode: _parseCombatMode(_requiredString(json, 'defenseMode')),
      attack: _requiredInt(json, 'attack'),
      defense: _requiredInt(json, 'defense'),
    );
  }

  static Map<String, Object?> encodePieceInstance(PieceInstance value) {
    return <String, Object?>{
      'instanceId': value.instanceId,
      'ownerIndex': value.ownerIndex,
      'definition': encodePieceDefinition(value.definition),
    };
  }

  static PieceInstance decodePieceInstance(Map<String, Object?> json) {
    return PieceInstance(
      instanceId: _requiredString(json, 'instanceId'),
      ownerIndex: _requiredInt(json, 'ownerIndex'),
      definition: decodePieceDefinition(_map(json['definition'], key: 'definition')),
    );
  }

  static Map<String, Object?> encodeUnitState(UnitState value) {
    return <String, Object?>{
      'unitId': value.unitId,
      'ownerIndex': value.ownerIndex,
      'pieces': value.pieces.map(encodePieceInstance).toList(growable: false),
      'summonedTurn': value.summonedTurn,
      'attackingPieceIndex': value.attackingPieceIndex,
      'defendingPieceIndex': value.defendingPieceIndex,
      'attackedThisTurn': value.attackedThisTurn,
    };
  }

  static UnitState decodeUnitState(Map<String, Object?> json) {
    return UnitState(
      unitId: _requiredString(json, 'unitId'),
      ownerIndex: _requiredInt(json, 'ownerIndex'),
      pieces: _list(
        json['pieces'],
        key: 'pieces',
      ).map((entry) => decodePieceInstance(_map(entry))).toList(growable: false),
      summonedTurn: _requiredInt(json, 'summonedTurn'),
      attackingPieceIndex: _optionalInt(json, 'attackingPieceIndex'),
      defendingPieceIndex: _optionalInt(json, 'defendingPieceIndex'),
      attackedThisTurn: _requiredBool(json, 'attackedThisTurn'),
    );
  }

  static Map<String, Object?> encodePlayerState(PlayerState value) {
    return <String, Object?>{
      'id': value.id,
      'health': value.health,
      'totemsInHand': value.totemsInHand,
      'hand': value.hand.map(encodePieceInstance).toList(growable: false),
      'units': value.units.map(encodeUnitState).toList(growable: false),
      'turnsTaken': value.turnsTaken,
      'poolPicksThisTurn': value.poolPicksThisTurn,
      'hadUnitsEver': value.hadUnitsEver,
    };
  }

  static PlayerState decodePlayerState(Map<String, Object?> json) {
    return PlayerState(
      id: _requiredString(json, 'id'),
      health: _requiredInt(json, 'health'),
      totemsInHand: _requiredInt(json, 'totemsInHand'),
      hand: _list(
        json['hand'],
        key: 'hand',
      ).map((entry) => decodePieceInstance(_map(entry))).toList(growable: false),
      units: _list(
        json['units'],
        key: 'units',
      ).map((entry) => decodeUnitState(_map(entry))).toList(growable: false),
      turnsTaken: _requiredInt(json, 'turnsTaken'),
      poolPicksThisTurn: _requiredInt(json, 'poolPicksThisTurn'),
      hadUnitsEver: _requiredBool(json, 'hadUnitsEver'),
    );
  }

  static Map<String, Object?> encodePendingCombat(PendingCombat value) {
    return <String, Object?>{
      'attackerPlayerIndex': value.attackerPlayerIndex,
      'attackerUnitId': value.attackerUnitId,
      'attackerPieceIndex': value.attackerPieceIndex,
      'targetUnitId': value.targetUnitId,
    };
  }

  static PendingCombat decodePendingCombat(Map<String, Object?> json) {
    return PendingCombat(
      attackerPlayerIndex: _requiredInt(json, 'attackerPlayerIndex'),
      attackerUnitId: _requiredString(json, 'attackerUnitId'),
      attackerPieceIndex: _requiredInt(json, 'attackerPieceIndex'),
      targetUnitId: _optionalString(json, 'targetUnitId'),
    );
  }

  static Map<String, Object?> encodeCommandLogEntry(CommandLogEntry value) {
    return <String, Object?>{
      'turnNumber': value.turnNumber,
      'actorIndex': value.actorIndex,
      'commandType': value.commandType,
      'summary': value.summary,
    };
  }

  static CommandLogEntry decodeCommandLogEntry(Map<String, Object?> json) {
    return CommandLogEntry(
      turnNumber: _requiredInt(json, 'turnNumber'),
      actorIndex: _requiredInt(json, 'actorIndex'),
      commandType: _requiredString(json, 'commandType'),
      summary: _requiredString(json, 'summary'),
    );
  }

  static SpiritElement _parseSpiritElement(String value) {
    for (final item in SpiritElement.values) {
      if (item.name == value) {
        return item;
      }
    }
    throw FormatException('Unknown SpiritElement: $value');
  }

  static CombatMode _parseCombatMode(String value) {
    for (final item in CombatMode.values) {
      if (item.name == value) {
        return item;
      }
    }
    throw FormatException('Unknown CombatMode: $value');
  }

  static TurnPhase _parseTurnPhase(String value) {
    for (final item in TurnPhase.values) {
      if (item.name == value) {
        return item;
      }
    }
    throw FormatException('Unknown TurnPhase: $value');
  }

  static Map<String, Object?> _map(Object? value, {String? key}) {
    if (value is Map<String, Object?>) {
      return value;
    }
    if (value is Map) {
      return value.map(
        (dynamic k, dynamic v) => MapEntry(k.toString(), v as Object?),
      );
    }
    throw FormatException('Expected map${key == null ? '' : ' for $key'}');
  }

  static List<Object?> _list(Object? value, {required String key}) {
    if (value is List) {
      return value.cast<Object?>();
    }
    throw FormatException('Expected list for $key');
  }

  static String _requiredString(Map<String, Object?> json, String key) {
    final value = json[key];
    if (value is String) {
      return value;
    }
    throw FormatException('Expected string for $key');
  }

  static String? _optionalString(Map<String, Object?> json, String key) {
    final value = json[key];
    if (value == null) {
      return null;
    }
    if (value is String) {
      return value;
    }
    throw FormatException('Expected string for $key');
  }

  static int _requiredInt(Map<String, Object?> json, String key) {
    final value = json[key];
    if (value is int) {
      return value;
    }
    if (value is num) {
      return value.toInt();
    }
    throw FormatException('Expected int for $key');
  }

  static int? _optionalInt(Map<String, Object?> json, String key) {
    final value = json[key];
    if (value == null) {
      return null;
    }
    if (value is int) {
      return value;
    }
    if (value is num) {
      return value.toInt();
    }
    throw FormatException('Expected int for $key');
  }

  static bool _requiredBool(Map<String, Object?> json, String key) {
    final value = json[key];
    if (value is bool) {
      return value;
    }
    throw FormatException('Expected bool for $key');
  }
}
