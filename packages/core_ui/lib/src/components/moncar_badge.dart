import 'package:flutter/material.dart';

import '../theme/moncar_colors.dart';

/// Tonalité d'un badge MON CAR.
enum MoncarBadgeTone { brand, accent, success, danger, warn, neutral }

/// Taille d'un badge MON CAR.
enum MoncarBadgeSize {
  sm(10.0, EdgeInsets.symmetric(horizontal: 8, vertical: 2)),
  md(11.0, EdgeInsets.symmetric(horizontal: 10, vertical: 4)),
  lg(12.0, EdgeInsets.symmetric(horizontal: 12, vertical: 6));

  const MoncarBadgeSize(this.fontSize, this.padding);
  final double fontSize;
  final EdgeInsets padding;
}

/// Badge MON CAR (Design System) — équivalent du `MCBadge` web.
class MoncarBadge extends StatelessWidget {
  const MoncarBadge({
    super.key,
    required this.label,
    this.tone = MoncarBadgeTone.brand,
    this.size = MoncarBadgeSize.md,
    this.icon,
    this.backgroundColor,
    this.textColor,
  });

  final String label;
  final MoncarBadgeTone tone;
  final MoncarBadgeSize size;
  final IconData? icon;

  /// Surcharge explicite des couleurs (ex. badge blanc translucide sur fond coloré).
  final Color? backgroundColor;
  final Color? textColor;

  @override
  Widget build(BuildContext context) {
    final (bg, fg) = switch (tone) {
      MoncarBadgeTone.brand => (MoncarColors.brandSoft, MoncarColors.brand),
      MoncarBadgeTone.accent => (
        MoncarColors.accentSoft,
        MoncarColors.accentInk,
      ),
      MoncarBadgeTone.success => (
        MoncarColors.successSoft,
        MoncarColors.success,
      ),
      MoncarBadgeTone.danger => (MoncarColors.dangerSoft, MoncarColors.danger),
      MoncarBadgeTone.warn => (MoncarColors.warnSoft, MoncarColors.warn),
      MoncarBadgeTone.neutral => (MoncarColors.muted, MoncarColors.inkMut),
    };

    return Container(
      padding: size.padding,
      decoration: BoxDecoration(
        color: backgroundColor ?? bg,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: size.fontSize + 2, color: textColor ?? fg),
            const SizedBox(width: 4),
          ],
          Text(
            label,
            style: TextStyle(
              fontSize: size.fontSize,
              fontWeight: FontWeight.w600,
              color: textColor ?? fg,
            ),
          ),
        ],
      ),
    );
  }
}
