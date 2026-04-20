import 'dart:math' as math;

class FanLayoutSlot {
  const FanLayoutSlot({
    required this.x,
    required this.y,
    required this.rotationRadians,
  });

  final double x;
  final double y;
  final double rotationRadians;
}

class FanLayoutInput {
  const FanLayoutInput({
    required this.itemCount,
    required this.availableWidth,
    this.cardWidth = 116,
    this.baseOverlapRatio = 0.32,
    this.maxFanAngleRadians = 0.26,
    this.maxArcLift = 24,
    this.emphasizedIndex,
    this.emphasisShift = 10,
  });

  final int itemCount;
  final double availableWidth;
  final double cardWidth;
  final double baseOverlapRatio;
  final double maxFanAngleRadians;
  final double maxArcLift;
  final int? emphasizedIndex;
  final double emphasisShift;
}

List<FanLayoutSlot> computeFanLayout(FanLayoutInput input) {
  final count = input.itemCount;
  if (count <= 0) {
    return const <FanLayoutSlot>[];
  }

  final overlap = input.cardWidth * input.baseOverlapRatio;
  final step = input.cardWidth - overlap;
  final rawWidth = input.cardWidth + (count - 1) * step;
  final startX = (input.availableWidth - rawWidth) / 2;
  final center = (count - 1) / 2;
  final slots = <FanLayoutSlot>[];

  for (var i = 0; i < count; i++) {
    final normalized = center == 0 ? 0.0 : (i - center) / center;
    final rotation = normalized * input.maxFanAngleRadians;
    final arc = (1 - normalized.abs()) * input.maxArcLift;
    var x = startX + i * step;

    if (input.emphasizedIndex != null) {
      if (i < input.emphasizedIndex!) {
        x -= input.emphasisShift;
      } else if (i > input.emphasizedIndex!) {
        x += input.emphasisShift;
      }
    }

    slots.add(
      FanLayoutSlot(
        x: math.max(0, x),
        y: input.maxArcLift - arc,
        rotationRadians: rotation,
      ),
    );
  }

  return slots;
}
