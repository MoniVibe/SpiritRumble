import 'bughunt_contract.dart';

const String invariantSideOwnershipSwitch = 'SIDE_OWNERSHIP_SWITCH';
const String invariantQueueStuckTimeout = 'QUEUE_STUCK_TIMEOUT';
const String invariantTurnOwnershipViolation = 'TURN_OWNERSHIP_VIOLATION';
const String invariantCooldownNonMonotonic = 'COOLDOWN_NON_MONOTONIC';
const String invariantSnapshotHashInvalid = 'SNAPSHOT_HASH_INVALID';
const String invariantHostClientDesync = 'HOST_CLIENT_DESYNC';
const String invariantDisconnectReasonMissing = 'DISCONNECT_REASON_MISSING';
const String invariantSessionTerminationInvalid = 'SESSION_TERMINATION_INVALID';

class BughuntInvariantEngine {
  const BughuntInvariantEngine({this.queueResolutionMaxTicks = 30});

  final int queueResolutionMaxTicks;

  List<InvariantFailure> evaluate(List<SessionEvent> events) {
    final failures = <InvariantFailure>[];
    final queueByKey = <String, SessionEvent>{};
    final cooldownByColor = <String, int>{};
    final pieceOwnerById = <String, String>{};
    var sawSessionComplete = false;

    for (final event in events) {
      if (event.eventType == 'session_complete') {
        sawSessionComplete = true;
      }

      if (event.eventType == 'state_snapshot') {
        final stateHash = event.payload['stateHash']?.toString();
        final snapshotHashValid = event.payload['snapshotHashValid'];
        if (stateHash == null || stateHash.trim().isEmpty) {
          failures.add(
            _failure(
              event: event,
              code: invariantSnapshotHashInvalid,
              message: 'State snapshot must include a non-empty stateHash.',
            ),
          );
        }
        if (snapshotHashValid == false) {
          failures.add(
            _failure(
              event: event,
              code: invariantSnapshotHashInvalid,
              message: 'Snapshot explicitly marked as invalid.',
              context: <String, Object?>{'payload': event.payload},
            ),
          );
        }
        _collectOwnershipSwitchFailures(
          event: event,
          knownOwners: pieceOwnerById,
          failures: failures,
        );
      }

      if (event.eventType == 'disconnect') {
        final reason = event.payload['reason']?.toString().trim();
        final message = event.payload['message']?.toString().trim();
        final hasReason =
            (reason != null && reason.isNotEmpty) ||
            (message != null && message.isNotEmpty);
        if (!hasReason) {
          failures.add(
            _failure(
              event: event,
              code: invariantDisconnectReasonMissing,
              message: 'Disconnect event must include a reason.',
            ),
          );
        }
      }

      if (event.eventType == 'action_queued') {
        queueByKey[_queueKey(event)] = event;
      }
      if (event.eventType == 'action_launched' ||
          event.eventType == 'action_applied' ||
          event.eventType == 'action_cancelled' ||
          event.eventType == 'action_rejected') {
        queueByKey.remove(_queueKey(event));
      }

      if (event.eventType == 'action_queued' ||
          event.eventType == 'action_launched' ||
          event.eventType == 'action_applied') {
        final actorColor = event.payload['actorColor']?.toString().trim();
        final turnColor =
            event.payload['turnColor']?.toString().trim() ??
            event.payload['expectedTurnColor']?.toString().trim();
        if (actorColor != null &&
            turnColor != null &&
            actorColor.isNotEmpty &&
            turnColor.isNotEmpty &&
            actorColor != turnColor) {
          failures.add(
            _failure(
              event: event,
              code: invariantTurnOwnershipViolation,
              message: 'Action actorColor does not match active turnColor.',
              context: <String, Object?>{
                'actorColor': actorColor,
                'turnColor': turnColor,
              },
            ),
          );
        }
      }

      final whiteRemaining = _readInt(event.payload['whiteRemainingMs']);
      if (whiteRemaining != null) {
        final key = 'w:${event.turnIndex}';
        final previous = cooldownByColor[key];
        if (previous != null && whiteRemaining > previous) {
          failures.add(
            _failure(
              event: event,
              code: invariantCooldownNonMonotonic,
              message: 'White cooldown increased inside same turn window.',
              context: <String, Object?>{
                'previous': previous,
                'current': whiteRemaining,
              },
            ),
          );
        }
        cooldownByColor[key] = whiteRemaining;
      }

      final blackRemaining = _readInt(event.payload['blackRemainingMs']);
      if (blackRemaining != null) {
        final key = 'b:${event.turnIndex}';
        final previous = cooldownByColor[key];
        if (previous != null && blackRemaining > previous) {
          failures.add(
            _failure(
              event: event,
              code: invariantCooldownNonMonotonic,
              message: 'Black cooldown increased inside same turn window.',
              context: <String, Object?>{
                'previous': previous,
                'current': blackRemaining,
              },
            ),
          );
        }
        cooldownByColor[key] = blackRemaining;
      }
    }

    for (final queued in queueByKey.values) {
      final lastTick = events.isEmpty
          ? queued.logicalTick
          : events.last.logicalTick;
      if (lastTick - queued.logicalTick >= queueResolutionMaxTicks) {
        failures.add(
          _failure(
            event: queued,
            code: invariantQueueStuckTimeout,
            message:
                'Queued action was not resolved within queueResolutionMaxTicks.',
          ),
        );
      }
    }

    if (events.isNotEmpty && !sawSessionComplete) {
      final last = events.last;
      failures.add(
        _failure(
          event: last,
          code: invariantSessionTerminationInvalid,
          message: 'Session ended without session_complete event.',
        ),
      );
    }

    return failures;
  }

  List<InvariantFailure> detectDesync({
    required List<SessionEvent> left,
    required List<SessionEvent> right,
  }) {
    final failures = <InvariantFailure>[];
    final rightBySyncKey = <String, SessionEvent>{};
    for (final event in right) {
      if (event.eventType != 'state_snapshot') {
        continue;
      }
      final key = _snapshotSyncKey(event);
      if (key == null) {
        continue;
      }
      rightBySyncKey[key] = event;
    }

    for (final leftEvent in left) {
      if (leftEvent.eventType != 'state_snapshot') {
        continue;
      }
      final syncKey = _snapshotSyncKey(leftEvent);
      if (syncKey == null) {
        continue;
      }
      final rightEvent = rightBySyncKey[syncKey];
      if (rightEvent == null) {
        continue;
      }
      final leftHash = leftEvent.payload['stateHash']?.toString();
      final rightHash = rightEvent.payload['stateHash']?.toString();
      if (leftHash == null || rightHash == null) {
        continue;
      }
      if (leftHash != rightHash) {
        failures.add(
          _failure(
            event: leftEvent,
            code: invariantHostClientDesync,
            message: 'Host/client snapshot hash mismatch.',
            context: <String, Object?>{
              'leftHash': leftHash,
              'rightHash': rightHash,
              'rightSessionId': rightEvent.sessionId,
            },
          ),
        );
      }
    }

    return failures;
  }

  String? _snapshotSyncKey(SessionEvent event) {
    final roomOrMatchId = _normalizedRoomOrMatchId(event);
    final sequence = _readInt(event.payload['sequence']);
    if (sequence != null) {
      return '$roomOrMatchId:seq:$sequence';
    }
    final historyLen = _readInt(event.payload['historyLen']);
    if (historyLen != null) {
      return '$roomOrMatchId:ply:$historyLen';
    }
    final actionIndex = event.actionIndexOrPlyIndex;
    if (actionIndex > 0) {
      return '$roomOrMatchId:action:$actionIndex';
    }
    return null;
  }

  String _normalizedRoomOrMatchId(SessionEvent event) {
    final fromEvent = event.roomIdOrMatchId?.trim() ?? '';
    if (fromEvent.isNotEmpty) {
      return fromEvent;
    }
    final fromPayload = event.payload['matchId']?.toString().trim() ?? '';
    if (fromPayload.isNotEmpty) {
      return fromPayload;
    }
    return event.sessionId;
  }

  String _queueKey(SessionEvent event) {
    final queueToken = event.payload['queueToken'];
    if (queueToken != null) {
      return '${event.sessionId}:${queueToken.toString()}';
    }
    final from = event.payload['from']?.toString() ?? '-';
    final to = event.payload['to']?.toString() ?? '-';
    return '${event.sessionId}:$from->$to:${event.turnIndex}';
  }

  void _collectOwnershipSwitchFailures({
    required SessionEvent event,
    required Map<String, String> knownOwners,
    required List<InvariantFailure> failures,
  }) {
    final ownershipRaw =
        event.payload['pieceOwners'] ??
        event.payload['checkerOwners'] ??
        event.payload['ownershipByPiece'];
    if (ownershipRaw is! Map) {
      return;
    }
    final ownership = Map<String, dynamic>.from(ownershipRaw);
    for (final entry in ownership.entries) {
      final pieceId = entry.key.trim();
      if (pieceId.isEmpty) {
        continue;
      }
      final owner = entry.value?.toString().trim().toLowerCase();
      if (owner == null || owner.isEmpty) {
        continue;
      }
      final previousOwner = knownOwners[pieceId];
      if (previousOwner != null &&
          previousOwner != owner &&
          !_isOwnershipSwapAllowed(event.payload, pieceId: pieceId)) {
        failures.add(
          _failure(
            event: event,
            code: invariantSideOwnershipSwitch,
            message: 'Piece/checker ownership switched sides unexpectedly.',
            context: <String, Object?>{
              'pieceId': pieceId,
              'previousOwner': previousOwner,
              'currentOwner': owner,
            },
          ),
        );
      }
      knownOwners[pieceId] = owner;
    }
  }

  bool _isOwnershipSwapAllowed(
    Map<String, Object?> payload, {
    required String pieceId,
  }) {
    final explicit = payload['allowOwnershipSwitch'];
    if (explicit == true) {
      return true;
    }
    final switched = payload['switchedPieces'];
    if (switched is List) {
      return switched.map((item) => item.toString()).contains(pieceId);
    }
    return false;
  }

  InvariantFailure _failure({
    required SessionEvent event,
    required String code,
    required String message,
    Map<String, Object?> context = const <String, Object?>{},
  }) {
    return InvariantFailure(
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
      context: context,
    );
  }

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
}
