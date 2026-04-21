import 'package:flutter/material.dart';

enum PieceSkinRenderMode { image, flat }

/// Backgammon board style option.
@immutable
class BoardSkinOption {
  const BoardSkinOption({
    required this.id,
    required this.label,
    this.assetPath,
    this.tintOverlay,
    this.isPremium = false,
  });

  final String id;
  final String label;
  final String? assetPath;
  final Color? tintOverlay;
  final bool isPremium;
}

/// Backgammon checker style option.
@immutable
class PieceSkinOption {
  const PieceSkinOption({
    required this.id,
    required this.label,
    required this.mode,
    this.whiteAssetPath,
    this.blackAssetPath,
    this.tintColor,
    this.isPremium = false,
  });

  final String id;
  final String label;
  final PieceSkinRenderMode mode;
  final String? whiteAssetPath;
  final String? blackAssetPath;
  final Color? tintColor;
  final bool isPremium;

  String? assetForColor(String color) {
    return color == 'w' ? whiteAssetPath : blackAssetPath;
  }
}

/// Chess board style option.
@immutable
class ChessBoardSkinOption {
  const ChessBoardSkinOption({
    required this.id,
    required this.label,
    required this.assetPath,
    required this.playableInsetRatio,
    required this.playableSizeRatio,
    this.isPremium = false,
  });

  final String id;
  final String label;
  final String assetPath;
  final double playableInsetRatio;
  final double playableSizeRatio;
  final bool isPremium;
}

/// Chess piece style option (maps FEN symbols to sprites).
@immutable
class ChessPieceSkinOption {
  const ChessPieceSkinOption({
    required this.id,
    required this.label,
    required this.spriteMap,
    this.pieceScale = 1.0,
    this.pieceYOffset = 0,
    this.tintColor,
    this.isPremium = false,
  });

  final String id;
  final String label;
  final Map<String, String> spriteMap;
  final double pieceScale;
  final double pieceYOffset;
  final Color? tintColor;
  final bool isPremium;
}
