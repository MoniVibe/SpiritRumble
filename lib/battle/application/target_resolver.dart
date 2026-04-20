import 'package:flutter/widgets.dart';

import 'target_preview.dart';

class DropTargetResolver {
  const DropTargetResolver();

  DropTargetPreview? resolve({
    required Offset globalPointer,
    required GlobalKey newUnitKey,
    required Iterable<MapEntry<String, GlobalKey>> unitKeys,
    required bool canDropToNewUnit,
    required bool Function(String unitId) canDropToUnit,
  }) {
    if (canDropToNewUnit &&
        (rectForKey(newUnitKey)?.contains(globalPointer) ?? false)) {
      return const DropTargetPreview.newUnit();
    }

    for (final entry in unitKeys) {
      if (!(rectForKey(entry.value)?.contains(globalPointer) ?? false)) {
        continue;
      }
      if (!canDropToUnit(entry.key)) {
        continue;
      }
      return DropTargetPreview.existingUnit(entry.key);
    }

    return null;
  }

  Rect? rectForKey(GlobalKey key) {
    final context = key.currentContext;
    if (context == null) {
      return null;
    }
    final render = context.findRenderObject();
    if (render is! RenderBox || !render.hasSize) {
      return null;
    }
    final topLeft = render.localToGlobal(Offset.zero);
    return topLeft & render.size;
  }
}
