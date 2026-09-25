import 'package:flutter/material.dart';

import '../theme/moncar_colors.dart';
import 'moncar_button.dart';

/// État de succès MON CAR (Design System) — équivalent du `MCSuccess` web :
/// coche verte animée, titre, description, action principale + secondaire.
class MoncarSuccessState extends StatelessWidget {
  const MoncarSuccessState({
    super.key,
    required this.title,
    this.message,
    this.actionLabel,
    this.onAction,
    this.secondaryLabel,
    this.onSecondary,
  });

  final String title;
  final String? message;
  final String? actionLabel;
  final VoidCallback? onAction;
  final String? secondaryLabel;
  final VoidCallback? onSecondary;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 48),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Stack(
              alignment: Alignment.center,
              children: [
                Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: MoncarColors.successSoft,
                  ),
                  child: Icon(
                    Icons.check_circle_outline,
                    size: 44,
                    color: MoncarColors.success,
                  ),
                ),
                // Halo pulsé (statique en Flutter, subtil).
                Container(
                  width: 96,
                  height: 96,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: MoncarColors.success.withValues(alpha: 0.3),
                      width: 2,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Text(
              title,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 18,
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
            if (actionLabel != null) ...[
              const SizedBox(height: 20),
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 320),
                child: MoncarButton(
                  label: actionLabel!,
                  onPressed: onAction,
                  variant: MoncarButtonVariant.primary,
                  size: MoncarButtonSize.lg,
                  expand: true,
                ),
              ),
            ],
            if (secondaryLabel != null) ...[
              const SizedBox(height: 12),
              TextButton(
                onPressed: onSecondary,
                child: Text(
                  secondaryLabel!,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: MoncarColors.brand,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
