import 'dart:convert';
import 'dart:io';

import 'bughunt_contract.dart';
import 'state_snapshot_hash.dart';

/// Writes structured per-session diagnostics for local and online game flows.
///
/// Compatibility outputs:
/// `debug/last_game/<game>/<mode>/sessions/<session-id>.jsonl`
/// `debug/last_game/<game>/<mode>/latest.jsonl`
/// `debug/last_game/<game>/<mode>/latest_summary.json`
///
/// Bughunt outputs:
/// `artifacts/bughunt/<runId>/<game>/<mode>/<role>.jsonl`
class GameSessionLogger {
  GameSessionLogger({
    required this.applicationId,
    required this.gameId,
    required this.mode,
    this.bughuntConfig,
    this.appVersionOrCommitSha,
    this.seed,
    this.maxTurns,
    this.roomIdOrMatchId,
  });

  final String applicationId;
  final String gameId;
  final String mode;
  final BughuntConfig? bughuntConfig;
  final String? appVersionOrCommitSha;
  final int? seed;
  final int? maxTurns;
  final String? roomIdOrMatchId;

  final BughuntStateHasher _stateHasher = const BughuntStateHasher();

  String? _sessionId;
  String? _runId;
  File? _sessionFile;
  File? _latestFile;
  File? _latestSummaryFile;
  File? _bughuntFile;

  int _logicalTick = 0;
  int _turnIndex = 0;
  int _actionIndexOrPlyIndex = 0;
  bool _emittedAppStart = false;
  String? _runtimeRoomOrMatchId;

  void beginSession({
    required String sessionLabel,
    Map<String, Object?> context = const <String, Object?>{},
  }) {
    final nowUtc = _utcNow();
    final timestamp = _compactTimestamp(nowUtc);
    _sessionId = '$timestamp-$pidString-${_sanitize(sessionLabel)}';
    _runId = _resolveRunId(nowUtc);
    _logicalTick = 0;
    _turnIndex = 0;
    _actionIndexOrPlyIndex = 0;
    _runtimeRoomOrMatchId = roomIdOrMatchId;
    _sessionFile = null;
    _latestFile = null;
    _latestSummaryFile = null;
    _bughuntFile = null;

    try {
      final root = _resolveWritableRootDirectory();
      final modeDir = Directory(
        _joinPath(root.path, <String>[
          'debug',
          'last_game',
          _sanitize(gameId),
          _sanitize(mode),
        ]),
      );
      final sessionsDir = Directory(
        _joinPath(modeDir.path, <String>['sessions']),
      );
      if (!sessionsDir.existsSync()) {
        sessionsDir.createSync(recursive: true);
      }

      _sessionFile = File(
        _joinPath(sessionsDir.path, <String>['$_sessionId.jsonl']),
      );
      _latestFile = File(_joinPath(modeDir.path, <String>['latest.jsonl']));
      _latestSummaryFile = File(
        _joinPath(modeDir.path, <String>['latest_summary.json']),
      );

      if (_latestFile!.existsSync()) {
        _latestFile!.deleteSync();
      }
      _latestFile!.createSync(recursive: true);

      _bughuntFile = _resolveBughuntFile(root: root);
      if (_bughuntFile != null && !_bughuntFile!.existsSync()) {
        _bughuntFile!.createSync(recursive: true);
      }
    } catch (_) {
      // Swallow path or permissions failures. Session logic should continue.
      _sessionFile = null;
      _latestFile = null;
      _latestSummaryFile = null;
      _bughuntFile = null;
    }

    if (!_emittedAppStart) {
      _emittedAppStart = true;
      logBughuntEvent(
        'app_start',
        payload: <String, Object?>{
          'applicationId': applicationId,
          'modeLabel': mode,
        },
      );
      logBughuntEvent('bughunt_config', payload: _activeConfig().toJson());
    }

    logBughuntEvent(
      'session_created',
      payload: <String, Object?>{
        'sessionLabel': sessionLabel,
        'sessionId': _sessionId,
        ...context,
      },
    );
  }

  void setRoomOrMatchId(String? value) {
    if (value == null || value.trim().isEmpty) {
      return;
    }
    _runtimeRoomOrMatchId = value.trim();
    _writeNoopEvent(
      eventType: 'session_joined',
      payload: <String, Object?>{'roomIdOrMatchId': _runtimeRoomOrMatchId},
    );
  }

  void setProgress({int? turnIndex, int? actionIndexOrPlyIndex}) {
    if (turnIndex != null && turnIndex >= 0) {
      _turnIndex = turnIndex;
    }
    if (actionIndexOrPlyIndex != null && actionIndexOrPlyIndex >= 0) {
      _actionIndexOrPlyIndex = actionIndexOrPlyIndex;
    }
  }

  void logEvent(
    String event, {
    Map<String, Object?> data = const <String, Object?>{},
  }) {
    final mappedType = _mapLegacyEventType(event);
    final severity = _legacySeverity(event);
    logBughuntEvent(
      mappedType,
      payload: <String, Object?>{'legacyEvent': event, ...data},
      severity: severity,
    );
  }

  void logBughuntEvent(
    String eventType, {
    Map<String, Object?> payload = const <String, Object?>{},
    BughuntSeverity severity = BughuntSeverity.info,
    int? turnIndex,
    int? actionIndexOrPlyIndex,
  }) {
    _writeNoopEvent(
      eventType: eventType,
      payload: payload,
      severity: severity,
      turnIndex: turnIndex,
      actionIndexOrPlyIndex: actionIndexOrPlyIndex,
    );
  }

  void recordStateSnapshot(
    Map<String, Object?> snapshot, {
    String eventType = 'state_snapshot',
    BughuntSeverity severity = BughuntSeverity.info,
    int? turnIndex,
    int? actionIndexOrPlyIndex,
  }) {
    final hash = _stateHasher.hashSnapshot(snapshot);
    final payload = <String, Object?>{
      ...snapshot,
      'stateHash': hash.value,
      'stateHashAlgorithm': hash.algorithm,
    };
    logBughuntEvent(
      eventType,
      payload: payload,
      severity: severity,
      turnIndex: turnIndex,
      actionIndexOrPlyIndex: actionIndexOrPlyIndex,
    );
  }

  void recordInvariantFailure({
    required String failureCode,
    required String message,
    Map<String, Object?> context = const <String, Object?>{},
    int? turnIndex,
    int? actionIndexOrPlyIndex,
  }) {
    logBughuntEvent(
      'invariant_failure',
      severity: BughuntSeverity.error,
      turnIndex: turnIndex,
      actionIndexOrPlyIndex: actionIndexOrPlyIndex,
      payload: <String, Object?>{
        'failureCode': failureCode,
        'message': message,
        'context': context,
      },
    );
  }

  void closeSession({
    String reason = 'session_closed',
    Map<String, Object?> summary = const <String, Object?>{},
  }) {
    if (_sessionId == null || _latestSummaryFile == null) {
      return;
    }
    logBughuntEvent(
      'session_complete',
      payload: <String, Object?>{'reason': reason, ...summary},
    );

    final summaryPayload = <String, Object?>{
      'ts': _utcNow().toIso8601String(),
      'app': applicationId,
      'game': gameId,
      'mode': mode,
      'sessionId': _sessionId,
      'reason': reason,
      'summary': summary,
      'runId': _runId,
    };
    try {
      _latestSummaryFile!.writeAsStringSync(
        const JsonEncoder.withIndent('  ').convert(summaryPayload),
        flush: true,
      );
    } catch (_) {
      // Best-effort summary output.
    }
  }

  String get pidString {
    final raw = pid;
    return raw >= 0 ? raw.toString() : 'unknown';
  }

  void _writeNoopEvent({
    required String eventType,
    required Map<String, Object?> payload,
    BughuntSeverity severity = BughuntSeverity.info,
    int? turnIndex,
    int? actionIndexOrPlyIndex,
  }) {
    if (_sessionId == null || _runId == null) {
      return;
    }

    final resolvedTurn =
        turnIndex ?? _readInt(payload['turnIndex']) ?? _turnIndex;
    final resolvedAction =
        actionIndexOrPlyIndex ??
        _readInt(payload['actionIndexOrPlyIndex']) ??
        _actionIndexOrPlyIndex;
    _turnIndex = resolvedTurn;
    _actionIndexOrPlyIndex = resolvedAction;
    _logicalTick += 1;

    final metadata = _currentMetadata();
    final event = SessionEvent(
      schemaVersion: bughuntSchemaVersion,
      runId: metadata.runId,
      sessionId: metadata.sessionId,
      game: metadata.game,
      appVersionOrCommitSha: metadata.appVersionOrCommitSha,
      mode: metadata.mode,
      role: metadata.role,
      roomIdOrMatchId: _resolveRoomOrMatchId(payload),
      seed: metadata.seed,
      maxTurns: metadata.maxTurns,
      deviceInfo: metadata.deviceInfo,
      logicalTick: _logicalTick,
      wallClockTs: _utcNow().toIso8601String(),
      turnIndex: resolvedTurn,
      actionIndexOrPlyIndex: resolvedAction,
      eventType: eventType,
      payload: payload,
      severity: severity,
    );

    final line = sessionEventToJsonLine(event);
    try {
      _sessionFile?.writeAsStringSync(line, mode: FileMode.append, flush: true);
      _latestFile?.writeAsStringSync(line, mode: FileMode.append, flush: true);
      _bughuntFile?.writeAsStringSync(line, mode: FileMode.append, flush: true);
    } catch (_) {
      // Logging must never break gameplay; swallow IO failures.
    }
  }

  SessionMetadata _currentMetadata() {
    final config = _activeConfig();
    return SessionMetadata(
      schemaVersion: bughuntSchemaVersion,
      runId: _runId ?? 'unknown',
      sessionId: _sessionId ?? 'unknown',
      game: gameId,
      mode: config.mode,
      role: config.role,
      appVersionOrCommitSha:
          config.appVersionOrCommitSha ?? appVersionOrCommitSha,
      roomIdOrMatchId:
          _runtimeRoomOrMatchId ?? config.roomIdOrMatchId ?? roomIdOrMatchId,
      seed: config.seed ?? seed,
      maxTurns: config.maxTurns ?? maxTurns,
      deviceInfo: <String, Object?>{
        'os': Platform.operatingSystem,
        'osVersion': Platform.operatingSystemVersion,
        'dartVersion': Platform.version,
        'pid': pid,
        'executable': Platform.executable,
      },
    );
  }

  BughuntConfig _activeConfig() {
    final explicit = bughuntConfig;
    if (explicit != null) {
      return explicit;
    }
    return BughuntConfig(
      runId: _runId ?? _resolveRunId(_utcNow()),
      mode: _resolveMode(mode),
      role: _resolveRole(mode),
      seed: seed ?? _readInt(Platform.environment['BULLETHOLE_BUGHUNT_SEED']),
      maxTurns:
          maxTurns ??
          _readInt(Platform.environment['BULLETHOLE_BUGHUNT_MAX_TURNS']),
      roomIdOrMatchId:
          roomIdOrMatchId ?? Platform.environment['BULLETHOLE_BUGHUNT_ROOM'],
      appVersionOrCommitSha:
          appVersionOrCommitSha ??
          Platform.environment['BULLETHOLE_COMMIT_SHA'],
    );
  }

  String _resolveRunId(DateTime nowUtc) {
    final explicit = bughuntConfig?.runId;
    if (explicit != null && explicit.trim().isNotEmpty) {
      return _sanitize(explicit);
    }
    final env = Platform.environment['BULLETHOLE_BUGHUNT_RUN_ID'];
    if (env != null && env.trim().isNotEmpty) {
      return _sanitize(env);
    }
    return 'run_${_compactTimestamp(nowUtc)}';
  }

  File? _resolveBughuntFile({required Directory root}) {
    final runId = _runId;
    if (runId == null || runId.trim().isEmpty) {
      return null;
    }
    final config = _activeConfig();
    final modeLabel = config.mode.name;
    final roleLabel = config.role.name.toLowerCase();
    final path = _joinPath(root.path, <String>[
      'artifacts',
      'bughunt',
      _sanitize(runId),
      _sanitize(gameId),
      _sanitize(modeLabel),
      '$roleLabel.jsonl',
    ]);
    return File(path);
  }

  String _resolveRoomOrMatchId(Map<String, Object?> payload) {
    final payloadValue = payload['roomIdOrMatchId']?.toString();
    if (payloadValue != null && payloadValue.trim().isNotEmpty) {
      return payloadValue.trim();
    }
    final runtimeValue = _runtimeRoomOrMatchId;
    if (runtimeValue != null && runtimeValue.trim().isNotEmpty) {
      return runtimeValue.trim();
    }
    final configValue = _activeConfig().roomIdOrMatchId;
    if (configValue != null && configValue.trim().isNotEmpty) {
      return configValue.trim();
    }
    return roomIdOrMatchId ?? '';
  }

  Directory _resolveWritableRootDirectory() {
    final candidates = <Directory>[];
    final override = Platform.environment['BULLETHOLE_LOG_ROOT'];
    if (override != null && override.trim().isNotEmpty) {
      candidates.add(Directory(override.trim()));
    }
    candidates.add(_resolveProjectRootDirectory());
    final executableDirectory = _resolveExecutableDirectory();
    if (executableDirectory != null) {
      candidates.add(executableDirectory);
    }
    candidates.add(Directory.systemTemp);

    for (final candidate in candidates) {
      final absolute = candidate.absolute;
      if (_isDirectoryWritable(absolute)) {
        return absolute;
      }
    }
    return Directory.current.absolute;
  }

  Directory _resolveProjectRootDirectory() {
    var candidate = Directory.current.absolute;
    for (var i = 0; i < 12; i++) {
      final pubspec = File(_joinPath(candidate.path, <String>['pubspec.yaml']));
      if (pubspec.existsSync()) {
        return candidate;
      }
      final parent = candidate.parent;
      if (parent.path == candidate.path) {
        break;
      }
      candidate = parent;
    }
    return Directory.current.absolute;
  }

  Directory? _resolveExecutableDirectory() {
    try {
      final resolved = Platform.resolvedExecutable;
      if (resolved.trim().isEmpty) {
        return null;
      }
      return File(resolved).parent.absolute;
    } catch (_) {
      return null;
    }
  }

  bool _isDirectoryWritable(Directory directory) {
    final probeDir = Directory(
      _joinPath(directory.path, <String>[
        'artifacts',
        'bughunt',
        '.write_probe',
      ]),
    );
    final probeFile = File(
      _joinPath(probeDir.path, <String>[
        'probe_${pidString}_${DateTime.now().millisecondsSinceEpoch}',
      ]),
    );
    try {
      if (!probeDir.existsSync()) {
        probeDir.createSync(recursive: true);
      }
      probeFile.writeAsStringSync('ok', flush: true);
      if (probeFile.existsSync()) {
        probeFile.deleteSync();
      }
      return true;
    } catch (_) {
      return false;
    }
  }

  String _mapLegacyEventType(String event) {
    final normalized = event.trim().toLowerCase();
    if (normalized == 'session_start') {
      return 'session_created';
    }
    if (normalized == 'session_end') {
      return 'session_complete';
    }
    if (normalized.contains('controller_initialized')) {
      return 'app_start';
    }
    if (normalized.contains('connection') ||
        normalized.contains('matchmaking')) {
      return 'connection_state';
    }
    if (normalized == 'disconnect' || normalized.contains('opponent_left')) {
      return 'disconnect';
    }
    if (normalized.contains('reconnect')) {
      return 'reconnect';
    }
    if (normalized.contains('queue') &&
        (normalized.contains('set') || normalized.contains('queued'))) {
      return 'action_queued';
    }
    if (normalized.contains('queue') &&
        (normalized.contains('cleared') || normalized.contains('cancel'))) {
      return 'action_cancelled';
    }
    if (normalized.contains('queue') &&
        (normalized.contains('invalid') || normalized.contains('reject'))) {
      return 'action_rejected';
    }
    if (normalized.contains('executing') || normalized.contains('sent')) {
      return 'action_launched';
    }
    if (normalized.contains('move_applied') ||
        normalized.contains('state_applied') ||
        normalized.contains('confirmed')) {
      return 'action_applied';
    }
    if (normalized.contains('state') || normalized.contains('snapshot')) {
      return 'state_snapshot';
    }
    if (normalized.contains('invalid') || normalized.contains('failed')) {
      return 'invariant_failure';
    }
    return event;
  }

  BughuntSeverity _legacySeverity(String event) {
    final normalized = event.trim().toLowerCase();
    if (normalized.contains('failed') ||
        normalized.contains('error') ||
        normalized.contains('invalid')) {
      return BughuntSeverity.error;
    }
    if (normalized.contains('warn')) {
      return BughuntSeverity.warn;
    }
    return BughuntSeverity.info;
  }

  BughuntMode _resolveMode(String rawMode) {
    final normalized = rawMode.trim().toLowerCase();
    if (normalized == 'online') {
      return BughuntMode.online;
    }
    if (normalized.contains('ai')) {
      return BughuntMode.ai;
    }
    return BughuntMode.local;
  }

  BughuntRole _resolveRole(String rawMode) {
    final env = Platform.environment['BULLETHOLE_BUGHUNT_ROLE'];
    final parsed = parseBughuntRole(env);
    if (parsed != null) {
      return parsed;
    }

    final normalized = rawMode.trim().toLowerCase();
    if (normalized == 'online') {
      return BughuntRole.client;
    }
    if (normalized.contains('local')) {
      return BughuntRole.localA;
    }
    if (normalized.contains('ai')) {
      return BughuntRole.localA;
    }
    return BughuntRole.localA;
  }

  DateTime _utcNow() => DateTime.now().toUtc();

  int? _readInt(Object? raw) {
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

  static String _compactTimestamp(DateTime ts) {
    return '${ts.year.toString().padLeft(4, '0')}'
        '${ts.month.toString().padLeft(2, '0')}'
        '${ts.day.toString().padLeft(2, '0')}_'
        '${ts.hour.toString().padLeft(2, '0')}'
        '${ts.minute.toString().padLeft(2, '0')}'
        '${ts.second.toString().padLeft(2, '0')}';
  }

  static String _sanitize(String raw) {
    final normalized = raw.trim().toLowerCase();
    if (normalized.isEmpty) {
      return 'unknown';
    }
    return normalized.replaceAll(RegExp(r'[^a-z0-9._-]+'), '_');
  }

  static String _joinPath(String root, List<String> parts) {
    final separator = Platform.pathSeparator;
    final suffix = parts
        .map((part) => part.trim())
        .where((part) => part.isNotEmpty)
        .join(separator);
    if (suffix.isEmpty) {
      return root;
    }
    if (root.endsWith(separator)) {
      return '$root$suffix';
    }
    return '$root$separator$suffix';
  }
}
