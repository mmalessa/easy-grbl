import 'package:flutter/material.dart';

/// A small square icon button used for +/- steppers: filled with a tint of
/// [color] while enabled (i.e. [onTap] is non-null), falls back to a
/// neutral surface with an [ColorScheme.onSurfaceVariant] icon when
/// [onTap] is null.
class IconStepperButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback? onTap;
  final Color color;
  final double width;
  final double height;
  final double iconSize;
  final double activeAlpha;

  const IconStepperButton({
    super.key,
    required this.icon,
    required this.onTap,
    required this.color,
    this.width = 28,
    this.height = 26,
    this.iconSize = 13,
    this.activeAlpha = 0.12,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final enabled = onTap != null;
    return SizedBox(
      width: width,
      height: height,
      child: Material(
        color: enabled
            ? color.withValues(alpha: activeAlpha)
            : cs.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(4),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(4),
          child: Icon(icon,
              size: iconSize, color: enabled ? color : cs.onSurfaceVariant),
        ),
      ),
    );
  }
}
