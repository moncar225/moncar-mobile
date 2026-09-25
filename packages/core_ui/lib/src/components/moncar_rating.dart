import 'package:flutter/material.dart';

import '../theme/moncar_colors.dart';

/// Note de rating MON CAR (Design System) — étoile orange + valeur + count.
class MoncarRating extends StatelessWidget {
  const MoncarRating({
    super.key,
    required this.value,
    this.count,
    this.fontSize = 12,
  });

  final double value;
  final int? count;
  final double fontSize;

  @override
  Widget build(BuildContext context) {
    // Un seul Text.rich (étoile en WidgetSpan) : se tronque proprement dans
    // un espace étroit et garde sa taille naturelle sinon (ex. FittedBox).
    return Text.rich(
      TextSpan(
        children: [
          WidgetSpan(
            alignment: PlaceholderAlignment.middle,
            child: Padding(
              padding: EdgeInsets.only(right: 2),
              child: Icon(
                Icons.star_rounded,
                size: 14,
                color: MoncarColors.accent,
              ),
            ),
          ),
          TextSpan(
            text: value.toStringAsFixed(1),
            style: TextStyle(
              fontWeight: FontWeight.w600,
              color: MoncarColors.ink,
            ),
          ),
          if (count != null)
            TextSpan(
              text: ' ($count)',
              style: TextStyle(color: MoncarColors.inkFaint),
            ),
        ],
      ),
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: TextStyle(fontSize: fontSize),
    );
  }
}
