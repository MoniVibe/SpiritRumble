import 'package:puredots_turn_engine/puredots_turn_engine.dart';

const MatchRules defaultBattleRules = MatchRules(
  startingHealth: 24,
  poolSize: 5,
  firstPlayerOpeningDraft: 1,
  standardDraft: 2,
);

final List<PieceDefinition> defaultBattleCatalog = List<PieceDefinition>.from(
  canonicalPlaceholderCatalog,
  growable: false,
);
