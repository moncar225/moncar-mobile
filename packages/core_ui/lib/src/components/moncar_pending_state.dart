import 'package:flutter/material.dart';

import '../theme/moncar_colors.dart';

/// État « en cours » MON CAR (Design System) — équivalent du `MCPending` web :
/// spinner accent, titre, message et compte à rebours optionnel (paiement).
class MoncarPendingState extends StatelessWidget {
  const MoncarPendingState({
    super.key,
    this.title = 'En cours…',
    this.message,
    this.countdown,
  });

  final String title;
  final String? message;

  /// Secondes restantes affichées sous forme m:ss (paiement en attente).
  final int? countdown;

  @override
  Widget build(BuildContext context) {
    final countdown = this.countdown;
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 48),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: 48,
              height: 48,
              child: CircularProgressIndicator(
                strokeWidth: 3,
                color: MoncarColors.accent,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              title,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: MoncarColors.ink,
              ),
            ),
            if (message != null) ...[
              const SizedBox(height: 4),
              Text(
                message!,
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 13, color: MoncarColors.inkMut),
              ),
            ],
            if (countdown != null && countdown > 0) ...[
              const SizedBox(height: 8),
              Text(
                '${countdown ~/ 60}:${(countdown % 60).toString().padLeft(2, '0')}',
                style: TextStyle(
                  fontSize: 12,
                  color: MoncarColors.inkFaint,
                  fontFamily: 'monospace',
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
