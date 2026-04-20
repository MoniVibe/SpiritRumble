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
import '../widgets/board_zone.dart';
import '../widgets/hand_zone.dart';

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
  final Map<String, GlobalKey> _unitDropKeys = <String, GlobalKey>{};
  final BattleController _controller = BattleController();
  final DropTargetResolver _targetResolver = const DropTargetResolver();

  late final AnimationController _snapController;
  HandDragSession? _dragSession;
  DropTargetPreview? _hoverTarget;
  Offset _snapFrom = Offset.zero;

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
    final active = view.activePlayer;
    final opponent = view.opposingPlayer;
    final winner = view.winnerIndex;

    return Scaffold(
      body: GameBackdrop(
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Row(
                  children: <Widget>[
                    Text(
                      'Sprit Rumble',
                      style: Theme.of(context).textTheme.headlineSmall,
                    ),
                    const Spacer(),
                    FilledButton.tonal(
                      onPressed: _resetMatch,
                      child: const Text('New Match'),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: <Widget>[
                    Chip(label: Text('Turn ${state.turnNumber}')),
                    Chip(label: Text('Active: ${active.id}')),
                    Chip(label: Text('Phase: ${phaseLabel(state.phase)}')),
                    Chip(label: Text('Pool ${state.pool.length}/5')),
                    if (winner != null)
                      Chip(label: Text('Winner: ${state.players[winner].id}')),
                  ],
                ),
                if (view.lastError != null) ...<Widget>[
                  const SizedBox(height: 8),
                  Text('Last rule denial: ${view.lastError}'),
                ],
                const SizedBox(height: 10),
                _ShamanSummary(player: active, caption: 'Current'),
                const SizedBox(height: 8),
                _ShamanSummary(player: opponent, caption: 'Opponent'),
                const SizedBox(height: 10),
                if (view.isDraftPhase) _buildDraftPanel(state),
                if (view.isMainPhase) _buildMainPanel(state, view),
                if (view.isChooseDefendersPhase) _buildDefenderPanel(state),
                const SizedBox(height: 10),
                Text(
                  'Event Log',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 8),
                Expanded(
                  child: Card(
                    child: ListView.builder(
                      reverse: true,
                      padding: const EdgeInsets.all(12),
                      itemCount: state.eventLog.length,
                      itemBuilder: (BuildContext context, int index) {
                        final reversedIndex = state.eventLog.length - 1 - index;
                        return Text('• ${state.eventLog[reversedIndex]}');
                      },
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

  Widget _buildDraftPanel(GameState state) {
    return Expanded(
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              'Draft From Shared Pool',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: state.pool
                  .map(
                    (piece) => FilledButton.tonal(
                      onPressed: () => _dispatch(
                        BattleIntents.draftFromPool(piece.instanceId),
                      ),
                      child: Text(pieceLabel(piece.definition)),
                    ),
                  )
                  .toList(growable: false),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMainPanel(GameState state, BattleViewState view) {
    return Expanded(
      child: Stack(
        key: _interactionLayerKey,
        children: <Widget>[
          SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  'Hand (Drag To Play)',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 8),
                SizedBox(
                  height: _handCardHeight + 38,
                  child: HandZone(
                    activePlayer: view.activePlayer,
                    phase: state.phase,
                    cardWidth: _handCardWidth,
                    cardHeight: _handCardHeight,
                    dragSession: _dragSession,
                    onDragStart: _onHandDragStart,
                    onDragUpdate: _onHandDragUpdate,
                    onDragEnd: _onHandDragEnd,
                    onDragCancel: _onHandDragCancel,
                  ),
                ),
                const SizedBox(height: 12),
                BoardZone(
                  activePlayer: view.activePlayer,
                  opponentPlayer: view.opposingPlayer,
                  selectedAttackerUnitId: view.selectedAttackerUnitId,
                  hoverTarget: _hoverTarget,
                  newUnitDropKey: _newUnitDropKey,
                  unitDropKeyFor: _unitDropKey,
                  onChooseAttacker: (String unitId, int pieceIndex) {
                    final picked = _dispatch(
                      BattleIntents.chooseAttacker(unitId, pieceIndex),
                    );
                    if (picked) {
                      setState(() {
                        _controller.selectAttackerUnit(unitId);
                      });
                    }
                  },
                  onAttack: (String attackerUnitId, String? targetUnitId) {
                    _dispatch(
                      BattleIntents.attack(
                        attackerUnitId,
                        targetUnitId: targetUnitId,
                      ),
                    );
                  },
                  onEndTurn: () => _dispatch(BattleIntents.endTurn()),
                ),
              ],
            ),
          ),
          _buildTargetingLineOverlay(),
        ],
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
        child: CustomPaint(
          painter: TargetingLinePainter(from: from, to: to),
        ),
      ),
    );
  }

  Widget _buildDefenderPanel(GameState state) {
    final active = state.activePlayer;
    return Expanded(
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              'Choose Defenders For Your Units',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 8),
            if (active.units.isEmpty)
              const Text('No units: turn will auto-advance.')
            else
              Column(
                children: active.units
                    .map(
                      (unit) => Card(
                        child: Padding(
                          padding: const EdgeInsets.all(8),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: <Widget>[
                              Text(
                                '${unit.unitId} (${unit.defendingPieceIndex == null ? 'unset' : 'defender ${unit.defendingPieceIndex}'})',
                              ),
                              const SizedBox(height: 6),
                              Wrap(
                                spacing: 8,
                                runSpacing: 8,
                                children: List<Widget>.generate(
                                  unit.pieces.length,
                                  (int i) {
                                    return FilledButton.tonal(
                                      onPressed: () => _dispatch(
                                        BattleIntents.chooseDefender(
                                          unit.unitId,
                                          i,
                                        ),
                                      ),
                                      child: Text('Defend With #$i'),
                                    );
                                  },
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    )
                    .toList(growable: false),
              ),
          ],
        ),
      ),
    );
  }
}

class _ShamanSummary extends StatelessWidget {
  const _ShamanSummary({required this.player, required this.caption});

  final PlayerState player;
  final String caption;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(10),
        child: Wrap(
          spacing: 10,
          runSpacing: 6,
          children: <Widget>[
            Text('$caption: ${player.id}'),
            Text('HP ${player.health}'),
            Text('Hand ${player.hand.length}'),
            Text('Units ${player.units.length}'),
          ],
        ),
      ),
    );
  }
}
