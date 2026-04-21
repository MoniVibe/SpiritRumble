import 'dart:ui';

import 'package:flutter/material.dart';

/// Shared visual shell for game screens.
class GameBackdrop extends StatelessWidget {
  const GameBackdrop({
    required this.child,
    this.backgroundAssetPath,
    this.fallbackColor = const Color(0xFF101A26),
    super.key,
  });

  final Widget child;
  final String? backgroundAssetPath;
  final Color fallbackColor;

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: <Widget>[
        Positioned.fill(
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: <Color>[
                  Color(0xFF05070B),
                  Color(0xFF0E1118),
                  Color(0xFF121621),
                ],
              ),
            ),
            child: backgroundAssetPath == null
                ? ColoredBox(color: fallbackColor.withValues(alpha: 0.08))
                : Image.asset(
                    backgroundAssetPath!,
                    fit: BoxFit.cover,
                    filterQuality: FilterQuality.medium,
                    errorBuilder: (context, error, stackTrace) =>
                        ColoredBox(color: fallbackColor),
                  ),
          ),
        ),
        Positioned.fill(
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: RadialGradient(
                center: Alignment.center,
                radius: 0.9,
                colors: <Color>[
                  Colors.white.withValues(alpha: 0.08),
                  Colors.transparent,
                ],
                stops: const <double>[0, 1],
              ),
            ),
          ),
        ),
        const _AmbientBlurBlob(
          top: -150,
          left: -130,
          size: 330,
          color: Color(0x88FF5A5A),
        ),
        const _AmbientBlurBlob(
          top: -70,
          right: -80,
          size: 260,
          color: Color(0x884F79FF),
        ),
        const _AmbientBlurBlob(
          bottom: -180,
          right: -130,
          size: 350,
          color: Color(0x88986BFF),
        ),
        Positioned.fill(
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: <Color>[
                  Colors.white.withValues(alpha: 0.1),
                  Colors.white.withValues(alpha: 0.02),
                  Colors.black.withValues(alpha: 0.44),
                ],
                stops: const <double>[0, 0.45, 1],
              ),
            ),
          ),
        ),
        Positioned.fill(child: child),
      ],
    );
  }
}

class _AmbientBlurBlob extends StatelessWidget {
  const _AmbientBlurBlob({
    required this.size,
    required this.color,
    this.top,
    this.right,
    this.bottom,
    this.left,
  });

  final double size;
  final Color color;
  final double? top;
  final double? right;
  final double? bottom;
  final double? left;

  @override
  Widget build(BuildContext context) {
    return Positioned(
      top: top,
      right: right,
      bottom: bottom,
      left: left,
      child: IgnorePointer(
        child: ImageFiltered(
          imageFilter: ImageFilter.blur(sigmaX: 70, sigmaY: 70),
          child: DecoratedBox(
            decoration: BoxDecoration(shape: BoxShape.circle, color: color),
            child: SizedBox.square(dimension: size),
          ),
        ),
      ),
    );
  }
}
