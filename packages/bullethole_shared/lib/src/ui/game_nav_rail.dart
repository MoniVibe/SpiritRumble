import 'package:flutter/material.dart';

@immutable
class GameNavDestination {
  const GameNavDestination({
    required this.icon,
    required this.tooltip,
    this.isActive = false,
    this.onTap,
  });

  final IconData icon;
  final String tooltip;
  final bool isActive;
  final VoidCallback? onTap;
}

/// Compact left rail inspired by the Figma Make shell.
class GameNavRail extends StatelessWidget {
  const GameNavRail({
    required this.destinations,
    this.brandIcon = Icons.gps_fixed_rounded,
    this.brandColor = const Color(0xFFE53935),
    this.width = 64,
    super.key,
  });

  final List<GameNavDestination> destinations;
  final IconData brandIcon;
  final Color brandColor;
  final double width;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: const Color(0xE6101218),
        border: Border(
          right: BorderSide(
            color: Colors.white.withValues(alpha: 0.08),
            width: 1,
          ),
        ),
      ),
      child: SizedBox(
        width: width,
        child: Column(
          children: <Widget>[
            const SizedBox(height: 10),
            DecoratedBox(
              decoration: BoxDecoration(
                color: brandColor,
                borderRadius: BorderRadius.circular(12),
                boxShadow: <BoxShadow>[
                  BoxShadow(
                    color: brandColor.withValues(alpha: 0.34),
                    blurRadius: 18,
                    spreadRadius: 0.8,
                    offset: const Offset(0, 5),
                  ),
                ],
              ),
              child: SizedBox(
                width: 40,
                height: 40,
                child: Icon(brandIcon, color: Colors.white, size: 22),
              ),
            ),
            const SizedBox(height: 14),
            Expanded(
              child: ListView.separated(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 8,
                ),
                itemCount: destinations.length,
                itemBuilder: (context, index) {
                  final destination = destinations[index];
                  final foreground = destination.isActive
                      ? colorScheme.primary
                      : colorScheme.onSurface.withValues(alpha: 0.66);
                  final background = destination.isActive
                      ? colorScheme.primary.withValues(alpha: 0.2)
                      : Colors.transparent;
                  return Tooltip(
                    message: destination.tooltip,
                    child: Material(
                      color: Colors.transparent,
                      child: InkWell(
                        borderRadius: BorderRadius.circular(12),
                        onTap: destination.onTap,
                        child: Ink(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            color: background,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: destination.isActive
                                  ? colorScheme.primary.withValues(alpha: 0.42)
                                  : Colors.white.withValues(alpha: 0.06),
                            ),
                          ),
                          child: Icon(
                            destination.icon,
                            color: foreground,
                            size: 20,
                          ),
                        ),
                      ),
                    ),
                  );
                },
                separatorBuilder: (_, _) => const SizedBox(height: 10),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
