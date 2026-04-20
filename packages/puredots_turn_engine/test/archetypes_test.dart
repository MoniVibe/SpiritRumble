import 'package:puredots_turn_engine/puredots_turn_engine.dart';
import 'package:test/test.dart';

void main() {
  group('canonical card archetypes', () {
    test('contains all 12 element/mode combinations exactly once', () {
      expect(canonicalCardArchetypes.length, 12);

      final combos = canonicalCardArchetypes
          .map((a) => '${a.element}:${a.attackMode}:${a.defenseMode}')
          .toSet();
      expect(combos.length, 12);
    });

    test('uses stable canonical ids', () {
      final ids = canonicalCardArchetypes.map((a) => a.id).toSet();
      expect(ids.length, 12);

      expect(
        ids,
        containsAll(<String>[
          'blue_phys_phys',
          'blue_phys_mag',
          'blue_mag_phys',
          'blue_mag_mag',
          'green_phys_phys',
          'green_phys_mag',
          'green_mag_phys',
          'green_mag_mag',
          'red_phys_phys',
          'red_phys_mag',
          'red_mag_phys',
          'red_mag_mag',
        ]),
      );
    });

    test('builds canonical placeholder catalog in archetype order', () {
      final catalog = buildCanonicalPlaceholderCatalog();
      expect(catalog.length, canonicalCardArchetypes.length);
      expect(catalog.first.id, 'blue_phys_phys');
      expect(catalog.last.id, 'red_mag_mag');
    });
  });
}
