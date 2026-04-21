import 'package:flutter/material.dart';
import 'package:puredots_turn_engine/puredots_turn_engine.dart';

import '../../application/drag_session.dart';
import 'spirit_card_view.dart';

class HandZone extends StatefulWidget {
  const HandZone({
    required this.activePlayer,
    required this.phase,
    required this.cardWidth,
    required this.cardHeight,
    required this.dragSession,
    required this.onDragStart,
    required this.onDragUpdate,
    required this.onDragEnd,
    required this.onDragCancel,
    super.key,
  });

  final PlayerState activePlayer;
  final TurnPhase phase;
  final double cardWidth;
  final double cardHeight;
  final HandDragSession? dragSession;
  final void Function(
    String pieceId,
    Offset grabOffsetInCard,
    Offset pointerGlobal,
  )
  onDragStart;
  final void Function(String pieceId, Offset pointerGlobal, Offset delta)
  onDragUpdate;
  final VoidCallback onDragEnd;
  final VoidCallback onDragCancel;

  @override
  State<HandZone> createState() => _HandZoneState();
}

class _HandZoneState extends State<HandZone> {
  String? _hoveredPieceId;

  @override
  Widget build(BuildContext context) {
    final hand = widget.activePlayer.hand;
    if (hand.isEmpty) {
      return const Center(child: Text('No pieces in hand.'));
    }

    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        final draggedIndex = widget.dragSession == null
            ? null
            : hand.indexWhere(
                (piece) => piece.instanceId == widget.dragSession!.pieceId,
              );
        final emphasized = (draggedIndex != null && draggedIndex >= 0)
            ? draggedIndex
            : null;
        final slots = computeFanLayout(
          FanLayoutInput(
            itemCount: hand.length,
            availableWidth: constraints.maxWidth,
            cardWidth: widget.cardWidth,
            emphasizedIndex: emphasized,
          ),
        );

        final staticChildren = <Widget>[];
        Widget? draggedChild;
        for (var i = 0; i < hand.length; i++) {
          final piece = hand[i];
          final slot = slots[i];
          final isDragged = widget.dragSession?.pieceId == piece.instanceId;
          final child = _buildHandPieceCard(
            piece: piece,
            rotationRadians: slot.rotationRadians,
            isDragged: isDragged,
            highlighted: _hoveredPieceId == piece.instanceId,
          );

          if (isDragged) {
            final translation = widget.dragSession!.translation;
            draggedChild = Positioned(
              left: slot.x + translation.dx,
              top: slot.y + translation.dy,
              child: Transform.rotate(
                angle:
                    slot.rotationRadians +
                    (translation.dx / 420).clamp(-0.12, 0.12) +
                    (translation.dy / 900).clamp(-0.05, 0.05),
                child: child,
              ),
            );
          } else {
            staticChildren.add(
              AnimatedPositioned(
                duration: const Duration(milliseconds: 120),
                curve: Curves.easeOutCubic,
                left: slot.x,
                top: slot.y,
                child: Transform.rotate(
                  angle: slot.rotationRadians,
                  child: child,
                ),
              ),
            );
          }
        }

        return Stack(
          clipBehavior: Clip.none,
          children: <Widget>[
            ...staticChildren,
            ...[draggedChild].whereType<Widget>(),
          ],
        );
      },
    );
  }

  Widget _buildHandPieceCard({
    required PieceInstance piece,
    required double rotationRadians,
    required bool isDragged,
    required bool highlighted,
  }) {
    final canStartDrag =
        widget.phase == TurnPhase.mainActions &&
        (widget.dragSession == null ||
            widget.dragSession?.pieceId == piece.instanceId);
    return Opacity(
      opacity: isDragged ? 1 : 0.97,
      child: MouseRegion(
        cursor: canStartDrag ? SystemMouseCursors.grab : MouseCursor.defer,
        onEnter: (_) {
          setState(() {
            _hoveredPieceId = piece.instanceId;
          });
        },
        onExit: (_) {
          if (_hoveredPieceId != piece.instanceId) {
            return;
          }
          setState(() {
            _hoveredPieceId = null;
          });
        },
        child: GestureDetector(
          onPanStart: canStartDrag
              ? (details) => widget.onDragStart(
                  piece.instanceId,
                  details.localPosition,
                  details.globalPosition,
                )
              : null,
          onPanUpdate: canStartDrag
              ? (details) => widget.onDragUpdate(
                  piece.instanceId,
                  details.globalPosition,
                  details.delta,
                )
              : null,
          onPanEnd: canStartDrag ? (_) => widget.onDragEnd() : null,
          onPanCancel: canStartDrag ? widget.onDragCancel : null,
          child: SpiritCardView(
            piece: piece.definition,
            width: widget.cardWidth,
            height: widget.cardHeight,
            elevated: isDragged,
            highlighted: highlighted && canStartDrag && !isDragged,
            angle: rotationRadians,
          ),
        ),
      ),
    );
  }
}
