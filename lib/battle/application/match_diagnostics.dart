import 'dart:convert';

import 'match_diagnostics_storage_io.dart'
    if (dart.library.html) 'match_diagnostics_storage_web.dart'
    as storage;

import 'package:puredots_turn_engine/puredots_turn_engine.dart';

class MatchDiagnosticsSnapshot {
  const MatchDiagnosticsSnapshot({
    required this.savedAtIsoUtc,
    required this.turnNumber,
    required this.winnerId,
    required this.eventLog,
    required this.appliedByType,
    required this.deniedByType,
    required this.deniedByReason,
    required this.appliedCommands,
    required this.deniedCommands,
    required this.destroyedEvents,
    required this.directHitEvents,
    required this.attackDeclarations,
  });

  final String savedAtIsoUtc;
  final int turnNumber;
  final String winnerId;
  final List<String> eventLog;
  final Map<String, int> appliedByType;
  final Map<String, int> deniedByType;
  final Map<String, int> deniedByReason;
  final int appliedCommands;
  final int deniedCommands;
  final int destroyedEvents;
  final int directHitEvents;
  final int attackDeclarations;

  Map<String, Object?> toJson() {
    return <String, Object?>{
      'savedAtIsoUtc': savedAtIsoUtc,
      'turnNumber': turnNumber,
      'winnerId': winnerId,
      'eventLog': eventLog,
      'appliedByType': appliedByType,
      'deniedByType': deniedByType,
      'deniedByReason': deniedByReason,
      'appliedCommands': appliedCommands,
      'deniedCommands': deniedCommands,
      'destroyedEvents': destroyedEvents,
      'directHitEvents': directHitEvents,
      'attackDeclarations': attackDeclarations,
    };
  }

  factory MatchDiagnosticsSnapshot.fromJson(Map<String, Object?> json) {
    Map<String, int> readIntMap(String key) {
      final source = (json[key] as Map?) ?? const <Object?, Object?>{};
      final out = <String, int>{};
      source.forEach((k, v) {
        if (k is String && v is num) {
          out[k] = v.toInt();
        }
      });
      return out;
    }

    return MatchDiagnosticsSnapshot(
      savedAtIsoUtc: (json['savedAtIsoUtc'] as String?) ?? '',
      turnNumber: (json['turnNumber'] as num?)?.toInt() ?? 0,
      winnerId: (json['winnerId'] as String?) ?? '',
      eventLog: ((json['eventLog'] as List?) ?? const <Object?>[])
          .whereType<String>()
          .toList(growable: false),
      appliedByType: readIntMap('appliedByType'),
      deniedByType: readIntMap('deniedByType'),
      deniedByReason: readIntMap('deniedByReason'),
      appliedCommands: (json['appliedCommands'] as num?)?.toInt() ?? 0,
      deniedCommands: (json['deniedCommands'] as num?)?.toInt() ?? 0,
      destroyedEvents: (json['destroyedEvents'] as num?)?.toInt() ?? 0,
      directHitEvents: (json['directHitEvents'] as num?)?.toInt() ?? 0,
      attackDeclarations: (json['attackDeclarations'] as num?)?.toInt() ?? 0,
    );
  }
}

class MatchDiagnosticsStore {
  MatchDiagnosticsStore({String? filePath})
    : _filePath = storage.resolveDiagnosticsPath(filePath);

  static const int maxSavedMatches = 5;

  final String _filePath;

  String get filePath => _filePath;

  List<MatchDiagnosticsSnapshot> loadRecent() {
    final raw = storage.readDiagnostics(_filePath);
    if (raw == null || raw.isEmpty) {
      return const <MatchDiagnosticsSnapshot>[];
    }
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! List) {
        return const <MatchDiagnosticsSnapshot>[];
      }
      return decoded
          .whereType<Map>()
          .map(
            (entry) => MatchDiagnosticsSnapshot.fromJson(
              entry.cast<String, Object?>(),
            ),
          )
          .take(maxSavedMatches)
          .toList(growable: false);
    } catch (_) {
      return const <MatchDiagnosticsSnapshot>[];
    }
  }

  List<MatchDiagnosticsSnapshot> saveFinishedMatch({
    required GameState state,
    required int deniedCommands,
    required Map<String, int> deniedByType,
    required Map<String, int> deniedByReason,
  }) {
    final appliedByType = <String, int>{};
    for (final entry in state.history) {
      appliedByType.update(
        entry.commandType,
        (value) => value + 1,
        ifAbsent: () => 1,
      );
    }

    final snapshot = MatchDiagnosticsSnapshot(
      savedAtIsoUtc: DateTime.now().toUtc().toIso8601String(),
      turnNumber: state.turnNumber,
      winnerId: state.winnerIndex == null
          ? ''
          : state.players[state.winnerIndex!].id,
      eventLog: List<String>.from(state.eventLog, growable: false),
      appliedByType: appliedByType,
      deniedByType: Map<String, int>.from(deniedByType),
      deniedByReason: Map<String, int>.from(deniedByReason),
      appliedCommands: state.history.length,
      deniedCommands: deniedCommands,
      destroyedEvents: state.eventLog
          .where((line) => line.contains(' destroyed '))
          .length,
      directHitEvents: state.eventLog
          .where((line) => line.contains(' directly for '))
          .length,
      attackDeclarations: state.eventLog
          .where((line) => line.contains('declared an attack'))
          .length,
    );

    final updated = <MatchDiagnosticsSnapshot>[
      snapshot,
      ...loadRecent(),
    ].take(maxSavedMatches).toList(growable: false);
    _write(updated);
    return updated;
  }

  void _write(List<MatchDiagnosticsSnapshot> snapshots) {
    final encoded = const JsonEncoder.withIndent(
      '  ',
    ).convert(snapshots.map((entry) => entry.toJson()).toList(growable: false));
    storage.writeDiagnostics(_filePath, encoded);
  }
}
