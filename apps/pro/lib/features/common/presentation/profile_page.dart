import 'package:core_ui/core_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/application/app_providers.dart';
import '../../../core/application/business_controller.dart';
import '../../../core/application/session_controller.dart';
import '../../../core/application/sync_controller.dart';
import '../../../core/application/trip_controller.dart';
import '../../../core/domain/models.dart';
import '../../../core/ui/pro_kit.dart';
import '../../../core/ui/role_style.dart';

class ProfilePage extends ConsumerWidget {
  const ProfilePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final session = ref.watch(sessionProvider);
    final user = session.user;
    final role = session.activeRole;
    if (user == null || role == null) return const SizedBox.shrink();
    final settings = ref.watch(settingsProvider);
    final net = ref.watch(networkProvider);
    final pending = ref.watch(syncProvider.select((s) => s.pendingCount));

    Future<void> logout() async {
      final ok = await confirmAction(
        context,
        title: 'Se déconnecter ?',
        message: pending > 0
            ? '$pending action(s) ne sont pas encore synchronisées. Elles restent '
                  'sur ce téléphone et partiront à la prochaine connexion.'
            : 'Les données sensibles de la session sont effacées de ce téléphone.',
        confirmLabel: 'Se déconnecter',
        icon: Icons.logout_rounded,
        color: MoncarColors.danger,
      );
      if (ok) ref.read(sessionProvider.notifier).signOut();
    }

    return ProPage(
      title: 'Profil',
      children: [
        HeroCard(
          colors: role.gradient,
          child: Row(
            children: [
              Container(
                width: 64,
                height: 64,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.18),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  user.initials,
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      user.name,
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    Text(
                      user.phone,
                      style: const TextStyle(color: Colors.white70),
                    ),
                    const SizedBox(height: 8),
                    GlassPill(label: role.label, icon: role.icon),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        MoncarCard(
          child: Column(
            children: [
              DetailRow(
                label: 'Compagnie',
                value: user.company,
                icon: Icons.business_rounded,
              ),
              DetailRow(
                label: 'Gare',
                value: user.station,
                icon: Icons.place_rounded,
              ),
              DetailRow(
                label: 'Identifiant',
                value: user.id,
                icon: Icons.badge_rounded,
              ),
            ],
          ),
        ),
        if (user.roles.length > 1) ...[
          const SizedBox(height: 12),
          _Tile(
            icon: Icons.swap_horiz_rounded,
            color: role.accent,
            title: 'Changer de poste',
            subtitle: '${user.roles.length} profils ouverts sur votre compte',
            onTap: () => ref.read(sessionProvider.notifier).clearRole(),
          ),
        ],
        const SectionTitle('Terrain'),
        _Tile(
          icon: Icons.sync_rounded,
          color: MoncarColors.info,
          title: 'Synchronisation',
          subtitle: pending > 0
              ? '$pending action(s) en attente'
              : 'Tout est à jour',
          onTap: () => context.push('/sync'),
        ),
        const SizedBox(height: 8),
        MoncarCard(
          padding: const EdgeInsets.fromLTRB(16, 4, 8, 4),
          child: Column(
            children: [
              Material(
                type: MaterialType.transparency,
                child: SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  value: net.forcedOffline,
                  onChanged: (v) =>
                      ref.read(networkProvider.notifier).setForcedOffline(v),
                  title: const Text(
                    'Mode hors ligne',
                    style: TextStyle(fontWeight: FontWeight.w700),
                  ),
                  subtitle: const Text(
                    'Essai terrain : simule l’absence de réseau',
                  ),
                ),
              ),
              if (role == ProRole.chauffeur) ...[
                const Divider(height: 1),
                Material(
                  type: MaterialType.transparency,
                  child: SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    value: settings.voiceAlerts,
                    onChanged: (v) =>
                        ref.read(settingsProvider.notifier).setVoiceAlerts(v),
                    title: const Text(
                      'Alertes vocales',
                      style: TextStyle(fontWeight: FontWeight.w700),
                    ),
                    subtitle: const Text(
                      '« Arrêt à 1 km », arrivée à l’arrêt…',
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
        const SectionTitle('Affichage'),
        MoncarCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Thème',
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                  color: MoncarColors.ink,
                ),
              ),
              const SizedBox(height: 10),
              SizedBox(
                width: double.infinity,
                child: SegmentedButton<ThemeChoice>(
                  segments: [
                    for (final c in ThemeChoice.values)
                      ButtonSegment(
                        value: c,
                        label: Text(c.label),
                        icon: Icon(switch (c) {
                          ThemeChoice.systeme => Icons.brightness_auto_rounded,
                          ThemeChoice.clair => Icons.light_mode_rounded,
                          ThemeChoice.sombre => Icons.dark_mode_rounded,
                        }),
                      ),
                  ],
                  selected: {settings.theme},
                  onSelectionChanged: (v) =>
                      ref.read(settingsProvider.notifier).setTheme(v.first),
                ),
              ),
            ],
          ),
        ),
        const SectionTitle('Assistance'),
        _Tile(
          icon: Icons.help_rounded,
          color: MoncarColors.brand,
          title: 'Aide & support',
          subtitle: 'Guide du poste, contacts',
          onTap: () => context.push('/help'),
        ),
        if (kDemoMode) ...[
          const SizedBox(height: 8),
          _Tile(
            icon: Icons.restart_alt_rounded,
            color: MoncarColors.accent,
            title: 'Réinitialiser la démonstration',
            subtitle: 'Voyage, missions et scans remis à zéro',
            onTap: () {
              ref.invalidate(tripProvider);
              ref.invalidate(businessProvider);
              showProToast(
                context,
                'Démonstration réinitialisée.',
                tone: ToastTone.success,
              );
            },
          ),
        ],
        const SizedBox(height: 20),
        BigActionButton(
          label: 'Se déconnecter',
          icon: Icons.logout_rounded,
          color: MoncarColors.danger,
          height: 54,
          onPressed: logout,
        ),
        const SizedBox(height: 16),
        Center(
          child: Text(
            'MON CAR PRO v1.0.0 · PROSOFT ACADEMY',
            style: TextStyle(fontSize: 12, color: MoncarColors.inkFaint),
          ),
        ),
      ],
    );
  }
}

class _Tile extends StatelessWidget {
  const _Tile({
    required this.icon,
    required this.color,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final Color color;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return MoncarCard(
      onTap: onTap,
      padding: const EdgeInsets.all(12),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: color),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontWeight: FontWeight.w800,
                    color: MoncarColors.ink,
                  ),
                ),
                Text(
                  subtitle,
                  style: TextStyle(fontSize: 12.5, color: MoncarColors.inkMut),
                ),
              ],
            ),
          ),
          Icon(Icons.chevron_right_rounded, color: MoncarColors.inkFaint),
        ],
      ),
    );
  }
}
