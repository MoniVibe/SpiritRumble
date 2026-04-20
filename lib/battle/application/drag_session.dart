import 'dart:ui';

class HandDragSession {
  const HandDragSession({
    required this.pieceId,
    required this.grabOffsetInCard,
    required this.pointerGlobal,
    required this.translation,
    required this.snapping,
  });

  final String pieceId;
  final Offset grabOffsetInCard;
  final Offset pointerGlobal;
  final Offset translation;
  final bool snapping;

  HandDragSession copyWith({
    String? pieceId,
    Offset? grabOffsetInCard,
    Offset? pointerGlobal,
    Offset? translation,
    bool? snapping,
  }) {
    return HandDragSession(
      pieceId: pieceId ?? this.pieceId,
      grabOffsetInCard: grabOffsetInCard ?? this.grabOffsetInCard,
      pointerGlobal: pointerGlobal ?? this.pointerGlobal,
      translation: translation ?? this.translation,
      snapping: snapping ?? this.snapping,
    );
  }
}
