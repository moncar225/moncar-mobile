import 'package:flutter/material.dart';

import '../theme/moncar_colors.dart';
import '../theme/moncar_radius.dart';

/// Carte MON CAR (Design System) — équivalent du `MCCard` web :
/// surface blanche, rayon 20, ombre douce teintée navy.
class MoncarCard extends StatelessWidget {
  const MoncarCard({
    super.key,
    required this.child,
    this.onTap,
    this.padding = const EdgeInsets.all(16),
    this.margin = EdgeInsets.zero,
    this.color,
  });

  final Widget child;
  final VoidCallback? onTap;
  final EdgeInsetsGeometry padding;
  final EdgeInsetsGeometry margin;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final body = Container(
      margin: margin,
      padding: padding,
      decoration: BoxDecoration(
        color: color ?? MoncarColors.surface,
        borderRadius: MoncarRadius.cardRadius,
        border: Border.all(color: MoncarColors.hairline.withValues(alpha: 0.7)),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF002060).withValues(alpha: 0.14),
            blurRadius: 14,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: child,
    );
    if (onTap == null) return body;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: MoncarRadius.cardRadius,
        child: body,
      ),
    );
  }
}
