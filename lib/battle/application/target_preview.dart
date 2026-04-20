enum DropTargetKind { newUnit, existingUnit }

class DropTargetPreview {
  const DropTargetPreview.newUnit()
    : kind = DropTargetKind.newUnit,
      unitId = null;

  const DropTargetPreview.existingUnit(this.unitId)
    : kind = DropTargetKind.existingUnit;

  final DropTargetKind kind;
  final String? unitId;

  @override
  bool operator ==(Object other) {
    return other is DropTargetPreview &&
        other.kind == kind &&
        other.unitId == unitId;
  }

  @override
  int get hashCode => Object.hash(kind, unitId);
}
