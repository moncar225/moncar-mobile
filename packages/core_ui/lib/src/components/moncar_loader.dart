import 'package:flutter/material.dart';

/// Indicateur de chargement MON CAR (Design System).
///
/// À utiliser pour tout état loading plein écran ou intégrés dans une liste.
class MoncarLoader extends StatelessWidget {
  const MoncarLoader({super.key, this.label, this.fullScreen = false});

  /// Libellé optionnel sous l'indicateur (ex. « Chargement des voyages… »).
  final String? label;

  /// Centre le loader sur tout l'écran.
  final bool fullScreen;

  @override
  Widget build(BuildContext context) {
    final content = Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const CircularProgressIndicator(),
        if (label != null) ...[
          const SizedBox(height: 16),
          Text(
            label!,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ],
    );

    if (fullScreen) {
      return Center(child: content);
    }
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Center(child: content),
    );
  }
}
