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
    this.highlighted = false,
    super.key,
  });

  final PieceDefinition piece;
  final double width;
  final double height;
  final bool elevated;
  final double angle;
  final bool highlighted;

  @override
  Widget build(BuildContext context) {
    final compact = width < 96 || height < 140;
    final tiny = width < 84 || height < 120;
    final padding = tiny ? 6.0 : (compact ? 8.0 : 10.0);
    final avatarRadius = tiny ? 16.0 : (compact ? 20.0 : 24.0);
    final accent = switch (piece.element) {
      SpiritElement.red => const Color(0xFFEF5350),
      SpiritElement.green => const Color(0xFF66BB6A),
      SpiritElement.blue => const Color(0xFF42A5F5),
    };
    final modeTextStyle = (compact
            ? Theme.of(context).textTheme.titleSmall
            : Theme.of(context).textTheme.titleMedium)
        ?.copyWith(
          fontWeight: FontWeight.w900,
          letterSpacing: 0.8,
          color: Colors.white,
        );
    final borderColor = elevated || highlighted
        ? accent.withValues(alpha: 0.95)
        : Colors.white24;
    return AnimatedScale(
      duration: const Duration(milliseconds: 90),
      curve: Curves.easeOutCubic,
      scale: elevated ? 1.04 : (highlighted ? 1.015 : 1.0),
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
            color: borderColor,
            width: elevated ? 2 : (highlighted ? 1.6 : 1),
          ),
          boxShadow: <BoxShadow>[
            if (elevated)
              BoxShadow(
                color: accent.withValues(alpha: 0.35),
                blurRadius: 18,
                spreadRadius: 1,
                offset: const Offset(0, 8),
              ),
            if (!elevated && highlighted)
              BoxShadow(
                color: accent.withValues(alpha: 0.26),
                blurRadius: 12,
                spreadRadius: 0.2,
                offset: const Offset(0, 3),
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
                child: _TagPill(
                  text: compact
                      ? _shortElement(piece.element)
                      : elementLabel(piece.element),
                  color: accent,
                ),
              ),
              SizedBox(height: tiny ? 4 : 6),
              Center(
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(_fullMode(piece.attackMode), style: modeTextStyle),
                ),
              ),
              SizedBox(height: tiny ? 2 : 6),
              Expanded(
                child: Center(
                  child: CircleAvatar(
                    radius: avatarRadius,
                    backgroundColor: accent.withValues(alpha: 0.25),
                    child: Text(
                      _elementGlyph(piece.element),
                      style: compact
                          ? Theme.of(context).textTheme.titleMedium
                          : Theme.of(context).textTheme.titleLarge,
                    ),
                  ),
                ),
              ),
              SizedBox(height: tiny ? 2 : 6),
              Center(
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(_fullMode(piece.defenseMode), style: modeTextStyle),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _fullMode(CombatMode mode) {
    return switch (mode) {
      CombatMode.physical => 'PHYSICAL',
      CombatMode.magical => 'MAGICAL',
    };
  }

  String _elementGlyph(SpiritElement element) {
    return switch (element) {
      SpiritElement.red => 'R',
      SpiritElement.green => 'G',
      SpiritElement.blue => 'B',
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
