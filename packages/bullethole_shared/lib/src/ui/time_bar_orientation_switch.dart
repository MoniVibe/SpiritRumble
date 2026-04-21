import 'package:flutter/material.dart';

import 'cooldown_meter.dart';

/// Shared switch to keep time-bar orientation controls consistent across games.
class TimeBarOrientationSwitch extends StatelessWidget {
  const TimeBarOrientationSwitch({
    required this.orientation,
    required this.onChanged,
    this.enabled = true,
    this.title = 'Vertical Time Bars',
    this.verticalHint = 'Bars appear on left/right of the board',
    this.horizontalHint = 'Bars appear above/below the board',
    super.key,
  });

  final TimeBarOrientation orientation;
  final ValueChanged<TimeBarOrientation> onChanged;
  final bool enabled;
  final String title;
  final String verticalHint;
  final String horizontalHint;

  @override
  Widget build(BuildContext context) {
    final isVertical = orientation == TimeBarOrientation.vertical;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface.withValues(alpha: 0.56),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Theme.of(
            context,
          ).colorScheme.outlineVariant.withValues(alpha: 0.66),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(10, 8, 10, 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              title,
              style: Theme.of(
                context,
              ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 6),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: SegmentedButton<TimeBarOrientation>(
                showSelectedIcon: false,
                segments: const <ButtonSegment<TimeBarOrientation>>[
                  ButtonSegment<TimeBarOrientation>(
                    value: TimeBarOrientation.horizontal,
                    icon: Icon(Icons.swap_vert_rounded, size: 16),
                    label: Text('Horizontal'),
                  ),
                  ButtonSegment<TimeBarOrientation>(
                    value: TimeBarOrientation.vertical,
                    icon: Icon(Icons.swap_horiz_rounded, size: 16),
                    label: Text('Vertical'),
                  ),
                ],
                selected: <TimeBarOrientation>{orientation},
                onSelectionChanged: enabled
                    ? (selection) => onChanged(selection.first)
                    : null,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              isVertical ? verticalHint : horizontalHint,
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
      ),
    );
  }
}
