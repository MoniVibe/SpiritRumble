import 'package:flutter/material.dart';

/// Renders an icon from assets with a material fallback.
///
/// Reasoning:
/// - Keeps icon presentation consistent across game clients.
/// - Fallback prevents broken UI if an optional asset is missing.
class AppAssetIcon extends StatelessWidget {
  const AppAssetIcon(
    this.assetPath, {
    required this.fallbackIcon,
    this.size = 18,
    super.key,
  });

  final String assetPath;
  final IconData fallbackIcon;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Image.asset(
      assetPath,
      width: size,
      height: size,
      fit: BoxFit.contain,
      filterQuality: FilterQuality.medium,
      errorBuilder: (context, error, stackTrace) {
        return Icon(fallbackIcon, size: size);
      },
    );
  }
}
