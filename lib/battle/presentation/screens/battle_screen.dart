import 'dart:math' as math;

import 'package:bullethole_shared/bullethole_shared.dart';
import 'package:flutter/material.dart';
import 'package:flutter/physics.dart';
import 'package:puredots_turn_engine/puredots_turn_engine.dart';

import '../../application/battle_controller.dart';
import '../../application/battle_intents.dart';
import '../../application/battle_view_state.dart';
import '../../application/drag_session.dart';
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
    with SingleTickerProviderStateMixin {
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
  final Map<String, GlobalKey> _unitDropKeys = <String, GlobalKey>{};
  final BattleController _controller = BattleController();
  final DropTargetResolver _targetResolver = const DropTargetResolver();

  late final AnimationController _snapController;
  HandDragSession? _dragSession;
  DropTargetPreview? _hoverTarget;
  Offset _snapFrom = Offset.zero;
  bool _logExpanded = false;

  BattleViewState get _view => _controller.viewState;

  @override
  void initState() {
    super.initState();
    _snapController =
        AnimationController(vsync: this, lowerBound: 0, upperBound: 1)
          ..addListener(_onSnapTick)
          ..addStatusListener(_onSnapStatusChange);
  }

  @override
  void dispose() {
    _snapController.dispose();
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

  void _resetMatch() {
    setState(() {
      _controller.resetMatch();
      _clearDragState();
      _logExpanded = false;
    });
  }

  bool _dispatch(GameCommand command) {
    final applied = _controller.dispatch(command);
    setState(() {});
    return applied;
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
                            onTapDirectAttack:
                                view.selectedAttackerUnitId != null &&
                                    view.isMainPhase &&
                                    view.opposingPlayer.units.isEmpty
                                ? () => _dispatch(
                                    BattleIntents.attack(
                                      view.selectedAttackerUnitId!,
                                    ),
                                  )
                                : null,
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
                    if (view.isDraftPhase) _buildDraftTrayOverlay(view),
                    _buildEventLogOverlay(state),
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
    VoidCallback? onTapDirectAttack,
  }) {
    return _BandFrame(
      title: title,
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
                Text('HP ${player.health}'),
                Text('Hand ${player.hand.length}'),
                Text('Units ${player.units.length}'),
                if (isActive) const Chip(label: Text('Active')),
              ],
            ),
          ),
          if (onTapDirectAttack != null)
            FilledButton.tonal(
              onPressed: onTapDirectAttack,
              child: const Text('Direct Attack'),
            ),
        ],
      ),
    );
  }

  Widget _buildOpponentTableBand(BattleViewState view) {
    return _BandFrame(
      title: 'Opponent Table',
      child: view.opposingPlayer.units.isEmpty
          ? const Text('No enemy units.')
          : ListView.separated(
              scrollDirection: Axis.horizontal,
              itemBuilder: (BuildContext context, int index) {
                final unit = view.opposingPlayer.units[index];
                final canTarget =
                    view.selectedAttackerUnitId != null && view.isMainPhase;
                return _UnitCard(
                  unit: unit,
                  selectedUnitId: null,
                  onPieceTap: null,
                  onUnitTap: canTarget
                      ? () => _dispatch(
                          BattleIntents.attack(
                            view.selectedAttackerUnitId!,
                            targetUnitId: unit.unitId,
                          ),
                        )
                      : null,
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
          if (view.isMainPhase)
            Card(
              key: _newUnitDropKey,
              color: _hoverTarget?.kind == DropTargetKind.newUnit
                  ? Theme.of(
                      context,
                    ).colorScheme.primary.withValues(alpha: 0.28)
                  : null,
              child: const ListTile(
                dense: true,
                title: Text('Drop Here For New Unit'),
              ),
            ),
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
    return _BandFrame(
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
                Text('HP ${player.health}'),
                Text('Hand ${player.hand.length}'),
                Text('Units ${player.units.length}'),
                if (view.gameState.activePlayerIndex == 0)
                  const Chip(label: Text('Active')),
              ],
            ),
          ),
          const SizedBox(width: 8),
          if (view.isMainPhase)
            FilledButton(
              onPressed: () => _dispatch(BattleIntents.endTurn()),
              child: const Text('End Turn'),
            ),
          if (view.isDraftPhase || view.isChooseDefendersPhase)
            FilledButton.tonal(
              onPressed: null,
              child: Text(view.isDraftPhase ? 'Drafting...' : 'Set Defenders'),
            ),
          const SizedBox(width: 8),
          FilledButton.tonal(
            onPressed: _resetMatch,
            child: const Text('New Match'),
          ),
        ],
      ),
    );
  }

  Widget _buildPlayerHandBand(BattleViewState view) {
    return RepaintBoundary(
      key: _playerHandDropKey,
      child: DragTarget<PieceInstance>(
        onWillAcceptWithDetails: (details) {
          if (!view.isDraftPhase) {
            return false;
          }
          return _controller
              .canApply(BattleIntents.draftFromPool(details.data.instanceId))
              .allowed;
        },
        onAcceptWithDetails: (details) {
          _dispatch(BattleIntents.draftFromPool(details.data.instanceId));
        },
        builder: (context, candidateData, rejectedData) {
          final draftHover = candidateData.isNotEmpty && view.isDraftPhase;
          return _BandFrame(
            title: 'Player Hand',
            borderColor: draftHover
                ? Theme.of(context).colorScheme.primary
                : (view.isDraftPhase ? Colors.white24 : null),
            child: HandZone(
              activePlayer: view.activePlayer,
              phase: view.gameState.phase,
              cardWidth: _handCardWidth,
              cardHeight: _handCardHeight,
              dragSession: _dragSession,
              onDragStart: _onHandDragStart,
              onDragUpdate: _onHandDragUpdate,
              onDragEnd: _onHandDragEnd,
              onDragCancel: _onHandDragCancel,
            ),
          );
        },
      ),
    );
  }

  Widget _buildDraftTrayOverlay(BattleViewState view) {
    final pool = view.gameState.pool;
    return Align(
      alignment: const Alignment(0, -0.1),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 840),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: RepaintBoundary(
            child: Card(
              color: Theme.of(
                context,
              ).colorScheme.surface.withValues(alpha: 0.96),
              child: Padding(
                padding: const EdgeInsets.all(10),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      'Draft Tray: drag to your hand',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 8),
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: pool
                            .map((piece) {
                              return Padding(
                                padding: const EdgeInsets.only(right: 8),
                                child: LongPressDraggable<PieceInstance>(
                                  data: piece,
                                  delay: const Duration(milliseconds: 90),
                                  feedback: Material(
                                    color: Colors.transparent,
                                    child: SizedBox(
                                      width: 92,
                                      height: 126,
                                      child: SpiritCardView(
                                        piece: piece.definition,
                                        width: 92,
                                        height: 126,
                                        elevated: true,
                                        angle: 0,
                                      ),
                                    ),
                                  ),
                                  childWhenDragging: Opacity(
                                    opacity: 0.22,
                                    child: SizedBox(
                                      width: 92,
                                      height: 126,
                                      child: SpiritCardView(
                                        piece: piece.definition,
                                        width: 92,
                                        height: 126,
                                        elevated: false,
                                        angle: 0,
                                      ),
                                    ),
                                  ),
                                  child: GestureDetector(
                                    onTap: () => _dispatch(
                                      BattleIntents.draftFromPool(
                                        piece.instanceId,
                                      ),
                                    ),
                                    child: SizedBox(
                                      width: 92,
                                      height: 126,
                                      child: SpiritCardView(
                                        piece: piece.definition,
                                        width: 92,
                                        height: 126,
                                        elevated: false,
                                        angle: 0,
                                      ),
                                    ),
                                  ),
                                ),
                              );
                            })
                            .toList(growable: false),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildEventLogOverlay(GameState state) {
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
                              'Event Log ${state.eventLog.length}',
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
                      ListTile(
                        dense: true,
                        title: const Text('Event Log'),
                        subtitle: Text('${state.eventLog.length} entries'),
                        trailing: IconButton(
                          icon: const Icon(Icons.expand_more),
                          onPressed: () => setState(() => _logExpanded = false),
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
    if (target == null) {
      _startSnapBack();
      return;
    }

    final command = switch (target.kind) {
      DropTargetKind.newUnit => BattleIntents.playToNewUnit(session.pieceId),
      DropTargetKind.existingUnit => BattleIntents.addToUnit(
        session.pieceId,
        target.unitId!,
      ),
    };

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
      canDropToNewUnit: _controller
          .canApply(BattleIntents.playToNewUnit(session.pieceId))
          .allowed,
      canDropToUnit: (String unitId) => _controller
          .canApply(BattleIntents.addToUnit(session.pieceId, unitId))
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

class _UnitCard extends StatelessWidget {
  const _UnitCard({
    required this.unit,
    required this.selectedUnitId,
    required this.onPieceTap,
    required this.onUnitTap,
  });

  final UnitState unit;
  final String? selectedUnitId;
  final void Function(int pieceIndex)? onPieceTap;
  final VoidCallback? onUnitTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onUnitTap,
      child: Card(
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
                ],
              ),
              const SizedBox(height: 6),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: List<Widget>.generate(unit.pieces.length, (int i) {
                  return OutlinedButton(
                    onPressed: onPieceTap == null ? null : () => onPieceTap!(i),
                    child: Text(
                      '${i == unit.attackingPieceIndex ? 'ATK>' : ''} '
                      '${i == unit.defendingPieceIndex ? 'DEF>' : ''}'
                      '${pieceLabel(unit.pieces[i].definition)}',
                    ),
                  );
                }),
              ),
            ],
          ),
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
