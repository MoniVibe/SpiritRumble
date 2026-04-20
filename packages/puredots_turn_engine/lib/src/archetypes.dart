import 'models.dart';

class CardArchetype {
  const CardArchetype({
    required this.id,
    required this.element,
    required this.attackMode,
    required this.defenseMode,
    required this.displayName,
  });

  final String id;
  final SpiritElement element;
  final CombatMode attackMode;
  final CombatMode defenseMode;
  final String displayName;
}

const List<CardArchetype> canonicalCardArchetypes = <CardArchetype>[
  CardArchetype(
    id: 'blue_phys_phys',
    element: SpiritElement.blue,
    attackMode: CombatMode.physical,
    defenseMode: CombatMode.physical,
    displayName: 'Blue Guardian',
  ),
  CardArchetype(
    id: 'blue_phys_mag',
    element: SpiritElement.blue,
    attackMode: CombatMode.physical,
    defenseMode: CombatMode.magical,
    displayName: 'Blue Duelist',
  ),
  CardArchetype(
    id: 'blue_mag_phys',
    element: SpiritElement.blue,
    attackMode: CombatMode.magical,
    defenseMode: CombatMode.physical,
    displayName: 'Blue Adept',
  ),
  CardArchetype(
    id: 'blue_mag_mag',
    element: SpiritElement.blue,
    attackMode: CombatMode.magical,
    defenseMode: CombatMode.magical,
    displayName: 'Blue Oracle',
  ),
  CardArchetype(
    id: 'green_phys_phys',
    element: SpiritElement.green,
    attackMode: CombatMode.physical,
    defenseMode: CombatMode.physical,
    displayName: 'Green Guardian',
  ),
  CardArchetype(
    id: 'green_phys_mag',
    element: SpiritElement.green,
    attackMode: CombatMode.physical,
    defenseMode: CombatMode.magical,
    displayName: 'Green Duelist',
  ),
  CardArchetype(
    id: 'green_mag_phys',
    element: SpiritElement.green,
    attackMode: CombatMode.magical,
    defenseMode: CombatMode.physical,
    displayName: 'Green Adept',
  ),
  CardArchetype(
    id: 'green_mag_mag',
    element: SpiritElement.green,
    attackMode: CombatMode.magical,
    defenseMode: CombatMode.magical,
    displayName: 'Green Oracle',
  ),
  CardArchetype(
    id: 'red_phys_phys',
    element: SpiritElement.red,
    attackMode: CombatMode.physical,
    defenseMode: CombatMode.physical,
    displayName: 'Red Guardian',
  ),
  CardArchetype(
    id: 'red_phys_mag',
    element: SpiritElement.red,
    attackMode: CombatMode.physical,
    defenseMode: CombatMode.magical,
    displayName: 'Red Duelist',
  ),
  CardArchetype(
    id: 'red_mag_phys',
    element: SpiritElement.red,
    attackMode: CombatMode.magical,
    defenseMode: CombatMode.physical,
    displayName: 'Red Adept',
  ),
  CardArchetype(
    id: 'red_mag_mag',
    element: SpiritElement.red,
    attackMode: CombatMode.magical,
    defenseMode: CombatMode.magical,
    displayName: 'Red Oracle',
  ),
];

List<PieceDefinition> buildCanonicalPlaceholderCatalog({
  int baseAttack = 2,
  int baseDefense = 2,
  int physicalAttackBonus = 1,
  int magicalDefenseBonus = 1,
  int redAttackBonus = 1,
  int greenDefenseBonus = 1,
}) {
  return List<PieceDefinition>.unmodifiable(
    canonicalCardArchetypes.map((CardArchetype archetype) {
      var attack = baseAttack;
      var defense = baseDefense;

      if (archetype.attackMode == CombatMode.physical) {
        attack += physicalAttackBonus;
      }
      if (archetype.defenseMode == CombatMode.magical) {
        defense += magicalDefenseBonus;
      }
      if (archetype.element == SpiritElement.red) {
        attack += redAttackBonus;
      }
      if (archetype.element == SpiritElement.green) {
        defense += greenDefenseBonus;
      }

      return PieceDefinition(
        id: archetype.id,
        name: archetype.displayName,
        element: archetype.element,
        attackMode: archetype.attackMode,
        defenseMode: archetype.defenseMode,
        attack: attack,
        defense: defense,
      );
    }),
  );
}

final List<PieceDefinition> canonicalPlaceholderCatalog =
    buildCanonicalPlaceholderCatalog();
