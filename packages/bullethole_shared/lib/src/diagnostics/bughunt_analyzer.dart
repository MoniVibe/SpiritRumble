import 'dart:convert';
import 'dart:io';

import 'bughunt_contract.dart';
import 'bughunt_invariants.dart';

class BughuntAnalysisResult {
  const BughuntAnalysisResult({
    required this.summary,
    required this.failures,
    required this.events,
    required this.secondaryEvents,
  });

  final SessionSummary summary;
  final List<InvariantFailure> failures;
  final List<SessionEvent> events;
  final List<SessionEvent> secondaryEvents;
}

class BughuntAnalyzer {
  const BughuntAnalyzer({
    this.queueResolutionMaxTicks = 30,
    this.gateConfig = const BughuntGateConfig(),
  });

  final int queueResolutionMaxTicks;
  final BughuntGateConfig gateConfig;

  BughuntAnalysisResult analyze({
    required List<SessionEvent> primary,
    List<SessionEvent> secondary = const <SessionEvent>[],
    String? notes,
  }) {
    final merged = <SessionEvent>[...primary, ...secondary]
      ..sort(_compareEvents);

    final invariantEngine = BughuntInvariantEngine(
      queueResolutionMaxTicks: queueResolutionMaxTicks,
    );
    final failures = <InvariantFailure>[
      ..._collectExplicitInvariantFailures(merged),
      ...invariantEngine.evaluate(merged),
      if (secondary.isNotEmpty)
        ...invariantEngine.detectDesync(left: primary, right: secondary),
    ];

    final hasCompletion = merged.any(
      (event) => event.eventType == 'session_complete',
    );
    final completionRate = hasCompletion ? 1.0 : 0.0;
    final sessions = {
      ...primary.map((event) => event.sessionId),
      ...secondary.map((event) => event.sessionId),
    }.length;
    final crashCount = merged
        .where((event) => event.eventType == 'crash')
        .length;
    final desyncCount = failures
        .where((failure) => failure.failureCode == invariantHostClientDesync)
        .length;
    final verdict = _computeVerdict(
      mergedIsEmpty: merged.isEmpty,
      sessions: sessions,
      completionRate: completionRate,
      crashCount: crashCount,
      failureCodes: failures.map((failure) => failure.failureCode).toSet(),
      desyncCount: desyncCount,
    );

    final first = merged.isEmpty ? null : merged.first;
    final summary = SessionSummary(
      runId: first?.runId ?? 'unknown',
      game: first?.game ?? 'unknown',
      mode: first?.mode ?? BughuntMode.local,
      sessions: sessions,
      failures: failures.length,
      verdict: verdict,
      completionRate: completionRate,
      crashCount: crashCount,
      desyncCount: desyncCount,
      invariantFailureCount: failures.length,
      failureCodes:
          failures.map((failure) => failure.failureCode).toSet().toList()
            ..sort(),
      notes: <String>[
        if (notes != null && notes.trim().isNotEmpty) notes.trim(),
      ],
    );

    return BughuntAnalysisResult(
      summary: summary,
      failures: failures,
      events: primary,
      secondaryEvents: secondary,
    );
  }

  List<SessionEvent> readJsonl(String path) {
    final file = File(path);
    if (!file.existsSync()) {
      return const <SessionEvent>[];
    }
    final events = <SessionEvent>[];
    for (final line in file.readAsLinesSync()) {
      final trimmed = line.trim();
      if (trimmed.isEmpty) {
        continue;
      }
      try {
        final decoded = jsonDecode(trimmed);
        final parsed = SessionEvent.tryParse(decoded);
        if (parsed != null) {
          events.add(parsed);
        }
      } catch (_) {
        // Analyzer is best-effort; malformed line is ignored.
      }
    }
    return events;
  }

  void writeOutputs({
    required String outputDirectory,
    required BughuntAnalysisResult result,
    String? reproductionCommand,
  }) {
    final directory = Directory(outputDirectory);
    if (!directory.existsSync()) {
      directory.createSync(recursive: true);
    }

    final summaryFile = File(_joinPath(directory.path, 'summary.json'));
    summaryFile.writeAsStringSync(
      const JsonEncoder.withIndent('  ').convert(result.summary.toJson()),
    );

    final reportFile = File(_joinPath(directory.path, 'report.md'));
    reportFile.writeAsStringSync(
      _buildReportMarkdown(
        result: result,
        reproductionCommand: reproductionCommand,
      ),
    );
  }

  String _buildReportMarkdown({
    required BughuntAnalysisResult result,
    required String? reproductionCommand,
  }) {
    final summary = result.summary;
    final buffer = StringBuffer()
      ..writeln('# Bughunt Report')
      ..writeln('')
      ..writeln('- Verdict: **${summary.verdict.name.toUpperCase()}**')
      ..writeln('- Game: `${summary.game}`')
      ..writeln('- Mode: `${summary.mode.name}`')
      ..writeln('- Run: `${summary.runId}`')
      ..writeln('- Sessions: `${summary.sessions}`')
      ..writeln('- Failures: `${summary.failures}`')
      ..writeln('- Crashes: `${summary.crashCount}`')
      ..writeln('- Desyncs: `${summary.desyncCount}`')
      ..writeln(
        '- Completion Rate: `${summary.completionRate.toStringAsFixed(2)}`',
      )
      ..writeln('');

    if (summary.failureCodes.isNotEmpty) {
      buffer
        ..writeln('## Failure Signatures')
        ..writeln('');
      for (final code in summary.failureCodes) {
        buffer.writeln('- `$code`');
      }
      buffer.writeln('');
    }

    if (result.failures.isNotEmpty) {
      final first = result.failures.first;
      buffer
        ..writeln('## First Bad Event')
        ..writeln('')
        ..writeln('- Code: `${first.failureCode}`')
        ..writeln('- Message: ${first.message}')
        ..writeln('- Session: `${first.sessionId}`')
        ..writeln('- Tick: `${first.logicalTick}`')
        ..writeln('- Turn: `${first.turnIndex}`')
        ..writeln('- Action/Ply: `${first.actionIndexOrPlyIndex}`')
        ..writeln('');
    }

    if (reproductionCommand != null && reproductionCommand.trim().isNotEmpty) {
      buffer
        ..writeln('## Reproduction')
        ..writeln('')
        ..writeln('```bash')
        ..writeln(reproductionCommand.trim())
        ..writeln('```')
        ..writeln('');
    }

    return buffer.toString();
  }

  List<InvariantFailure> _collectExplicitInvariantFailures(
    List<SessionEvent> events,
  ) {
    final failures = <InvariantFailure>[];
    for (final event in events) {
      if (event.eventType != 'invariant_failure') {
        continue;
      }
      final code =
          event.payload['failureCode']?.toString() ?? 'INVARIANT_FAILURE';
      final message =
          event.payload['message']?.toString() ??
          'Invariant failure emitted by game runtime.';
      failures.add(
        InvariantFailure(
          failureCode: code,
          message: message,
          runId: event.runId,
          sessionId: event.sessionId,
          game: event.game,
          mode: event.mode,
          role: event.role,
          logicalTick: event.logicalTick,
          turnIndex: event.turnIndex,
          actionIndexOrPlyIndex: event.actionIndexOrPlyIndex,
          seed: event.seed,
          context: event.payload,
        ),
      );
    }
    return failures;
  }

  BughuntGateVerdict _computeVerdict({
    required bool mergedIsEmpty,
    required int sessions,
    required double completionRate,
    required int crashCount,
    required Set<String> failureCodes,
    required int desyncCount,
  }) {
    if (mergedIsEmpty) {
      return BughuntGateVerdict.blocked;
    }

    if (_isBlockedByPolicy(failureCodes)) {
      return BughuntGateVerdict.blocked;
    }

    final minSessions = gateConfig.minSessions;
    if (minSessions != null && sessions < minSessions) {
      return BughuntGateVerdict.fail;
    }
    if (completionRate < gateConfig.minCompletionRate) {
      return BughuntGateVerdict.fail;
    }
    if (gateConfig.requireZeroCrashes && crashCount > 0) {
      return BughuntGateVerdict.fail;
    }
    if (gateConfig.requireZeroInvariantFailures && failureCodes.isNotEmpty) {
      return BughuntGateVerdict.fail;
    }
    if (gateConfig.requireZeroDesyncs && desyncCount > 0) {
      return BughuntGateVerdict.fail;
    }
    return BughuntGateVerdict.pass;
  }

  bool _isBlockedByPolicy(Set<String> failureCodes) {
    final blockedCodes = gateConfig.blockedFailureCodes.toSet();
    if (blockedCodes.isEmpty || failureCodes.isEmpty) {
      return false;
    }
    final hasBlockedCode = failureCodes.any(blockedCodes.contains);
    if (!hasBlockedCode) {
      return false;
    }
    final hasNonBlockedCode = failureCodes.any(
      (code) => !blockedCodes.contains(code),
    );
    return !hasNonBlockedCode;
  }

  int _compareEvents(SessionEvent left, SessionEvent right) {
    final byTick = left.logicalTick.compareTo(right.logicalTick);
    if (byTick != 0) {
      return byTick;
    }
    final byTurn = left.turnIndex.compareTo(right.turnIndex);
    if (byTurn != 0) {
      return byTurn;
    }
    final byAction = left.actionIndexOrPlyIndex.compareTo(
      right.actionIndexOrPlyIndex,
    );
    if (byAction != 0) {
      return byAction;
    }
    return left.wallClockTs.compareTo(right.wallClockTs);
  }

  String _joinPath(String root, String child) {
    if (root.endsWith(Platform.pathSeparator)) {
      return '$root$child';
    }
    return '$root${Platform.pathSeparator}$child';
  }
}
