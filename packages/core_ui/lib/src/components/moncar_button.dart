import 'package:flutter/material.dart';

/// Bouton principal MON CAR (Design System).
///
/// Un seul bouton dans tout le Design System : variante remplie par défaut,
/// variante secondaire (contour) via [MoncarButton.secondary].
class MoncarButton extends StatelessWidget {
  const MoncarButton({
    super.key,
    required this.label,
    this.onPressed,
    this.secondary = false,
    this.danger = false,
    this.isLoading = false,
    this.icon,
  }) : assert(!(secondary && danger), 'Un bouton ne peut pas être à la fois secondaire et danger.');

  final String label;
  final VoidCallback? onPressed;
  final bool secondary;
  final bool danger;
  final bool isLoading;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final enabled = onPressed != null && !isLoading;
    final style = secondary
        ? OutlinedButton.styleFrom(
            foregroundColor: danger ? Theme.of(context).colorScheme.error : null,
            side: BorderSide(
              color: enabled
                  ? (danger ? Theme.of(context).colorScheme.error : Theme.of(context).colorScheme.primary)
                  : Theme.of(context).disabledColor,
            ),
          )
        : FilledButton.styleFrom(
            backgroundColor: danger ? Theme.of(context).colorScheme.error : null,
          );

    final child = isLoading
        ? const SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
          )
        : (icon != null
            ? Row(
                mainAxisSize: MainAxisSize.min,
                children: [Icon(icon, size: 20), const SizedBox(width: 8), Text(label)],
              )
            : Text(label));

    return secondary
        ? OutlinedButton(onPressed: enabled ? onPressed : null, style: style, child: child)
        : FilledButton(onPressed: enabled ? onPressed : null, style: style, child: child);
  }
}
