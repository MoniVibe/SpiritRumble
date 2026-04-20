import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:puredots_turn_engine/puredots_turn_engine.dart';

import '../../domain/battle_view_models.dart';

class SpiritCardView extends StatelessWidget {
  const SpiritCardView({
    required this.piece,
    required this.width,
    required this.height,
    required this.elevated,
    required this.angle,
    super.key,
  });

  final PieceDefinition piece;
  final double width;
  final double height;
  final bool elevated;
  final double angle;

  @override
  Widget build(BuildContext context) {
    final compact = width < 96 || height < 140;
    final tiny = width < 84 || height < 120;
    final padding = tiny ? 6.0 : (compact ? 8.0 : 10.0);
    final avatarRadius = tiny ? 16.0 : (compact ? 20.0 : 24.0);
    final titleStyle = compact
        ? Theme.of(context).textTheme.labelLarge
        : Theme.of(context).textTheme.titleMedium;
    final accent = switch (piece.element) {
      SpiritElement.red => const Color(0xFFEF5350),
      SpiritElement.green => const Color(0xFF66BB6A),
      SpiritElement.blue => const Color(0xFF42A5F5),
    };
    return AnimatedScale(
      duration: const Duration(milliseconds: 90),
      curve: Curves.easeOutCubic,
      scale: elevated ? 1.08 : 1.0,
      child: Container(
        width: width,
        height: height,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14),
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: <Color>[
              accent.withValues(alpha: 0.40),
              const Color(0xFF121826),
            ],
          ),
          border: Border.all(
            color: elevated ? accent.withValues(alpha: 0.95) : Colors.white24,
            width: elevated ? 2 : 1,
          ),
          boxShadow: <BoxShadow>[
            if (elevated)
              BoxShadow(
                color: accent.withValues(alpha: 0.35),
                blurRadius: 18,
                spreadRadius: 1,
                offset: const Offset(0, 8),
              ),
          ],
        ),
        child: Padding(
          padding: EdgeInsets.all(padding),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              FittedBox(
                fit: BoxFit.scaleDown,
                child: Row(
                  children: <Widget>[
                    _TagPill(
                      text: compact
                          ? _shortElement(piece.element)
                          : elementLabel(piece.element),
                      color: accent,
                    ),
                    const SizedBox(width: 6),
                    _TagPill(
                      text: compact
                          ? _shortMode(piece.attackMode)
                          : modeLabel(piece.attackMode),
                      color: Colors.white24,
                    ),
                  ],
                ),
              ),
              const Spacer(),
              Center(
                child: CircleAvatar(
                  radius: avatarRadius,
                  backgroundColor: accent.withValues(alpha: 0.25),
                  child: Text(
                    piece.name.isEmpty
                        ? '?'
                        : piece.name.substring(0, 1).toUpperCase(),
                    style: compact
                        ? Theme.of(context).textTheme.titleMedium
                        : Theme.of(context).textTheme.titleLarge,
                  ),
                ),
              ),
              const Spacer(),
              Text(
                piece.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: titleStyle,
              ),
              SizedBox(height: tiny ? 1 : 4),
              FittedBox(
                fit: BoxFit.scaleDown,
                child: Row(
                  children: <Widget>[
                    Text('${compact ? 'A' : 'ATK'} ${piece.attack}'),
                    const SizedBox(width: 10),
                    Text('${compact ? 'D' : 'DEF'} ${piece.defense}'),
                  ],
                ),
              ),
              if (!compact) ...<Widget>[
                const SizedBox(height: 2),
                Text(
                  'Tilt ${(angle * 180 / math.pi).abs().toStringAsFixed(0)}°',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  String _shortMode(CombatMode mode) {
    return switch (mode) {
      CombatMode.physical => 'PHY',
      CombatMode.magical => 'MAG',
    };
  }

  String _shortElement(SpiritElement element) {
    return switch (element) {
      SpiritElement.red => 'RED',
      SpiritElement.green => 'GRN',
      SpiritElement.blue => 'BLU',
    };
  }
}

class _TagPill extends StatelessWidget {
  const _TagPill({required this.text, required this.color});

  final String text;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(999),
        color: color,
      ),
      child: Text(
        text,
        style: Theme.of(
          context,
        ).textTheme.labelSmall?.copyWith(fontWeight: FontWeight.w700),
      ),
    );
  }
}
