import 'package:puredots_turn_engine/puredots_turn_engine.dart';

const MatchRules defaultBattleRules = MatchRules(
  startingHealth: 24,
  poolSize: 5,
  firstPlayerOpeningDraft: 1,
  standardDraft: 2,
);

const List<PieceDefinition> defaultBattleCatalog = <PieceDefinition>[
  PieceDefinition(
    id: 'ember_hound',
    name: 'Ember Hound',
    element: SpiritElement.red,
    attackMode: CombatMode.physical,
    defenseMode: CombatMode.magical,
    attack: 4,
    defense: 2,
  ),
  PieceDefinition(
    id: 'ash_sentinel',
    name: 'Ash Sentinel',
    element: SpiritElement.red,
    attackMode: CombatMode.magical,
    defenseMode: CombatMode.magical,
    attack: 2,
    defense: 3,
  ),
  PieceDefinition(
    id: 'tidal_scholar',
    name: 'Tidal Scholar',
    element: SpiritElement.blue,
    attackMode: CombatMode.magical,
    defenseMode: CombatMode.physical,
    attack: 3,
    defense: 3,
  ),
  PieceDefinition(
    id: 'frost_lancer',
    name: 'Frost Lancer',
    element: SpiritElement.blue,
    attackMode: CombatMode.physical,
    defenseMode: CombatMode.magical,
    attack: 3,
    defense: 2,
  ),
  PieceDefinition(
    id: 'grove_keeper',
    name: 'Grove Keeper',
    element: SpiritElement.green,
    attackMode: CombatMode.physical,
    defenseMode: CombatMode.magical,
    attack: 2,
    defense: 4,
  ),
  PieceDefinition(
    id: 'wild_oracle',
    name: 'Wild Oracle',
    element: SpiritElement.green,
    attackMode: CombatMode.magical,
    defenseMode: CombatMode.physical,
    attack: 2,
    defense: 3,
  ),
];
