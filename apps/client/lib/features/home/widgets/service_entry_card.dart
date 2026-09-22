import 'package:flutter/material.dart';
import 'package:core_ui/core_ui.dart';

/// Carte d'entrée de service sur l'accueil (Voyager / Colis / Location).
class ServiceEntryCard extends StatelessWidget {
  const ServiceEntryCard({
    super.key,
    required this.icon,
    required this.title,
    required this.subtitle,
    this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;

  /// Null = fonctionnalité pas encore disponible (carte désactivée).
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final enabled = onTap != null;
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: MoncarRadius.lg,
        side: const BorderSide(color: MoncarColors.border),
      ),
      child: ListTile(
        enabled: enabled,
        onTap: onTap,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: MoncarSpacing.md,
          vertical: MoncarSpacing.sm,
        ),
        leading: CircleAvatar(
          radius: 24,
          backgroundColor: enabled
              ? theme.colorScheme.primary.withValues(alpha: 0.12)
              : theme.disabledColor.withValues(alpha: 0.2),
          child: Icon(
            icon,
            color: enabled ? theme.colorScheme.primary : theme.disabledColor,
          ),
        ),
        title: Text(title, style: theme.textTheme.titleMedium),
        subtitle: Text(
          subtitle,
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        trailing: const Icon(Icons.chevron_right),
      ),
    );
  }
}
