import 'dart:math' as math;

import 'package:bullethole_shared/bullethole_shared.dart';
import 'package:flutter/material.dart';
import 'package:flutter/physics.dart';
import 'package:puredots_turn_engine/puredots_turn_engine.dart';

import '../../application/battle_controller.dart';
import '../../application/battle_intents.dart';
import '../../application/battle_view_state.dart';
import '../../application/drag_session.dart';
import '../../application/opponent_ai.dart';
import '../../application/target_preview.dart';
import '../../application/target_resolver.dart';
import '../../domain/battle_view_models.dart';
import '../painters/targeting_line_painter.dart';
import '../widgets/hand_zone.dart';
import '../widgets/spirit_card_view.dart';

class SpritRumbleScreen extends StatefulWidget {
  const SpritRumbleScreen({super.key});

  @override
  State<SpritRumbleScreen> createState() => _SpritRumbleScreenState();
}

class _SpritRumbleScreenState extends State<SpritRumbleScreen>
    with TickerProviderStateMixin {
  static const double _handCardWidth = 116;
  static const double _handCardHeight = 156;
  static const SpringDescription _snapSpring = SpringDescription(
    mass: 1,
    stiffness: 460,
    damping: 28,
  );

  final GlobalKey _interactionLayerKey = GlobalKey();
  final GlobalKey _newUnitDropKey = GlobalKey();
  final GlobalKey _playerHandDropKey = GlobalKey();
  final GlobalKey _opponentShamanKey = GlobalKey();
  final GlobalKey _playerShamanKey = GlobalKey();
  final Map<String, GlobalKey> _unitDropKeys = <String, GlobalKey>{};
  final Map<String, GlobalKey> _opponentUnitKeys = <String, GlobalKey>{};
  final BattleController _controller = BattleController();
  final DropTargetResolver _targetResolver = const DropTargetResolver();

  late final AnimationController _snapController;
  late final AnimationController _attackController;
  HandDragSession? _dragSession;
  DropTargetPreview? _hoverTarget;
  _AttackVisual? _attackVisual;
  Offset _snapFrom = Offset.zero;
  String? _hoverAttackTargetUnitId;
  bool _logExpanded = false;
  bool _aiRunning = false;
  bool _aiQueued = false;

  BattleViewState get _view => _controller.viewState;

  @override
  void initState() {
    super.initState();
    _snapController =
        AnimationController(vsync: this, lowerBound: 0, upperBound: 1)
          ..addListener(_onSnapTick)
          ..addStatusListener(_onSnapStatusChange);
    _attackController =
        AnimationController(
            vsync: this,
            lowerBound: 0,
            upperBound: 1,
            duration: const Duration(milliseconds: 320),
          )
          ..addListener(_onAttackTick)
          ..addStatusListener(_onAttackStatusChange);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _scheduleOpponentAiIfNeeded();
    });
  }

  @override
  void dispose() {
    _snapController.dispose();
    _attackController.dispose();
    super.dispose();
  }

  void _onSnapTick() {
    final session = _dragSession;
    if (session == null || !session.snapping) {
      return;
    }
    final t = _snapController.value.clamp(0.0, 1.0);
    setState(() {
      _dragSession = session.copyWith(
        translation: Offset.lerp(_snapFrom, Offset.zero, t)!,
      );
    });
  }

  void _onSnapStatusChange(AnimationStatus status) {
    if (status != AnimationStatus.completed) {
      return;
    }
    if (_dragSession == null || !_dragSession!.snapping) {
      return;
    }
    setState(_clearDragState);
  }

  void _onAttackTick() {
    if (_attackVisual == null) {
      return;
    }
    setState(() {});
  }

  void _onAttackStatusChange(AnimationStatus status) {
    if (status != AnimationStatus.completed) {
      return;
    }
    _attackController.reset();
    if (!mounted) {
      return;
    }
    setState(() {
      _attackVisual = null;
    });
  }

  void _resetMatch() {
    setState(() {
      _attackController.stop();
      _attackController.value = 0;
      _attackVisual = null;
      _hoverAttackTargetUnitId = null;
      _aiRunning = false;
      _aiQueued = false;
      _controller.resetMatch();
      _clearDragState();
      _logExpanded = false;
    });
    _scheduleOpponentAiIfNeeded();
  }

  bool _dispatch(GameCommand command, {bool scheduleAi = true}) {
    final applied = _controller.dispatch(command);
    setState(() {});
    if (scheduleAi) {
      _scheduleOpponentAiIfNeeded();
    }
    return applied;
  }

  void _scheduleOpponentAiIfNeeded() {
    if (_aiRunning || _aiQueued || !mounted) {
      return;
    }
    final state = _view.gameState;
    if (state.hasWinner || state.activePlayerIndex != 1) {
      return;
    }
    _aiQueued = true;
    Future<void>.delayed(const Duration(milliseconds: 220), () async {
      _aiQueued = false;
      if (!mounted) {
        return;
      }
      await _runOpponentAiTurn();
    });
  }

  Future<void> _runOpponentAiTurn() async {
    if (_aiRunning || !mounted) {
      return;
    }
    _aiRunning = true;
    try {
      var guard = 0;
      while (mounted &&
          _view.gameState.activePlayerIndex == 1 &&
          !_view.gameState.hasWinner &&
          guard < 64) {
        guard++;
        final next = OpponentAi.pickNextCommand(
          _view.gameState,
          (command) => _controller.canApply(command).allowed,
        );
        if (next == null) {
          break;
        }
        final applied = next is AttackUnitMove
            ? _performResolvedAttack(next, animate: true, scheduleAi: false)
            : _dispatch(next, scheduleAi: false);
        if (!applied) {
          break;
        }
        if (next is AttackUnitMove) {
          await _waitForAttackAnimationComplete();
          await Future<void>.delayed(const Duration(milliseconds: 120));
          continue;
        }
        await Future<void>.delayed(const Duration(milliseconds: 230));
      }
    } finally {
      _aiRunning = false;
      _scheduleOpponentAiIfNeeded();
    }
  }

  @override
  Widget build(BuildContext context) {
    final view = _view;
    final state = view.gameState;
    final winner = view.winnerIndex;

    return Scaffold(
      body: GameBackdrop(
        child: SafeArea(
          child: LayoutBuilder(
            builder: (BuildContext context, BoxConstraints constraints) {
              final flex = _BandFlex.forHeight(constraints.maxHeight);
              return Padding(
                padding: const EdgeInsets.all(8),
                child: Stack(
                  key: _interactionLayerKey,
                  children: <Widget>[
                    Column(
                      children: <Widget>[
                        Flexible(
                          flex: flex.opponentHand,
                          child: _buildOpponentHandBand(view),
                        ),
                        Flexible(
                          flex: flex.opponentShaman,
                          child: _buildShamanBand(
                            player: view.opposingPlayer,
                            isActive: state.activePlayerIndex == 1,
                            title: 'Opponent Shaman',
                            bandKey: _opponentShamanKey,
                          ),
                        ),
                        Flexible(
                          flex: flex.opponentTable,
                          child: _buildOpponentTableBand(view),
                        ),
                        Flexible(
                          flex: flex.playerTable,
                          child: _buildPlayerTableBand(view),
                        ),
                        Flexible(
                          flex: flex.playerShaman,
                          child: _buildPlayerShamanBand(view),
                        ),
                        Flexible(
                          flex: flex.playerHand,
                          child: _buildPlayerHandBand(view),
                        ),
                      ],
                    ),
                    _buildHudOverlay(state, winner),
                    _buildTargetingLineOverlay(),
                    _buildAttackAnimationOverlay(),
                    _buildEventLogOverlay(view),
                    if (view.lastError != null)
                      Positioned(
                        left: 8,
                        right: 8,
                        bottom: _logExpanded ? 268 : 56,
                        child: Card(
                          color: Theme.of(context).colorScheme.errorContainer,
                          child: Padding(
                            padding: const EdgeInsets.all(8),
                            child: Text('Rule denial: ${view.lastError}'),
                          ),
                        ),
                      ),
                  ],
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _buildHudOverlay(GameState state, int? winner) {
    return Positioned(
      left: 8,
      top: 8,
      right: 8,
      child: IgnorePointer(
        ignoring: true,
        child: Wrap(
          spacing: 6,
          runSpacing: 6,
          children: <Widget>[
            const Chip(label: Text('Sprit Rumble')),
            Chip(label: Text('Turn ${state.turnNumber}')),
            Chip(label: Text('Active: ${state.activePlayer.id}')),
            Chip(label: Text('Phase: ${phaseLabel(state.phase)}')),
            Chip(label: Text('Pool ${state.pool.length}/5')),
            if (winner != null)
              Chip(label: Text('Winner: ${state.players[winner].id}')),
          ],
        ),
      ),
    );
  }

  Widget _buildOpponentHandBand(BattleViewState view) {
    final count = view.opposingPlayer.hand.length;
    final shown = math.min(count, 8);
    return _BandFrame(
      title: 'Opponent Hand',
      child: Row(
        children: <Widget>[
          Text('Cards: $count'),
          const SizedBox(width: 12),
          Expanded(
            child: Align(
              alignment: Alignment.centerLeft,
              child: Wrap(
                spacing: 4,
                children: List<Widget>.generate(shown, (int index) {
                  return Container(
                    width: 22,
                    height: 30,
                    decoration: BoxDecoration(
                      color: Colors.white12,
                      borderRadius: BorderRadius.circular(4),
                      border: Border.all(color: Colors.white24),
                    ),
                  );
                }),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildShamanBand({
    required PlayerState player,
    required bool isActive,
    required String title,
    GlobalKey? bandKey,
    bool incomingPreview = false,
    bool incomingHover = false,
    ValueChanged<bool>? onDirectAttackHoverChanged,
    VoidCallback? onTapDirectAttack,
  }) {
    return Container(
      key: bandKey,
      child: _BandFrame(
        title: title,
        borderColor: incomingHover
            ? const Color(0xFFFFB74D)
            : (incomingPreview
                  ? Colors.redAccent.withValues(alpha: 0.55)
                  : null),
        child: Row(
          children: <Widget>[
            CircleAvatar(
              radius: 16,
              child: Text(player.id.substring(player.id.length - 1)),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Wrap(
                spacing: 8,
                runSpacing: 4,
                children: <Widget>[
                  Text(player.id),
                  Text('Totems ${player.units.length + player.totemsInHand}'),
                  Text('Field ${player.units.length}'),
                  Text('In Hand ${player.totemsInHand}'),
                  Text('Spirits ${player.hand.length}'),
                  if (isActive) const Chip(label: Text('Active')),
                ],
              ),
            ),
            if (onTapDirectAttack != null)
              MouseRegion(
                onEnter: (_) => onDirectAttackHoverChanged?.call(true),
                onExit: (_) => onDirectAttackHoverChanged?.call(false),
                child: FilledButton.tonal(
                  onPressed: onTapDirectAttack,
                  child: const Text('Direct Attack'),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildOpponentTableBand(BattleViewState view) {
    final selectedAttackerUnitId = view.selectedAttackerUnitId;
    return _BandFrame(
      title: 'Opponent Table',
      child: view.opposingPlayer.units.isEmpty
          ? const Text('No enemy units.')
          : ListView.separated(
              scrollDirection: Axis.horizontal,
              itemBuilder: (BuildContext context, int index) {
                final unit = view.opposingPlayer.units[index];
                final canTarget =
                    selectedAttackerUnitId != null &&
                    view.isAttackPhase &&
                    _controller
                        .canApply(
                          BattleIntents.attack(
                            selectedAttackerUnitId,
                            targetUnitId: unit.unitId,
                          ),
                        )
                        .allowed;
                final incomingHover = _hoverAttackTargetUnitId == unit.unitId;
                return Container(
                  key: _opponentUnitKey(unit.unitId),
                  child: MouseRegion(
                    onEnter: (_) {
                      if (!canTarget) {
                        return;
                      }
                      setState(() {
                        _hoverAttackTargetUnitId = unit.unitId;
                      });
                    },
                    onExit: (_) {
                      if (_hoverAttackTargetUnitId != unit.unitId) {
                        return;
                      }
                      setState(() {
                        _hoverAttackTargetUnitId = null;
                      });
                    },
                    child: _UnitCard(
                      unit: unit,
                      selectedUnitId: null,
                      onPieceTap: null,
                      incomingPreview: canTarget,
                      incomingHovered: incomingHover,
                      onUnitTap: canTarget
                          ? () => _queueAttack(
                              selectedAttackerUnitId,
                              targetUnitId: unit.unitId,
                            )
                          : null,
                    ),
                  ),
                );
              },
              separatorBuilder: (_, _) => const SizedBox(width: 8),
              itemCount: view.opposingPlayer.units.length,
            ),
    );
  }

  Widget _buildPlayerTableBand(BattleViewState view) {
    final active = view.activePlayer;
    return _BandFrame(
      title: view.isChooseDefendersPhase
          ? 'Player Table (Choose Defenders)'
          : 'Player Table',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          if (active.units.isEmpty)
            const Expanded(child: Center(child: Text('No units on field.')))
          else
            Expanded(
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemBuilder: (BuildContext context, int index) {
                  final unit = active.units[index];
                  final highlighted =
                      _hoverTarget?.kind == DropTargetKind.existingUnit &&
                      _hoverTarget?.unitId == unit.unitId;
                  return Container(
                    key: _unitDropKey(unit.unitId),
                    decoration: highlighted
                        ? BoxDecoration(
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                              color: Theme.of(context).colorScheme.secondary,
                              width: 2,
                            ),
                          )
                        : null,
                    child: _UnitCard(
                      unit: unit,
                      selectedUnitId: view.selectedAttackerUnitId,
                      outgoingReady:
                          view.isAttackPhase &&
                          _canUnitAttackThisTurn(unit),
                      onPieceTap: (int pieceIndex) {
                        if (view.isChooseDefendersPhase) {
                          _dispatch(
                            BattleIntents.chooseDefender(
                              unit.unitId,
                              pieceIndex,
                            ),
                          );
                          return;
                        }
                        if (!view.isAttackPhase) {
                          return;
                        }
                        final picked = _dispatch(
                          BattleIntents.chooseAttacker(unit.unitId, pieceIndex),
                        );
                        if (picked) {
                          setState(() {
                            _controller.selectAttackerUnit(unit.unitId);
                          });
                        }
                      },
                      onUnitTap: null,
                    ),
                  );
                },
                separatorBuilder: (_, _) => const SizedBox(width: 8),
                itemCount: active.units.length,
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildPlayerShamanBand(BattleViewState view) {
    final player = view.activePlayer;
    final actionWidgets = <Widget>[];
    if (view.isAttackPhase) {
      actionWidgets.add(
        FilledButton(
          onPressed: _controller.canApply(BattleIntents.endTurn()).allowed
              ? () => _dispatch(BattleIntents.endTurn())
              : null,
          child: const Text('Finish Attacks'),
        ),
      );
    }
    if (view.isMainPhase) {
      actionWidgets.addAll(<Widget>[
        Chip(
          label: Text(
            'Bind ${_bindsUsedThisTurn(view)}/${_bindCapForTurn(view.gameState)}',
          ),
        ),
        FilledButton.tonal(
          onPressed: _controller.canApply(BattleIntents.summonTotem()).allowed
              ? () => _dispatch(BattleIntents.summonTotem())
              : null,
          child: const Text('Summon Totem'),
        ),
        FilledButton(
          onPressed: () => _dispatch(BattleIntents.endTurn()),
          child: const Text('End Action Phase'),
        ),
      ]);
    }
    if (view.isChooseDefendersPhase) {
      actionWidgets.add(
        FilledButton(
          onPressed: _controller.canApply(BattleIntents.endTurn()).allowed
              ? () => _dispatch(BattleIntents.endTurn())
              : null,
          child: const Text('Validate Active Spirits'),
        ),
      );
    }
    actionWidgets.add(
      FilledButton.tonal(
        onPressed: _resetMatch,
        child: const Text('New Match'),
      ),
    );

    return Container(
      key: _playerShamanKey,
      child: _BandFrame(
        title: 'Player Shaman',
        child: Row(
          children: <Widget>[
            Expanded(
              child: Wrap(
                spacing: 8,
                runSpacing: 4,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: <Widget>[
                  CircleAvatar(
                    radius: 16,
                    child: Text(player.id.substring(player.id.length - 1)),
                  ),
                  Text(player.id),
                  Text('Totems ${player.units.length + player.totemsInHand}'),
                  Text('Field ${player.units.length}'),
                  Text('In Hand ${player.totemsInHand}'),
                  Text(
                    'Spirits ${player.units.fold<int>(0, (s, u) => s + u.pieces.length)}',
                  ),
                  if (view.gameState.activePlayerIndex == 0)
                    const Chip(label: Text('Active')),
                ],
              ),
            ),
            const SizedBox(width: 6),
            Flexible(
              child: Align(
                alignment: Alignment.centerRight,
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Wrap(
                    spacing: 8,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: actionWidgets,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPlayerHandBand(BattleViewState view) {
    final synthetic = view.activePlayer.copyWith(hand: view.gameState.pool);
    final remaining = _remainingPoolBinds(view);
    return Align(
      child: RepaintBoundary(
        key: _playerHandDropKey,
        child: _BandFrame(
          title:
              'Spirit Pool (${view.gameState.pool.length}) - Bind Remaining $remaining',
          borderColor: view.isMainPhase ? Colors.white24 : null,
          child: HandZone(
            activePlayer: synthetic,
            phase: view.gameState.phase,
            cardWidth: _handCardWidth,
            cardHeight: _handCardHeight,
            dragSession: _dragSession,
            onDragStart: _onHandDragStart,
            onDragUpdate: _onHandDragUpdate,
            onDragEnd: _onHandDragEnd,
            onDragCancel: _onHandDragCancel,
          ),
        ),
      ),
    );
  }

  Widget _buildEventLogOverlay(BattleViewState view) {
    final state = view.gameState;
    final telemetry = view.telemetry;
    final compact = !_logExpanded;
    return Positioned(
      right: 8,
      bottom: 8,
      child: RepaintBoundary(
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          width: compact ? 188 : 360,
          height: compact ? 40 : 250,
          curve: Curves.easeOutCubic,
          child: Card(
            child: compact
                ? InkWell(
                    onTap: () => setState(() => _logExpanded = true),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 10),
                      child: Row(
                        children: <Widget>[
                          const Icon(Icons.history, size: 18),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              'Log ${state.eventLog.length} | C ${telemetry.appliedCommands}/${telemetry.deniedCommands}',
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const Icon(Icons.expand_less),
                        ],
                      ),
                    ),
                  )
                : Column(
                    children: <Widget>[
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.04),
                          borderRadius: const BorderRadius.vertical(
                            top: Radius.circular(12),
                          ),
                        ),
                        child: Text(
                          'Cmd applied ${telemetry.appliedCommands}  denied ${telemetry.deniedCommands}  '
                          'attacks ${telemetry.attackDeclarations}  kills ${telemetry.destroyedEvents}  '
                          'direct ${telemetry.directHitEvents}',
                          style: Theme.of(context).textTheme.labelSmall,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      ListTile(
                        dense: true,
                        title: const Text('Event Log'),
                        subtitle: Text(
                          '${state.eventLog.length} entries | saved logs ${view.recentDiagnostics.length}/5',
                        ),
                        trailing: IconButton(
                          icon: const Icon(Icons.expand_more),
                          onPressed: () => setState(() => _logExpanded = false),
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 10),
                        child: Align(
                          alignment: Alignment.centerLeft,
                          child: Text(
                            'Diagnostics: ${view.diagnosticsPath}',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: Theme.of(context).textTheme.labelSmall,
                          ),
                        ),
                      ),
                      if (view.recentDiagnostics.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 4,
                          ),
                          child: Align(
                            alignment: Alignment.centerLeft,
                            child: Text(
                              'Latest: T${view.recentDiagnostics.first.turnNumber}  '
                              'Winner ${view.recentDiagnostics.first.winnerId}  '
                              'Events ${view.recentDiagnostics.first.eventLog.length}',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: Theme.of(context).textTheme.labelSmall,
                            ),
                          ),
                        ),
                      Expanded(
                        child: ListView.builder(
                          reverse: true,
                          padding: const EdgeInsets.symmetric(horizontal: 8),
                          itemCount: state.eventLog.length,
                          itemBuilder: (BuildContext context, int index) {
                            final reversedIndex =
                                state.eventLog.length - 1 - index;
                            return Text('• ${state.eventLog[reversedIndex]}');
                          },
                        ),
                      ),
                    ],
                  ),
          ),
        ),
      ),
    );
  }

  void _onHandDragStart(
    String pieceId,
    Offset grabOffsetInCard,
    Offset pointerGlobal,
  ) {
    if (_view.gameState.phase != TurnPhase.mainActions ||
        _dragSession != null) {
      return;
    }
    _snapController.stop();
    setState(() {
      _dragSession = HandDragSession(
        pieceId: pieceId,
        grabOffsetInCard: grabOffsetInCard,
        pointerGlobal: pointerGlobal,
        translation: Offset.zero,
        snapping: false,
      );
      _hoverTarget = null;
    });
    _updateHoverTarget(pointerGlobal);
  }

  void _onHandDragUpdate(String pieceId, Offset pointerGlobal, Offset delta) {
    final session = _dragSession;
    if (session == null || session.pieceId != pieceId || session.snapping) {
      return;
    }
    setState(() {
      _dragSession = session.copyWith(
        pointerGlobal: pointerGlobal,
        translation: session.translation + delta,
      );
    });
    _updateHoverTarget(pointerGlobal);
  }

  void _onHandDragEnd() {
    final session = _dragSession;
    if (session == null || session.snapping) {
      return;
    }

    final target = _hoverTarget;
    if (target == null || target.kind != DropTargetKind.existingUnit) {
      _startSnapBack();
      return;
    }

    final command = BattleIntents.bindFromPool(session.pieceId, target.unitId!);

    final applied = _dispatch(command);
    if (applied) {
      setState(_clearDragState);
      return;
    }
    _startSnapBack();
  }

  void _onHandDragCancel() {
    if (_dragSession == null) {
      return;
    }
    _startSnapBack();
  }

  void _startSnapBack() {
    final session = _dragSession;
    if (session == null) {
      return;
    }
    _snapFrom = session.translation;
    _snapController.stop();
    _snapController.value = 0;
    setState(() {
      _dragSession = session.copyWith(snapping: true);
      _hoverTarget = null;
    });
    _snapController.animateWith(SpringSimulation(_snapSpring, 0, 1, -0.2));
  }

  void _clearDragState() {
    _snapController.stop();
    _dragSession = null;
    _hoverTarget = null;
  }

  void _updateHoverTarget(Offset globalPointer) {
    final session = _dragSession;
    final state = _view.gameState;
    if (session == null || session.snapping) {
      return;
    }

    final next = _targetResolver.resolve(
      globalPointer: globalPointer,
      newUnitKey: _newUnitDropKey,
      unitKeys: state.activePlayer.units.map(
        (unit) =>
            MapEntry<String, GlobalKey>(unit.unitId, _unitDropKey(unit.unitId)),
      ),
      canDropToNewUnit: false,
      canDropToUnit: (String unitId) => _controller
          .canApply(BattleIntents.bindFromPool(session.pieceId, unitId))
          .allowed,
    );

    if (next != _hoverTarget) {
      setState(() {
        _hoverTarget = next;
      });
    }
  }

  GlobalKey _unitDropKey(String unitId) {
    return _unitDropKeys.putIfAbsent(
      unitId,
      () => GlobalKey(debugLabel: 'drop_$unitId'),
    );
  }

  GlobalKey _opponentUnitKey(String unitId) {
    return _opponentUnitKeys.putIfAbsent(
      unitId,
      () => GlobalKey(debugLabel: 'opponent_$unitId'),
    );
  }

  void _queueAttack(String attackerUnitId, {String? targetUnitId}) {
    _hoverAttackTargetUnitId = null;
    final command = BattleIntents.attack(
      attackerUnitId,
      targetUnitId: targetUnitId,
    );
    _performResolvedAttack(command, animate: true);
  }

  bool _performResolvedAttack(
    AttackUnitMove command, {
    required bool animate,
    bool scheduleAi = true,
  }) {
    final visual = animate ? _buildAttackVisualSnapshot(command) : null;
    final applied = _dispatch(command, scheduleAi: scheduleAi);
    if (applied && visual != null) {
      _startAttackVisual(visual);
    }
    return applied;
  }

  _AttackVisual? _buildAttackVisualSnapshot(AttackUnitMove command) {
    final state = _view.gameState;
    final attackerIsPlayer = state.activePlayerIndex == 0;
    final fromRect = _targetResolver.rectForKey(
      attackerIsPlayer
          ? _unitDropKey(command.attackerUnitId)
          : _opponentUnitKey(command.attackerUnitId),
    );
    final toRect = command.targetUnitId == null
        ? _targetResolver.rectForKey(
            attackerIsPlayer ? _opponentShamanKey : _playerShamanKey,
          )
        : _targetResolver.rectForKey(
            attackerIsPlayer
                ? _opponentUnitKey(command.targetUnitId!)
                : _unitDropKey(command.targetUnitId!),
          );
    final layerContext = _interactionLayerKey.currentContext;
    if (fromRect == null || toRect == null || layerContext == null) {
      return null;
    }
    final render = layerContext.findRenderObject();
    if (render is! RenderBox || !render.hasSize) {
      return null;
    }
    final activeUnits = state.activePlayer.units;
    if (activeUnits.isEmpty) {
      return null;
    }
    final attackerUnit = activeUnits.firstWhere(
      (unit) => unit.unitId == command.attackerUnitId,
      orElse: () => activeUnits.first,
    );
    if (attackerUnit.pieces.isEmpty) {
      return null;
    }
    final attackerPiece =
        attackerUnit.pieces[attackerUnit.attackingPieceIndex ?? 0].definition;
    return _AttackVisual(
      from: render.globalToLocal(fromRect.center),
      to: render.globalToLocal(toRect.center),
      color: _elementColor(attackerPiece.element),
      piece: attackerPiece,
    );
  }

  void _startAttackVisual(_AttackVisual visual) {
    setState(() {
      _attackVisual = visual;
    });
    _attackController
      ..stop()
      ..value = 0
      ..forward();
  }

  Future<void> _waitForAttackAnimationComplete() async {
    final deadline = DateTime.now().add(const Duration(seconds: 2));
    while (mounted &&
        _attackVisual != null &&
        DateTime.now().isBefore(deadline)) {
      await Future<void>.delayed(const Duration(milliseconds: 16));
    }
  }

  Color _elementColor(SpiritElement element) {
    return switch (element) {
      SpiritElement.red => const Color(0xFFEF5350),
      SpiritElement.green => const Color(0xFF66BB6A),
      SpiritElement.blue => const Color(0xFF42A5F5),
    };
  }

  bool _canUnitAttackThisTurn(UnitState unit) {
    return unit.pieces.isNotEmpty && !unit.attackedThisTurn;
  }

  int _bindCapForTurn(GameState state) {
    return state.turnNumber == 1 && state.activePlayerIndex == 0 ? 1 : 2;
  }

  int _bindsUsedThisTurn(BattleViewState view) {
    return view.activePlayer.poolPicksThisTurn;
  }

  int _remainingPoolBinds(BattleViewState view) {
    final cap = _bindCapForTurn(view.gameState);
    final used = _bindsUsedThisTurn(view);
    final remaining = cap - used;
    return remaining < 0 ? 0 : remaining;
  }

  Widget _buildTargetingLineOverlay() {
    final session = _dragSession;
    final target = _hoverTarget;
    if (session == null || target == null) {
      return const SizedBox.shrink();
    }

    final targetRect = switch (target.kind) {
      DropTargetKind.newUnit => _targetResolver.rectForKey(_newUnitDropKey),
      DropTargetKind.existingUnit => _targetResolver.rectForKey(
        _unitDropKey(target.unitId!),
      ),
    };
    if (targetRect == null) {
      return const SizedBox.shrink();
    }

    final layerContext = _interactionLayerKey.currentContext;
    if (layerContext == null) {
      return const SizedBox.shrink();
    }
    final render = layerContext.findRenderObject();
    if (render is! RenderBox || !render.hasSize) {
      return const SizedBox.shrink();
    }

    final draggedCardTopLeftGlobal =
        session.pointerGlobal - session.grabOffsetInCard;
    final from = render.globalToLocal(
      draggedCardTopLeftGlobal +
          const Offset(_handCardWidth / 2, _handCardHeight / 2),
    );
    final to = render.globalToLocal(targetRect.center);
    return Positioned.fill(
      child: IgnorePointer(
        child: RepaintBoundary(
          child: CustomPaint(
            painter: TargetingLinePainter(from: from, to: to),
          ),
        ),
      ),
    );
  }

  Widget _buildAttackAnimationOverlay() {
    final visual = _attackVisual;
    if (visual == null) {
      return const SizedBox.shrink();
    }
    final t = _attackController.value;
    final outgoing = t <= 0.58;
    final segmentT = outgoing ? (t / 0.58) : ((t - 0.58) / 0.42);
    final curved = outgoing
        ? Curves.easeOutCubic.transform(segmentT.clamp(0.0, 1.0))
        : Curves.easeInCubic.transform(segmentT.clamp(0.0, 1.0));
    final position = outgoing
        ? Offset.lerp(visual.from, visual.to, curved)!
        : Offset.lerp(visual.to, visual.from, curved)!;
    final collisionStrength = (1 - ((t - 0.58).abs() / 0.12))
        .clamp(0.0, 1.0)
        .toDouble();

    return Positioned.fill(
      child: IgnorePointer(
        child: Stack(
          children: <Widget>[
            if (collisionStrength > 0)
              Positioned(
                left: visual.to.dx - 26,
                top: visual.to.dy - 26,
                child: Opacity(
                  opacity: collisionStrength * 0.65,
                  child: Container(
                    width: 52,
                    height: 52,
                    decoration: BoxDecoration(
                      color: visual.color,
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
              ),
            Positioned(
              left: position.dx - 30,
              top: position.dy - 40,
              child: Transform.scale(
                scale: 1 + (collisionStrength * 0.25),
                child: Transform.rotate(
                  angle: outgoing ? 0 : 0.05,
                  child: SizedBox(
                    width: 60,
                    height: 80,
                    child: SpiritCardView(
                      piece: visual.piece,
                      width: 60,
                      height: 80,
                      elevated: true,
                      highlighted: false,
                      angle: 0,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AttackVisual {
  const _AttackVisual({
    required this.from,
    required this.to,
    required this.color,
    required this.piece,
  });

  final Offset from;
  final Offset to;
  final Color color;
  final PieceDefinition piece;
}

class _BandFrame extends StatelessWidget {
  const _BandFrame({
    required this.title,
    required this.child,
    this.borderColor,
  });

  final String title;
  final Widget child;
  final Color? borderColor;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        final compact = constraints.maxHeight < 56;
        return Card(
          margin: const EdgeInsets.symmetric(vertical: 2),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: BorderSide(color: borderColor ?? Colors.white12),
          ),
          child: Padding(
            padding: EdgeInsets.symmetric(
              horizontal: compact ? 6 : 8,
              vertical: compact ? 4 : 6,
            ),
            child: compact
                ? ClipRect(child: child)
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        title,
                        style: Theme.of(context).textTheme.labelLarge,
                      ),
                      const SizedBox(height: 4),
                      Expanded(child: child),
                    ],
                  ),
          ),
        );
      },
    );
  }
}

class _UnitCard extends StatefulWidget {
  const _UnitCard({
    required this.unit,
    required this.selectedUnitId,
    required this.onPieceTap,
    required this.onUnitTap,
    this.outgoingReady = false,
    this.incomingPreview = false,
    this.incomingHovered = false,
  });

  final UnitState unit;
  final String? selectedUnitId;
  final void Function(int pieceIndex)? onPieceTap;
  final VoidCallback? onUnitTap;
  final bool outgoingReady;
  final bool incomingPreview;
  final bool incomingHovered;

  @override
  State<_UnitCard> createState() => _UnitCardState();
}

class _UnitCardState extends State<_UnitCard> {
  int? _hoveredPieceIndex;
  bool _hoveredUnit = false;

  @override
  Widget build(BuildContext context) {
    final unit = widget.unit;
    final selectedUnitId = widget.selectedUnitId;
    final borderColor = widget.incomingHovered
        ? const Color(0xFFFFB74D)
        : (widget.incomingPreview
              ? Colors.redAccent.withValues(alpha: 0.55)
              : (widget.outgoingReady
                    ? Colors.lightGreenAccent.withValues(alpha: 0.5)
                    : (_hoveredUnit && widget.onUnitTap != null
                          ? Colors.white38
                          : Colors.white10)));
    return MouseRegion(
      onEnter: (_) => setState(() => _hoveredUnit = true),
      onExit: (_) => setState(() => _hoveredUnit = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 110),
        width: 280,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: borderColor),
        ),
        child: Card(
          margin: EdgeInsets.zero,
          child: Padding(
            padding: const EdgeInsets.all(8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Wrap(
                  spacing: 8,
                  children: <Widget>[
                    Text(unit.unitId),
                    if (unit.attackedThisTurn)
                      const Chip(label: Text('Attacked')),
                    if (selectedUnitId == unit.unitId)
                      const Chip(label: Text('Selected')),
                    if (widget.outgoingReady)
                      const _StatusChip(label: 'OUT', color: Color(0xFF66BB6A)),
                    if (widget.incomingPreview)
                      _StatusChip(
                        label: widget.incomingHovered ? 'TARGET' : 'IN',
                        color: widget.incomingHovered
                            ? const Color(0xFFFFB74D)
                            : const Color(0xFFEF5350),
                      ),
                  ],
                ),
                const SizedBox(height: 8),
                Expanded(
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: List<Widget>.generate(unit.pieces.length, (
                        int i,
                      ) {
                        final piece = unit.pieces[i];
                        final isAttacking = i == unit.attackingPieceIndex;
                        final isDefending = i == unit.defendingPieceIndex;
                        final highlighted =
                            _hoveredPieceIndex == i ||
                            isAttacking ||
                            isDefending;
                        return Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: MouseRegion(
                            onEnter: (_) =>
                                setState(() => _hoveredPieceIndex = i),
                            onExit: (_) {
                              if (_hoveredPieceIndex != i) {
                                return;
                              }
                              setState(() => _hoveredPieceIndex = null);
                            },
                            child: GestureDetector(
                              onTap: () {
                                if (widget.onPieceTap != null) {
                                  widget.onPieceTap!(i);
                                  return;
                                }
                                widget.onUnitTap?.call();
                              },
                              child: SizedBox(
                                width: 96,
                                height: 130,
                                child: Stack(
                                  children: <Widget>[
                                    SpiritCardView(
                                      piece: piece.definition,
                                      width: 96,
                                      height: 130,
                                      elevated: false,
                                      highlighted: highlighted,
                                      angle: 0,
                                    ),
                                    if (isAttacking)
                                      const Positioned(
                                        left: 6,
                                        bottom: 6,
                                        child: _StatusChip(
                                          label: 'ATK',
                                          color: Color(0xFFEF5350),
                                        ),
                                      ),
                                    if (isDefending)
                                      const Positioned(
                                        right: 6,
                                        bottom: 6,
                                        child: _StatusChip(
                                          label: 'DEF',
                                          color: Color(0xFF42A5F5),
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        );
                      }),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.9),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
          color: Colors.white,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _BandFlex {
  const _BandFlex({
    required this.opponentHand,
    required this.opponentShaman,
    required this.opponentTable,
    required this.playerTable,
    required this.playerShaman,
    required this.playerHand,
  });

  final int opponentHand;
  final int opponentShaman;
  final int opponentTable;
  final int playerTable;
  final int playerShaman;
  final int playerHand;

  factory _BandFlex.forHeight(double height) {
    if (height < 760) {
      return const _BandFlex(
        opponentHand: 8,
        opponentShaman: 10,
        opponentTable: 19,
        playerTable: 19,
        playerShaman: 11,
        playerHand: 25,
      );
    }
    return const _BandFlex(
      opponentHand: 9,
      opponentShaman: 11,
      opponentTable: 19,
      playerTable: 19,
      playerShaman: 11,
      playerHand: 24,
    );
  }
}
