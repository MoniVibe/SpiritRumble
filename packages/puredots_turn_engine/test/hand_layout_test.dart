import 'package:puredots_turn_engine/puredots_turn_engine.dart';
import 'package:test/test.dart';

void main() {
  group('computeFanLayout', () {
    test('returns empty for zero count', () {
      final slots = computeFanLayout(
        const FanLayoutInput(itemCount: 0, availableWidth: 500),
      );
      expect(slots, isEmpty);
    });

    test('fans around center with symmetric rotation', () {
      final slots = computeFanLayout(
        const FanLayoutInput(itemCount: 5, availableWidth: 500),
      );
      expect(slots.length, 5);
      expect(slots[0].rotationRadians, lessThan(0));
      expect(slots[4].rotationRadians, greaterThan(0));
      expect(slots[2].rotationRadians.abs(), lessThan(0.0001));
    });

    test('emphasized index shifts neighbors apart', () {
      final base = computeFanLayout(
        const FanLayoutInput(itemCount: 4, availableWidth: 500),
      );
      final emphasized = computeFanLayout(
        const FanLayoutInput(
          itemCount: 4,
          availableWidth: 500,
          emphasizedIndex: 1,
        ),
      );
      expect(emphasized[0].x, lessThan(base[0].x));
      expect(emphasized[2].x, greaterThan(base[2].x));
    });
  });
}
