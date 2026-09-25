import 'package:flutter/material.dart';

/// État d'erreur MON CAR (Design System).
///
/// [message] doit être un libellé compréhensible en français (voir
/// `core_api` pour les messages standards par code HTTP).
class MoncarErrorState extends StatelessWidget {
  const MoncarErrorState({
    super.key,
    required this.message,
    this.title = 'Une erreur est survenue',
    this.onRetry,
    this.incidentId,
  });

  final String title;
  final String message;

  /// Relance le chargement des données.
  final VoidCallback? onRetry;

  /// Référence d'incident serveur, si fournie par l'API (erreur 500).
  final String? incidentId;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.error_outline, size: 48, color: theme.colorScheme.error),
            const SizedBox(height: 16),
            Text(
              title,
              style: theme.textTheme.titleMedium,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              message,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
              textAlign: TextAlign.center,
            ),
            if (incidentId != null) ...[
              const SizedBox(height: 8),
              Text(
                'Référence incident : $incidentId',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
                textAlign: TextAlign.center,
              ),
            ],
            if (onRetry != null) ...[
              const SizedBox(height: 16),
              FilledButton(onPressed: onRetry, child: const Text('Réessayer')),
            ],
          ],
        ),
      ),
    );
  }
}
