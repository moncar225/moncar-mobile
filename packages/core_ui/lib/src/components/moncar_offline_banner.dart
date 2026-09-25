import 'package:flutter/material.dart';

import '../theme/moncar_colors.dart';

/// Bannière hors ligne MON CAR (Design System) — équivalent du
/// `MCOfflineBanner` web. À afficher en haut du shell quand l'app
/// détecte une perte de connectivité.
class MoncarOfflineBanner extends StatelessWidget {
  const MoncarOfflineBanner({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      color: MoncarColors.warnSoft,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(
        children: [
          Icon(Icons.cloud_off, size: 16, color: MoncarColors.warn),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'Hors ligne — certaines données peuvent être obsolètes. '
              'Synchronisation en attente.',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: MoncarColors.warn.withValues(alpha: 0.9),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
