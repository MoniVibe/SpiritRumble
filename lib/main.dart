import 'package:bullethole_shared/bullethole_shared.dart';
import 'package:flutter/material.dart';
import 'package:puredots_turn_engine/puredots_turn_engine.dart';

void main() {
  runApp(const SpritRumbleApp());
}

class SpritRumbleApp extends StatelessWidget {
  const SpritRumbleApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Sprit Rumble',
      theme: buildBulletholeGameTheme(
        palette: const BulletholeThemePalette(
          primary: Color(0xFFDC4A3D),
          secondary: Color(0xFF4FA1E2),
          tertiary: Color(0xFF61BF78),
        ),
      ),
      home: const SpritRumbleScreen(),
    );
  }
}

class SpritRumbleScreen extends StatefulWidget {
  const SpritRumbleScreen({super.key});

  @override
  State<SpritRumbleScreen> createState() => _SpritRumbleScreenState();
}

class _SpritRumbleScreenState extends State<SpritRumbleScreen> {
  static const TurnEngine _engine = TurnEngine();
  static const MatchRules _rules = MatchRules(
    startingHealth: 24,
    poolSize: 5,
    firstPlayerOpeningDraft: 1,
    standardDraft: 2,
  );

  static const List<PieceDefinition> _catalog = <PieceDefinition>[
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

  late GameState _state;
  String? _selectedAttackerUnitId;
  String? _lastError;

  @override
  void initState() {
    super.initState();
    _state = _engine.newMatch(draftCatalog: _catalog, rules: _rules);
  }

  void _resetMatch() {
    setState(() {
      _state = _engine.newMatch(draftCatalog: _catalog, rules: _rules);
      _selectedAttackerUnitId = null;
      _lastError = null;
    });
  }

  void _dispatch(GameCommand command) {
    final result = _engine.applyCommand(
      _state,
      _state.activePlayerIndex,
      command,
      rules: _rules,
    );
    setState(() {
      if (!result.applied) {
        _lastError = result.reason;
        return;
      }
      _state = result.state;
      _lastError = null;
      if (_selectedAttackerUnitId != null &&
          !_state.activePlayer.units.any(
            (u) => u.unitId == _selectedAttackerUnitId,
          )) {
        _selectedAttackerUnitId = null;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final active = _state.activePlayer;
    final opponent = _state.opposingPlayer;
    final winner = _state.winnerIndex;
    final isDraft = _state.phase == TurnPhase.draftFromPool;
    final isMain = _state.phase == TurnPhase.mainActions;
    final isChooseDefenders = _state.phase == TurnPhase.chooseDefenders;

    return Scaffold(
      body: GameBackdrop(
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Row(
                  children: <Widget>[
                    Text(
                      'Sprit Rumble',
                      style: Theme.of(context).textTheme.headlineSmall,
                    ),
                    const Spacer(),
                    FilledButton.tonal(
                      onPressed: _resetMatch,
                      child: const Text('New Match'),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: <Widget>[
                    Chip(label: Text('Turn ${_state.turnNumber}')),
                    Chip(label: Text('Active: ${active.id}')),
                    Chip(label: Text('Phase: ${_phaseLabel(_state.phase)}')),
                    Chip(label: Text('Pool ${_state.pool.length}/5')),
                    if (winner != null)
                      Chip(label: Text('Winner: ${_state.players[winner].id}')),
                  ],
                ),
                if (_lastError != null) ...<Widget>[
                  const SizedBox(height: 8),
                  Text('Last rule denial: $_lastError'),
                ],
                const SizedBox(height: 10),
                _ShamanSummary(player: active, caption: 'Current'),
                const SizedBox(height: 8),
                _ShamanSummary(player: opponent, caption: 'Opponent'),
                const SizedBox(height: 10),
                if (isDraft) _buildDraftPanel(),
                if (isMain) _buildMainPanel(),
                if (isChooseDefenders) _buildDefenderPanel(),
                const SizedBox(height: 10),
                Text(
                  'Event Log',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 8),
                Expanded(
                  child: Card(
                    child: ListView.builder(
                      reverse: true,
                      padding: const EdgeInsets.all(12),
                      itemCount: _state.eventLog.length,
                      itemBuilder: (BuildContext context, int index) {
                        final reversedIndex =
                            _state.eventLog.length - 1 - index;
                        return Text('• ${_state.eventLog[reversedIndex]}');
                      },
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDraftPanel() {
    return Expanded(
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              'Draft From Shared Pool',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _state.pool
                  .map(
                    (piece) => FilledButton.tonal(
                      onPressed: () => _dispatch(
                        DraftFromPoolMove(poolPieceId: piece.instanceId),
                      ),
                      child: Text(_pieceLabel(piece.definition)),
                    ),
                  )
                  .toList(growable: false),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMainPanel() {
    final active = _state.activePlayer;
    final opponent = _state.opposingPlayer;
    return Expanded(
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text('Hand Actions', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 8),
            if (active.hand.isEmpty)
              const Text('No pieces in hand.')
            else
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: active.hand
                    .map(
                      (piece) => Card(
                        child: Padding(
                          padding: const EdgeInsets.all(8),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: <Widget>[
                              Text(_pieceLabel(piece.definition)),
                              const SizedBox(height: 6),
                              Wrap(
                                spacing: 8,
                                runSpacing: 8,
                                children: <Widget>[
                                  FilledButton.tonal(
                                    onPressed: () => _dispatch(
                                      PlayToNewUnitMove(
                                        handPieceId: piece.instanceId,
                                      ),
                                    ),
                                    child: const Text('Play To New Unit'),
                                  ),
                                  ...active.units.map(
                                    (unit) => OutlinedButton(
                                      onPressed: () => _dispatch(
                                        AddToExistingUnitMove(
                                          handPieceId: piece.instanceId,
                                          unitId: unit.unitId,
                                        ),
                                      ),
                                      child: Text('Add To ${unit.unitId}'),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                    )
                    .toList(growable: false),
              ),
            const SizedBox(height: 10),
            Text('Your Units', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 8),
            if (active.units.isEmpty)
              const Text('No units on field.')
            else
              Column(
                children: active.units
                    .map(
                      (unit) => Card(
                        child: Padding(
                          padding: const EdgeInsets.all(8),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: <Widget>[
                              Wrap(
                                spacing: 8,
                                children: <Widget>[
                                  Text(unit.unitId),
                                  if (unit.attackedThisTurn)
                                    const Chip(label: Text('Attacked')),
                                  if (_selectedAttackerUnitId == unit.unitId)
                                    const Chip(label: Text('Selected')),
                                ],
                              ),
                              const SizedBox(height: 6),
                              Wrap(
                                spacing: 8,
                                runSpacing: 8,
                                children: List<Widget>.generate(unit.pieces.length, (
                                  int i,
                                ) {
                                  return OutlinedButton(
                                    onPressed: () {
                                      _dispatch(
                                        ChooseAttackerMove(
                                          unitId: unit.unitId,
                                          pieceIndex: i,
                                        ),
                                      );
                                      setState(() {
                                        _selectedAttackerUnitId = unit.unitId;
                                      });
                                    },
                                    child: Text(
                                      '${i == unit.attackingPieceIndex ? 'ATK>' : ''} '
                                      '${i == unit.defendingPieceIndex ? 'DEF>' : ''}'
                                      '${_pieceLabel(unit.pieces[i].definition)}',
                                    ),
                                  );
                                }),
                              ),
                            ],
                          ),
                        ),
                      ),
                    )
                    .toList(growable: false),
              ),
            const SizedBox(height: 10),
            Text(
              'Attack Targets',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 8),
            if (_selectedAttackerUnitId == null)
              const Text('Choose an attacker piece first.')
            else ...<Widget>[
              if (opponent.units.isEmpty)
                FilledButton(
                  onPressed: () => _dispatch(
                    AttackUnitMove(attackerUnitId: _selectedAttackerUnitId!),
                  ),
                  child: const Text('Attack Opponent Directly'),
                )
              else
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: opponent.units
                      .map(
                        (unit) => FilledButton(
                          onPressed: () => _dispatch(
                            AttackUnitMove(
                              attackerUnitId: _selectedAttackerUnitId!,
                              targetUnitId: unit.unitId,
                            ),
                          ),
                          child: Text('Attack ${unit.unitId}'),
                        ),
                      )
                      .toList(growable: false),
                ),
            ],
            const SizedBox(height: 12),
            FilledButton(
              onPressed: () => _dispatch(EndTurnMove()),
              child: const Text('End Turn'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDefenderPanel() {
    final active = _state.activePlayer;
    return Expanded(
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              'Choose Defenders For Your Units',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 8),
            if (active.units.isEmpty)
              const Text('No units: turn will auto-advance.')
            else
              Column(
                children: active.units
                    .map(
                      (unit) => Card(
                        child: Padding(
                          padding: const EdgeInsets.all(8),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: <Widget>[
                              Text(
                                '${unit.unitId} (${unit.defendingPieceIndex == null ? 'unset' : 'defender ${unit.defendingPieceIndex}'})',
                              ),
                              const SizedBox(height: 6),
                              Wrap(
                                spacing: 8,
                                runSpacing: 8,
                                children: List<Widget>.generate(
                                  unit.pieces.length,
                                  (int i) {
                                    return FilledButton.tonal(
                                      onPressed: () => _dispatch(
                                        ChooseDefenderMove(
                                          unitId: unit.unitId,
                                          pieceIndex: i,
                                        ),
                                      ),
                                      child: Text('Defend With #$i'),
                                    );
                                  },
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    )
                    .toList(growable: false),
              ),
          ],
        ),
      ),
    );
  }

  String _phaseLabel(TurnPhase phase) {
    switch (phase) {
      case TurnPhase.startTurn:
        return 'Start';
      case TurnPhase.draftFromPool:
        return 'Draft';
      case TurnPhase.mainActions:
        return 'Main';
      case TurnPhase.resolveCombat:
        return 'Combat';
      case TurnPhase.chooseDefenders:
        return 'Defenders';
      case TurnPhase.endTurn:
        return 'End';
      case TurnPhase.gameOver:
        return 'Game Over';
    }
  }
}

class _ShamanSummary extends StatelessWidget {
  const _ShamanSummary({required this.player, required this.caption});

  final PlayerState player;
  final String caption;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(10),
        child: Wrap(
          spacing: 10,
          runSpacing: 6,
          children: <Widget>[
            Text('$caption: ${player.id}'),
            Text('HP ${player.health}'),
            Text('Hand ${player.hand.length}'),
            Text('Units ${player.units.length}'),
          ],
        ),
      ),
    );
  }
}

String _pieceLabel(PieceDefinition piece) {
  return '${piece.name}\n${_elementLabel(piece.element)} '
      'ATK ${piece.attack}/${_modeLabel(piece.attackMode)} '
      'DEF ${piece.defense}/${_modeLabel(piece.defenseMode)}';
}

String _modeLabel(CombatMode mode) {
  switch (mode) {
    case CombatMode.physical:
      return 'PHY';
    case CombatMode.magical:
      return 'MAG';
  }
}

String _elementLabel(SpiritElement element) {
  switch (element) {
    case SpiritElement.red:
      return 'RED';
    case SpiritElement.green:
      return 'GREEN';
    case SpiritElement.blue:
      return 'BLUE';
  }
}
