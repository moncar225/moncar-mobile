import 'package:flutter/material.dart';

import '../theme/moncar_colors.dart';

/// En-tête de section MON CAR (Design System) — équivalent du
/// `MCSectionHeader` web : titre + action facultative « Voir tout → ».
class MoncarSectionHeader extends StatelessWidget {
  const MoncarSectionHeader({
    super.key,
    required this.title,
    this.action,
    this.onAction,
  }) : assert(
         (action == null) == (onAction == null),
         'action et onAction doivent être fournis ensemble.',
       );

  final String title;
  final String? action;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12, left: 4, right: 4),
      child: Row(
        children: [
          Expanded(
            child: Text(
              title,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: MoncarColors.ink,
              ),
            ),
          ),
          if (action != null)
            GestureDetector(
              onTap: onAction,
              child: Text(
                '$action →',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: MoncarColors.accent,
                ),
              ),
            ),
        ],
      ),
    );
  }
}
