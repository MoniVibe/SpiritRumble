import 'dart:convert';

enum BughuntMode { local, ai, online }

enum BughuntRole { host, client, localA, localB }

enum BughuntSeverity { info, warn, error, critical }

enum BughuntGateVerdict { pass, fail, blocked }

const int bughuntSchemaVersion = 1;

class BughuntConfig {
  const BughuntConfig({
    required this.runId,
    required this.mode,
    required this.role,
    this.seed,
    this.maxTurns,
    this.queueResolutionMaxTicks = 30,
    this.roomIdOrMatchId,
    this.appVersionOrCommitSha,
  });

  final String runId;
  final BughuntMode mode;
  final BughuntRole role;
  final int? seed;
  final int? maxTurns;
  final int queueResolutionMaxTicks;
  final String? roomIdOrMatchId;
  final String? appVersionOrCommitSha;

  Map<String, Object?> toJson() {
    return <String, Object?>{
      'runId': runId,
      'mode': mode.name,
      'role': role.name,
      'seed': seed,
      'maxTurns': maxTurns,
      'queueResolutionMaxTicks': queueResolutionMaxTicks,
      'roomIdOrMatchId': roomIdOrMatchId,
      'appVersionOrCommitSha': appVersionOrCommitSha,
    };
  }
}

class SessionMetadata {
  const SessionMetadata({
    required this.schemaVersion,
    required this.runId,
    required this.sessionId,
    required this.game,
    required this.mode,
    required this.role,
    required this.deviceInfo,
    this.appVersionOrCommitSha,
    this.roomIdOrMatchId,
    this.seed,
    this.maxTurns,
  });

  final int schemaVersion;
  final String runId;
  final String sessionId;
  final String game;
  final BughuntMode mode;
  final BughuntRole role;
  final String? appVersionOrCommitSha;
  final String? roomIdOrMatchId;
  final int? seed;
  final int? maxTurns;
  final Map<String, Object?> deviceInfo;

  Map<String, Object?> toJson() {
    return <String, Object?>{
      'schemaVersion': schemaVersion,
      'runId': runId,
      'sessionId': sessionId,
      'game': game,
      'mode': mode.name,
      'role': role.name,
      'appVersionOrCommitSha': appVersionOrCommitSha,
      'roomIdOrMatchId': roomIdOrMatchId,
      'seed': seed,
      'maxTurns': maxTurns,
      'deviceInfo': deviceInfo,
    };
  }
}

class SessionEvent {
  const SessionEvent({
    required this.schemaVersion,
    required this.runId,
    required this.sessionId,
    required this.game,
    required this.mode,
    required this.role,
    required this.deviceInfo,
    required this.logicalTick,
    required this.wallClockTs,
    required this.turnIndex,
    required this.actionIndexOrPlyIndex,
    required this.eventType,
    required this.payload,
    required this.severity,
    this.appVersionOrCommitSha,
    this.roomIdOrMatchId,
    this.seed,
    this.maxTurns,
  });

  final int schemaVersion;
  final String runId;
  final String sessionId;
  final String game;
  final BughuntMode mode;
  final BughuntRole role;
  final String? appVersionOrCommitSha;
  final String? roomIdOrMatchId;
  final int? seed;
  final int? maxTurns;
  final Map<String, Object?> deviceInfo;
  final int logicalTick;
  final String wallClockTs;
  final int turnIndex;
  final int actionIndexOrPlyIndex;
  final String eventType;
  final Map<String, Object?> payload;
  final BughuntSeverity severity;

  Map<String, Object?> toJson() {
    return <String, Object?>{
      'schemaVersion': schemaVersion,
      'runId': runId,
      'sessionId': sessionId,
      'game': game,
      'appVersionOrCommitSha': appVersionOrCommitSha,
      'mode': mode.name,
      'role': role.name,
      'roomIdOrMatchId': roomIdOrMatchId,
      'seed': seed,
      'maxTurns': maxTurns,
      'deviceInfo': deviceInfo,
      'logicalTick': logicalTick,
      'wallClockTs': wallClockTs,
      'turnIndex': turnIndex,
      'actionIndexOrPlyIndex': actionIndexOrPlyIndex,
      'eventType': eventType,
      'payload': payload,
      'severity': severity.name,
    };
  }

  static SessionEvent? tryParse(Object? raw) {
    if (raw is! Map) {
      return null;
    }
    final map = Map<String, dynamic>.from(raw);
    final mode = _parseMode(map['mode']);
    final role = _parseRole(map['role']);
    final severity = _parseSeverity(map['severity']);
    if (mode == null || role == null || severity == null) {
      return null;
    }

    final logicalTick = _asInt(map['logicalTick']);
    final turnIndex = _asInt(map['turnIndex']);
    final actionIndex = _asInt(map['actionIndexOrPlyIndex']);
    final schemaVersion = _asInt(map['schemaVersion']) ?? bughuntSchemaVersion;
    final runId = map['runId']?.toString();
    final sessionId = map['sessionId']?.toString();
    final game = map['game']?.toString();
    final wallClockTs = map['wallClockTs']?.toString();
    final eventType = map['eventType']?.toString();
    if (logicalTick == null ||
        turnIndex == null ||
        actionIndex == null ||
        runId == null ||
        sessionId == null ||
        game == null ||
        wallClockTs == null ||
        eventType == null) {
      return null;
    }

    final payloadRaw = map['payload'];
    final payload = payloadRaw is Map
        ? Map<String, Object?>.from(payloadRaw)
        : const <String, Object?>{};

    final deviceRaw = map['deviceInfo'];
    final deviceInfo = deviceRaw is Map
        ? Map<String, Object?>.from(deviceRaw)
        : const <String, Object?>{};

    return SessionEvent(
      schemaVersion: schemaVersion,
      runId: runId,
      sessionId: sessionId,
      game: game,
      mode: mode,
      role: role,
      appVersionOrCommitSha: map['appVersionOrCommitSha']?.toString(),
      roomIdOrMatchId: map['roomIdOrMatchId']?.toString(),
      seed: _asInt(map['seed']),
      maxTurns: _asInt(map['maxTurns']),
      deviceInfo: deviceInfo,
      logicalTick: logicalTick,
      wallClockTs: wallClockTs,
      turnIndex: turnIndex,
      actionIndexOrPlyIndex: actionIndex,
      eventType: eventType,
      payload: payload,
      severity: severity,
    );
  }

  static int? _asInt(Object? raw) {
    if (raw is int) {
      return raw;
    }
    if (raw is num) {
      return raw.toInt();
    }
    if (raw is String) {
      return int.tryParse(raw);
    }
    return null;
  }
}

class InvariantFailure {
  const InvariantFailure({
    required this.failureCode,
    required this.message,
    required this.runId,
    required this.sessionId,
    required this.game,
    required this.mode,
    required this.role,
    required this.logicalTick,
    required this.turnIndex,
    required this.actionIndexOrPlyIndex,
    this.seed,
    this.context = const <String, Object?>{},
  });

  final String failureCode;
  final String message;
  final String runId;
  final String sessionId;
  final String game;
  final BughuntMode mode;
  final BughuntRole role;
  final int logicalTick;
  final int turnIndex;
  final int actionIndexOrPlyIndex;
  final int? seed;
  final Map<String, Object?> context;

  Map<String, Object?> toJson() {
    return <String, Object?>{
      'failureCode': failureCode,
      'message': message,
      'runId': runId,
      'sessionId': sessionId,
      'game': game,
      'mode': mode.name,
      'role': role.name,
      'logicalTick': logicalTick,
      'turnIndex': turnIndex,
      'actionIndexOrPlyIndex': actionIndexOrPlyIndex,
      'seed': seed,
      'context': context,
    };
  }
}

class SessionSummary {
  const SessionSummary({
    required this.runId,
    required this.game,
    required this.mode,
    required this.sessions,
    required this.failures,
    required this.verdict,
    required this.completionRate,
    this.crashCount = 0,
    this.desyncCount = 0,
    this.invariantFailureCount = 0,
    this.failureCodes = const <String>[],
    this.notes = const <String>[],
  });

  final String runId;
  final String game;
  final BughuntMode mode;
  final int sessions;
  final int failures;
  final BughuntGateVerdict verdict;
  final double completionRate;
  final int crashCount;
  final int desyncCount;
  final int invariantFailureCount;
  final List<String> failureCodes;
  final List<String> notes;

  Map<String, Object?> toJson() {
    return <String, Object?>{
      'runId': runId,
      'game': game,
      'mode': mode.name,
      'sessions': sessions,
      'failures': failures,
      'verdict': verdict.name.toUpperCase(),
      'completionRate': completionRate,
      'crashCount': crashCount,
      'desyncCount': desyncCount,
      'invariantFailureCount': invariantFailureCount,
      'failureCodes': failureCodes,
      'notes': notes,
    };
  }
}

class BughuntGateConfig {
  const BughuntGateConfig({
    this.minSessions,
    this.minCompletionRate = 1.0,
    this.requireZeroCrashes = true,
    this.requireZeroInvariantFailures = true,
    this.requireZeroDesyncs = true,
    this.blockedFailureCodes = const <String>[],
  });

  final int? minSessions;
  final double minCompletionRate;
  final bool requireZeroCrashes;
  final bool requireZeroInvariantFailures;
  final bool requireZeroDesyncs;
  final List<String> blockedFailureCodes;

  Map<String, Object?> toJson() {
    return <String, Object?>{
      'minSessions': minSessions,
      'minCompletionRate': minCompletionRate,
      'requireZeroCrashes': requireZeroCrashes,
      'requireZeroInvariantFailures': requireZeroInvariantFailures,
      'requireZeroDesyncs': requireZeroDesyncs,
      'blockedFailureCodes': blockedFailureCodes,
    };
  }
}

class StateSnapshotHash {
  const StateSnapshotHash({
    required this.algorithm,
    required this.value,
    required this.canonicalJson,
  });

  final String algorithm;
  final String value;
  final String canonicalJson;

  Map<String, Object?> toJson() {
    return <String, Object?>{
      'algorithm': algorithm,
      'value': value,
      'canonicalJson': canonicalJson,
    };
  }
}

BughuntMode? parseBughuntMode(String? raw) => _parseMode(raw);

BughuntRole? parseBughuntRole(String? raw) => _parseRole(raw);

BughuntSeverity? parseBughuntSeverity(String? raw) => _parseSeverity(raw);

BughuntMode? _parseMode(Object? raw) {
  final value = raw?.toString().trim().toLowerCase();
  switch (value) {
    case 'local':
      return BughuntMode.local;
    case 'ai':
      return BughuntMode.ai;
    case 'online':
      return BughuntMode.online;
    default:
      return null;
  }
}

BughuntRole? _parseRole(Object? raw) {
  final value = raw?.toString().trim();
  if (value == null || value.isEmpty) {
    return null;
  }
  for (final role in BughuntRole.values) {
    if (role.name.toLowerCase() == value.toLowerCase()) {
      return role;
    }
  }
  return null;
}

BughuntSeverity? _parseSeverity(Object? raw) {
  final value = raw?.toString().trim().toLowerCase();
  switch (value) {
    case 'info':
      return BughuntSeverity.info;
    case 'warn':
      return BughuntSeverity.warn;
    case 'error':
      return BughuntSeverity.error;
    case 'critical':
      return BughuntSeverity.critical;
    default:
      return null;
  }
}

String sessionEventToJsonLine(SessionEvent event) {
  return '${jsonEncode(event.toJson())}\n';
}
