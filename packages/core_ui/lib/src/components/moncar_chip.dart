import 'package:flutter/material.dart';

import '../theme/moncar_colors.dart';

/// Puce cliquable MON CAR (Design System) — équivalent du `MCChip` web.
/// Utilisée pour les filtres, villes populaires, tri…
class MoncarChip extends StatelessWidget {
  const MoncarChip({
    super.key,
    required this.label,
    this.onTap,
    this.active = false,
    this.icon,
  });

  final String label;
  final VoidCallback? onTap;
  final bool active;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final fg = active ? Colors.white : MoncarColors.inkMut;
    return Material(
      color: active ? MoncarColors.brand : MoncarColors.surface,
      shape: StadiumBorder(
        side: BorderSide(
          color: active ? MoncarColors.brand : MoncarColors.hairline,
        ),
      ),
      child: InkWell(
        onTap: onTap,
        customBorder: const StadiumBorder(),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (icon != null) ...[
                Icon(icon, size: 14, color: fg),
                const SizedBox(width: 6),
              ],
              Text(
                label,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: fg,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
