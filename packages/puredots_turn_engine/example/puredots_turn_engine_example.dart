import 'package:puredots_turn_engine/puredots_turn_engine.dart';

void main() {
  const rules = MatchRules(firstPlayerOpeningDraft: 1, standardDraft: 2);
  final catalog = <PieceDefinition>[
    const PieceDefinition(
      id: 'ember_fox',
      name: 'Ember Fox',
      element: SpiritElement.red,
      attackMode: CombatMode.physical,
      defenseMode: CombatMode.magical,
      attack: 3,
      defense: 2,
    ),
    const PieceDefinition(
      id: 'reef_oracle',
      name: 'Reef Oracle',
      element: SpiritElement.blue,
      attackMode: CombatMode.magical,
      defenseMode: CombatMode.physical,
      attack: 2,
      defense: 3,
    ),
    const PieceDefinition(
      id: 'vine_titan',
      name: 'Vine Titan',
      element: SpiritElement.green,
      attackMode: CombatMode.physical,
      defenseMode: CombatMode.magical,
      attack: 2,
      defense: 4,
    ),
  ];

  final engine = const TurnEngine();
  var state = engine.newMatch(draftCatalog: catalog, rules: rules);
  print('Turn ${state.turnNumber}, phase: ${state.phase}');

  final draftPieceId = state.pool.first.instanceId;
  final drafted = engine.applyCommand(
    state,
    state.activePlayerIndex,
    DraftFromPoolMove(poolPieceId: draftPieceId),
    rules: rules,
  );
  state = drafted.state;
  print(
    'After draft: hand=${state.activePlayer.hand.length}, phase=${state.phase}',
  );
}
