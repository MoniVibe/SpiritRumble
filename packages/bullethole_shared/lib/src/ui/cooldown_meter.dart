import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

enum TimeBarOrientation { horizontal, vertical }

/// Generic cooldown/progress meter with optional vertical dice overlay.
///
/// The widget is asset-agnostic: game packages pass in the bar asset paths and
/// dice face resolver so this stays reusable across titles.
class CooldownMeter extends StatefulWidget {
  const CooldownMeter({
    required this.label,
    required this.remaining,
    required this.total,
    required this.activeColor,
    required this.isPlayerSide,
    required this.timeLabel,
    required this.readyToFlash,
    required this.flashTint,
    required this.flashDuration,
    required this.horizontalPrimaryAssetPath,
    required this.horizontalFallbackAssetPath,
    required this.verticalPrimaryAssetPath,
    required this.verticalFallbackAssetPath,
    this.diceFaceAssetBuilder,
    this.diceFaces = const <int>[],
    this.orientation = TimeBarOrientation.horizontal,
    super.key,
  });

  final String label;
  final Duration remaining;
  final Duration total;
  final Color activeColor;
  final bool isPlayerSide;
  final String timeLabel;
  final bool readyToFlash;
  final Color flashTint;
  final Duration flashDuration;
  final String horizontalPrimaryAssetPath;
  final String horizontalFallbackAssetPath;
  final String verticalPrimaryAssetPath;
  final String verticalFallbackAssetPath;
  final String? Function(int face)? diceFaceAssetBuilder;
  final List<int> diceFaces;
  final TimeBarOrientation orientation;

  @override
  State<CooldownMeter> createState() => _CooldownMeterState();
}

class _CooldownMeterState extends State<CooldownMeter>
    with TickerProviderStateMixin {
  late final AnimationController _pulse;
  late final Ticker _depletionTicker;
  Duration _remainingSnapshot = Duration.zero;
  DateTime _remainingSampledAt = DateTime.now();

  @override
  void initState() {
    super.initState();
    _remainingSnapshot = widget.remaining;
    _remainingSampledAt = DateTime.now();
    _pulse = AnimationController(vsync: this, duration: widget.flashDuration);
    _depletionTicker = createTicker((_) {
      if (!mounted) {
        return;
      }
      if (_effectiveRemaining().inMilliseconds <= 0) {
        _depletionTicker.stop();
      }
      setState(() {});
    });
    _syncPulse();
    _syncDepletionTicker();
  }

  @override
  void didUpdateWidget(covariant CooldownMeter oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.remaining != widget.remaining) {
      _remainingSnapshot = widget.remaining;
      _remainingSampledAt = DateTime.now();
    }
    if (oldWidget.flashDuration != widget.flashDuration) {
      _pulse.duration = widget.flashDuration;
    }
    _syncPulse();
    _syncDepletionTicker();
  }

  void _syncPulse() {
    if (widget.readyToFlash) {
      if (!_pulse.isAnimating) {
        _pulse.repeat(reverse: true);
      }
      return;
    }
    if (_pulse.isAnimating) {
      _pulse.stop();
    }
    _pulse.value = 0;
  }

  void _syncDepletionTicker() {
    if (_effectiveRemaining().inMilliseconds <= 0) {
      if (_depletionTicker.isActive) {
        _depletionTicker.stop();
      }
      return;
    }
    if (!_depletionTicker.isActive) {
      _depletionTicker.start();
    }
  }

  Duration _effectiveRemaining() {
    if (_remainingSnapshot.inMilliseconds <= 0) {
      return Duration.zero;
    }
    final elapsed = DateTime.now().difference(_remainingSampledAt);
    final remaining = _remainingSnapshot - elapsed;
    if (remaining.inMilliseconds <= 0) {
      return Duration.zero;
    }
    return remaining;
  }

  double _effectiveRatio() {
    final totalMs = widget.total.inMilliseconds;
    if (totalMs <= 0) {
      return 0;
    }
    final ratio = _effectiveRemaining().inMilliseconds / totalMs;
    return ratio.clamp(0.0, 1.0);
  }

  @override
  void dispose() {
    _depletionTicker.dispose();
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final clampedRatio = _effectiveRatio();
    final isVertical = widget.orientation == TimeBarOrientation.vertical;
    final barPrimaryAsset = isVertical
        ? widget.verticalPrimaryAssetPath
        : widget.horizontalPrimaryAssetPath;
    final barFallbackAsset = isVertical
        ? widget.verticalFallbackAssetPath
        : widget.horizontalFallbackAssetPath;

    return AnimatedBuilder(
      animation: _pulse,
      builder: (context, _) {
        final glow = widget.readyToFlash ? (0.2 + (0.8 * _pulse.value)) : 0.0;

        return DecoratedBox(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.22),
              width: 1,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.14),
                blurRadius: 14,
                offset: const Offset(0, 6),
              ),
              BoxShadow(
                color: widget.flashTint.withValues(alpha: 0.22 * glow),
                blurRadius: 12 + (22 * glow),
                spreadRadius: 0.5 + (3.5 * glow),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(18),
            child: Stack(
              fit: StackFit.expand,
              children: [
                ColorFiltered(
                  colorFilter: const ColorFilter.matrix(<double>[
                    0.2126,
                    0.7152,
                    0.0722,
                    0,
                    0,
                    0.2126,
                    0.7152,
                    0.0722,
                    0,
                    0,
                    0.2126,
                    0.7152,
                    0.0722,
                    0,
                    0,
                    0,
                    0,
                    0,
                    0.7,
                    0,
                  ]),
                  child: _buildBarImage(
                    primaryAssetPath: barPrimaryAsset,
                    fallbackAssetPath: barFallbackAsset,
                    filterQuality: FilterQuality.medium,
                  ),
                ),
                if (clampedRatio > 0)
                  ClipRect(
                    clipper: isVertical
                        ? _VerticalProgressClipper(clampedRatio)
                        : _HorizontalProgressClipper(clampedRatio),
                    child: ColorFiltered(
                      colorFilter: ColorFilter.mode(
                        widget.activeColor.withValues(alpha: 0.22),
                        BlendMode.hardLight,
                      ),
                      child: _buildBarImage(
                        primaryAssetPath: barPrimaryAsset,
                        fallbackAssetPath: barFallbackAsset,
                        filterQuality: FilterQuality.high,
                      ),
                    ),
                  ),
                if (widget.readyToFlash)
                  Positioned.fill(
                    child: IgnorePointer(
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          color: widget.flashTint.withValues(
                            alpha: 0.24 + (0.6 * _pulse.value),
                          ),
                        ),
                      ),
                    ),
                  ),
                Positioned.fill(
                  child: isVertical
                      ? _buildVerticalOverlay()
                      : _buildHorizontalOverlay(),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildBarImage({
    required String primaryAssetPath,
    required String fallbackAssetPath,
    required FilterQuality filterQuality,
  }) {
    return Image.asset(
      primaryAssetPath,
      fit: BoxFit.fill,
      filterQuality: filterQuality,
      errorBuilder: (context, error, stackTrace) {
        return Image.asset(
          fallbackAssetPath,
          fit: BoxFit.fill,
          filterQuality: filterQuality,
        );
      },
    );
  }

  Widget _buildHorizontalOverlay() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14),
      child: Row(
        children: [
          Text(
            widget.label,
            style: _labelStyle(fontSize: 13, letterSpacing: 0.25),
          ),
          if (widget.isPlayerSide) ...[
            const SizedBox(width: 5),
            Icon(
              Icons.person,
              size: 12,
              color: Colors.white.withValues(alpha: 0.96),
              shadows: const <Shadow>[
                Shadow(
                  color: Colors.black87,
                  blurRadius: 3,
                  offset: Offset(0, 1),
                ),
              ],
            ),
          ],
          const Spacer(),
          Text(widget.timeLabel, style: _timeStyle(fontSize: 13)),
        ],
      ),
    );
  }

  Widget _buildVerticalOverlay() {
    final hasDice = widget.diceFaces.isNotEmpty;
    final dieSize = widget.diceFaces.length <= 2 ? 19.0 : 15.0;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 8),
      child: Column(
        children: [
          Text(
            widget.label,
            textAlign: TextAlign.center,
            style: _labelStyle(fontSize: 11, letterSpacing: 0.18),
          ),
          if (widget.isPlayerSide) ...[
            const SizedBox(height: 2),
            Icon(
              Icons.person,
              size: 10,
              color: Colors.white.withValues(alpha: 0.96),
              shadows: const <Shadow>[
                Shadow(
                  color: Colors.black87,
                  blurRadius: 3,
                  offset: Offset(0, 1),
                ),
              ],
            ),
          ],
          if (hasDice) ...[
            const SizedBox(height: 6),
            Wrap(
              spacing: 2,
              runSpacing: 2,
              alignment: WrapAlignment.center,
              children: widget.diceFaces
                  .take(4)
                  .map(
                    (face) => _MeterDiceFace(
                      face: face,
                      size: dieSize,
                      assetPath: widget.diceFaceAssetBuilder?.call(face),
                    ),
                  )
                  .toList(growable: false),
            ),
          ],
          const Spacer(),
          Text(
            widget.timeLabel,
            textAlign: TextAlign.center,
            style: _timeStyle(fontSize: 11),
          ),
        ],
      ),
    );
  }

  TextStyle _labelStyle({
    required double fontSize,
    required double letterSpacing,
  }) {
    return TextStyle(
      fontFamily: 'Orbitron',
      fontWeight: FontWeight.w800,
      letterSpacing: letterSpacing,
      fontSize: fontSize,
      color: Colors.white.withValues(alpha: 0.96),
      shadows: const <Shadow>[
        Shadow(color: Colors.black87, blurRadius: 3, offset: Offset(0, 1)),
      ],
    );
  }

  TextStyle _timeStyle({required double fontSize}) {
    return TextStyle(
      fontFamily: 'Orbitron',
      fontWeight: FontWeight.w700,
      fontSize: fontSize,
      color: Colors.white.withValues(alpha: 0.96),
      shadows: const <Shadow>[
        Shadow(color: Colors.black87, blurRadius: 3, offset: Offset(0, 1)),
      ],
    );
  }
}

class _HorizontalProgressClipper extends CustomClipper<Rect> {
  const _HorizontalProgressClipper(this.progressRatio);

  final double progressRatio;

  @override
  Rect getClip(Size size) {
    final clamped = progressRatio.clamp(0.0, 1.0);
    return Rect.fromLTWH(0, 0, size.width * clamped, size.height);
  }

  @override
  bool shouldReclip(covariant _HorizontalProgressClipper oldClipper) {
    return oldClipper.progressRatio != progressRatio;
  }
}

class _VerticalProgressClipper extends CustomClipper<Rect> {
  const _VerticalProgressClipper(this.progressRatio);

  final double progressRatio;

  @override
  Rect getClip(Size size) {
    final clamped = progressRatio.clamp(0.0, 1.0);
    final clippedHeight = size.height * clamped;
    return Rect.fromLTWH(
      0,
      size.height - clippedHeight,
      size.width,
      clippedHeight,
    );
  }

  @override
  bool shouldReclip(covariant _VerticalProgressClipper oldClipper) {
    return oldClipper.progressRatio != progressRatio;
  }
}

class _MeterDiceFace extends StatelessWidget {
  const _MeterDiceFace({
    required this.face,
    required this.size,
    required this.assetPath,
  });

  final int face;
  final double size;
  final String? assetPath;

  @override
  Widget build(BuildContext context) {
    if (assetPath == null) {
      return _fallbackFace();
    }

    return ClipRRect(
      borderRadius: BorderRadius.circular(4),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.24),
          borderRadius: BorderRadius.circular(4),
          border: Border.all(color: Colors.white.withValues(alpha: 0.16)),
        ),
        child: Image.asset(
          assetPath!,
          width: size,
          height: size,
          fit: BoxFit.contain,
          filterQuality: FilterQuality.medium,
          errorBuilder: (context, error, stackTrace) => _fallbackFace(),
        ),
      ),
    );
  }

  Widget _fallbackFace() {
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        '$face',
        style: TextStyle(
          fontWeight: FontWeight.w800,
          color: const Color(0xFF212121),
          fontSize: size * 0.56,
        ),
      ),
    );
  }
}
