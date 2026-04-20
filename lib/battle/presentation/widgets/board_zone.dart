import 'package:flutter/material.dart';
import 'package:puredots_turn_engine/puredots_turn_engine.dart';

import '../../application/target_preview.dart';
import '../../domain/battle_view_models.dart';

class BoardZone extends StatelessWidget {
  const BoardZone({
    required this.activePlayer,
    required this.opponentPlayer,
    required this.selectedAttackerUnitId,
    required this.hoverTarget,
    required this.newUnitDropKey,
    required this.unitDropKeyFor,
    required this.onChooseAttacker,
    required this.onAttack,
    required this.onEndTurn,
    super.key,
  });

  final PlayerState activePlayer;
  final PlayerState opponentPlayer;
  final String? selectedAttackerUnitId;
  final DropTargetPreview? hoverTarget;
  final GlobalKey newUnitDropKey;
  final GlobalKey Function(String unitId) unitDropKeyFor;
  final void Function(String unitId, int pieceIndex) onChooseAttacker;
  final void Function(String attackerUnitId, String? targetUnitId) onAttack;
  final VoidCallback onEndTurn;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text('Drop Zones', style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 8),
        Card(
          key: newUnitDropKey,
          color: hoverTarget?.kind == DropTargetKind.newUnit
              ? Theme.of(context).colorScheme.primary.withValues(alpha: 0.28)
              : null,
          child: const ListTile(
            title: Text('New Unit Slot'),
            subtitle: Text('Drop a hand card here to create a new unit'),
            trailing: Icon(Icons.add_box_outlined),
          ),
        ),
        const SizedBox(height: 8),
        Text('Your Units', style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 8),
        if (activePlayer.units.isEmpty)
          const Text('No units on field.')
        else
          Column(
            children: activePlayer.units
                .map((unit) => _buildUnitCardForMain(context, unit))
                .toList(growable: false),
          ),
        const SizedBox(height: 10),
        Text('Attack Targets', style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 8),
        if (selectedAttackerUnitId == null)
          const Text('Choose an attacker piece first.')
        else ...<Widget>[
          if (opponentPlayer.units.isEmpty)
            FilledButton(
              onPressed: () => onAttack(selectedAttackerUnitId!, null),
              child: const Text('Attack Opponent Directly'),
            )
          else
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: opponentPlayer.units
                  .map(
                    (unit) => FilledButton(
                      onPressed: () =>
                          onAttack(selectedAttackerUnitId!, unit.unitId),
                      child: Text('Attack ${unit.unitId}'),
                    ),
                  )
                  .toList(growable: false),
            ),
        ],
        const SizedBox(height: 12),
        FilledButton(onPressed: onEndTurn, child: const Text('End Turn')),
        const SizedBox(height: 12),
      ],
    );
  }

  Widget _buildUnitCardForMain(BuildContext context, UnitState unit) {
    final highlighted =
        hoverTarget?.kind == DropTargetKind.existingUnit &&
        hoverTarget?.unitId == unit.unitId;
    return Card(
      key: unitDropKeyFor(unit.unitId),
      color: highlighted
          ? Theme.of(context).colorScheme.secondary.withValues(alpha: 0.24)
          : null,
      child: Padding(
        padding: const EdgeInsets.all(8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Wrap(
              spacing: 8,
              children: <Widget>[
                Text(unit.unitId),
                if (unit.attackedThisTurn) const Chip(label: Text('Attacked')),
                if (selectedAttackerUnitId == unit.unitId)
                  const Chip(label: Text('Selected')),
              ],
            ),
            const SizedBox(height: 6),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: List<Widget>.generate(unit.pieces.length, (int i) {
                return OutlinedButton(
                  onPressed: () => onChooseAttacker(unit.unitId, i),
                  child: Text(
                    '${i == unit.attackingPieceIndex ? 'ATK>' : ''} '
                    '${i == unit.defendingPieceIndex ? 'DEF>' : ''}'
                    '${pieceLabel(unit.pieces[i].definition)}',
                  ),
                );
              }),
            ),
          ],
        ),
      ),
    );
  }
}
