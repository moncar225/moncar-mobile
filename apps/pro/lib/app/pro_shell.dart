import 'package:core_ui/core_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../core/application/app_providers.dart';
import '../core/application/gps_controller.dart';
import '../core/application/notifications_controller.dart';
import '../core/application/session_controller.dart';
import '../core/application/sync_controller.dart';
import '../core/domain/models.dart';
import '../core/ui/pro_kit.dart';
import '../core/ui/role_style.dart';

/// Onglet de la barre de navigation.
class NavTab {
  const NavTab(this.path, this.label, this.icon, {this.primary = false});

  final String path;
  final String label;
  final IconData icon;

  /// Action principale du profil, mise en avant au centre.
  final bool primary;
}

/// Menus par profil (repris des « Navigation et écrans » du CDC PRO).
List<NavTab> tabsFor(ProRole role) => switch (role) {
  ProRole.controleur => const [
    NavTab('/home', 'Accueil', Icons.space_dashboard_rounded),
    NavTab('/ctrl/historique', 'Historique', Icons.history_rounded),
    NavTab(
      '/ctrl/scan',
      'Scanner',
      Icons.qr_code_scanner_rounded,
      primary: true,
    ),
    NavTab('/voyage', 'Voyage', Icons.directions_bus_rounded),
    NavTab('/profile', 'Profil', Icons.person_rounded),
  ],
  ProRole.convoyeur => const [
    NavTab('/home', 'Accueil', Icons.space_dashboard_rounded),
    NavTab('/voyage', 'Voyage', Icons.directions_bus_rounded),
    NavTab('/manifeste', 'Manifeste', Icons.fact_check_rounded, primary: true),
    NavTab('/alertes', 'Alertes', Icons.notifications_rounded),
    NavTab('/profile', 'Profil', Icons.person_rounded),
  ],
  ProRole.chauffeur => const [
    NavTab('/home', 'Accueil', Icons.space_dashboard_rounded),
    NavTab('/chauf/itineraire', 'Itinéraire', Icons.map_rounded),
    NavTab('/chauf/actif', 'Conduite', Icons.navigation_rounded, primary: true),
    NavTab('/alertes', 'Alertes', Icons.notifications_rounded),
    NavTab('/profile', 'Profil', Icons.person_rounded),
  ],
  ProRole.agentBusiness => const [
    NavTab('/home', 'Accueil', Icons.space_dashboard_rounded),
    NavTab('/incidents', 'Incidents', Icons.report_rounded),
    NavTab(
      '/biz/missions',
      'Missions',
      Icons.car_rental_rounded,
      primary: true,
    ),
    NavTab('/alertes', 'Alertes', Icons.notifications_rounded),
    NavTab('/profile', 'Profil', Icons.person_rounded),
  ],
};

/// Coquille des écrans connectés : bandeau hors ligne + barre de
/// navigation (uniquement sur les écrans racines du profil).
class ProShell extends ConsumerWidget {
  const ProShell({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final role = ref.watch(activeRoleProvider);
    final online = ref.watch(networkProvider.select((n) => n.online));
    final pending = ref.watch(syncProvider.select((s) => s.pendingCount));
    // Le suivi GPS reste actif tant que le chauffeur est connecté.
    if (role == ProRole.chauffeur) ref.watch(gpsProvider);

    final location = GoRouterState.of(context).uri.path;
    final tabs = role == null ? const <NavTab>[] : tabsFor(role);
    final showNav = tabs.any((t) => t.path == location);

    return Scaffold(
      backgroundColor: MoncarColors.background,
      body: Column(
        children: [
          if (!online) _OfflineBanner(pending: pending),
          Expanded(child: child),
        ],
      ),
      bottomNavigationBar: showNav && role != null
          ? _ProBottomNav(tabs: tabs, location: location, role: role)
          : null,
    );
  }
}

class _OfflineBanner extends StatelessWidget {
  const _OfflineBanner({required this.pending});

  final int pending;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: const Color(0xFF16213E),
      child: SafeArea(
        bottom: false,
        child: InkWell(
          onTap: () => context.push('/sync'),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              children: [
                const Icon(
                  Icons.cloud_off_rounded,
                  color: Color(0xFFF0B455),
                  size: 18,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    pending > 0
                        ? 'Mode hors ligne · $pending action${pending > 1 ? 's' : ''} en attente'
                        : 'Mode hors ligne · vos actions sont enregistrées',
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                      fontSize: 13,
                    ),
                  ),
                ),
                const Icon(Icons.chevron_right_rounded, color: Colors.white70),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ProBottomNav extends ConsumerWidget {
  const _ProBottomNav({
    required this.tabs,
    required this.location,
    required this.role,
  });

  final List<NavTab> tabs;
  final String location;
  final ProRole role;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final unread = ref.watch(unreadCountProvider);
    final accent = role.accent;
    return Container(
      decoration: BoxDecoration(
        color: MoncarColors.surface,
        border: Border(top: BorderSide(color: MoncarColors.hairline)),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF002060).withValues(alpha: 0.10),
            blurRadius: 20,
            offset: const Offset(0, -6),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: 68,
          child: Row(
            children: [
              for (final t in tabs)
                Expanded(
                  child: t.primary
                      ? _PrimaryTab(tab: t, color: accent)
                      : _Tab(
                          tab: t,
                          active: location == t.path,
                          color: accent,
                          badge: t.path == '/alertes' ? unread : 0,
                        ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

void _open(BuildContext context, NavTab t) {
  haptic(HapticKind.tap);
  // Le scan est un écran immersif empilé ; les autres onglets remplacent.
  if (t.path == '/ctrl/scan') {
    context.push(t.path);
  } else {
    context.go(t.path);
  }
}

class _Tab extends StatelessWidget {
  const _Tab({
    required this.tab,
    required this.active,
    required this.color,
    required this.badge,
  });

  final NavTab tab;
  final bool active;
  final Color color;
  final int badge;

  @override
  Widget build(BuildContext context) {
    final c = active ? color : MoncarColors.inkFaint;
    return InkWell(
      onTap: () => _open(context, tab),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
            decoration: BoxDecoration(
              color: active
                  ? color.withValues(alpha: 0.12)
                  : Colors.transparent,
              borderRadius: BorderRadius.circular(99),
            ),
            child: Badge(
              isLabelVisible: badge > 0,
              label: Text('$badge'),
              backgroundColor: MoncarColors.danger,
              child: Icon(tab.icon, size: 23, color: c),
            ),
          ),
          const SizedBox(height: 3),
          Text(
            tab.label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 11,
              fontWeight: active ? FontWeight.w800 : FontWeight.w600,
              color: c,
            ),
          ),
        ],
      ),
    );
  }
}

class _PrimaryTab extends StatelessWidget {
  const _PrimaryTab({required this.tab, required this.color});

  final NavTab tab;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () => _open(context, tab),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 50,
            height: 38,
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(14),
              boxShadow: [
                BoxShadow(
                  color: color.withValues(alpha: 0.4),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Icon(tab.icon, color: Colors.white, size: 24),
          ),
          const SizedBox(height: 3),
          Text(
            tab.label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w800,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}
