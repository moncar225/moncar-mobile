import 'package:core_ui/core_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/application/business_controller.dart';
import '../../../core/application/gps_controller.dart';
import '../../../core/application/notifications_controller.dart';
import '../../../core/application/session_controller.dart';
import '../../../core/application/sync_controller.dart';
import '../../../core/application/trip_controller.dart';
import '../../../core/domain/models.dart';
import '../../../core/ui/format.dart';
import '../../../core/ui/pro_kit.dart';
import '../../../core/ui/role_style.dart';
import '../../../core/ui/status_widgets.dart';
import '../../../core/ui/trip_widgets.dart';

/// Tableau de bord adaptatif : répond à « que dois-je faire maintenant ? »
/// (KPI par poste repris du CDC MON CAR PRO).
class DashboardPage extends ConsumerWidget {
  const DashboardPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final session = ref.watch(sessionProvider);
    final user = session.user;
    final role = session.activeRole;
    if (user == null || role == null) return const SizedBox.shrink();

    return SafeArea(
      bottom: false,
      child: RefreshIndicator(
        color: role.accent,
        onRefresh: () async {
          ref.read(tripProvider.notifier).refreshManifest();
          await ref.read(syncProvider.notifier).flush();
        },
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 28),
          children: [
            _Header(user: user, role: role),
            const SizedBox(height: 18),
            ...switch (role) {
              ProRole.controleur => _controleur(context, ref, role),
              ProRole.convoyeur => _convoyeur(context, ref, role),
              ProRole.chauffeur => _chauffeur(context, ref, role),
              ProRole.agentBusiness => _business(context, ref, role),
            },
            _AlertsSection(role: role),
          ],
        ),
      ),
    );
  }

  // ----------------------------- Contrôleur -----------------------------

  List<Widget> _controleur(BuildContext context, WidgetRef ref, ProRole role) {
    final t = ref.watch(tripProvider);
    final checkedBags = t.bags.where((b) => b.checked).length;
    return [
      TripHeroCard(
        trip: t,
        colors: role.gradient,
        onTap: () => context.go('/voyage'),
      ),
      const SizedBox(height: 14),
      BigActionButton(
        label: 'Scanner un billet',
        icon: Icons.qr_code_scanner_rounded,
        color: role.accent,
        onPressed: () => context.push('/ctrl/scan'),
      ),
      const SizedBox(height: 10),
      _ManifestBanner(trip: t),
      const SectionTitle('Embarquement'),
      TwoColumnGrid(
        children: [
          KpiTile(
            label: 'Passagers prévus',
            value: '${t.expected}',
            icon: Icons.groups_rounded,
            color: MoncarColors.brand,
            onTap: () => context.push('/manifeste'),
          ),
          KpiTile(
            label: 'Scannés',
            value: '${t.controlled}',
            caption:
                '${(t.expected == 0 ? 0 : t.controlled * 100 / t.expected).round()} % du voyage',
            icon: Icons.verified_rounded,
            color: MoncarColors.success,
          ),
          KpiTile(
            label: 'Non scannés',
            value: '${t.notControlled}',
            icon: Icons.pending_actions_rounded,
            color: MoncarColors.warn,
            onTap: () => context.push('/manifeste'),
          ),
          KpiTile(
            label: 'Refusés',
            value: '${t.refused}',
            icon: Icons.block_rounded,
            color: MoncarColors.danger,
            onTap: () => context.go('/ctrl/historique'),
          ),
          KpiTile(
            label: 'Bagages contrôlés',
            value: '$checkedBags/${t.bags.length}',
            icon: Icons.luggage_rounded,
            color: MoncarColors.info,
            onTap: () => context.push('/ctrl/bagages'),
          ),
          KpiTile(
            label: 'Colis à bord',
            value: '${t.parcels.length}',
            icon: Icons.inventory_2_rounded,
            color: MoncarColors.accent,
          ),
        ],
      ),
      const SectionTitle('Actions rapides'),
      TwoColumnGrid(
        children: [
          QuickActionTile(
            label: 'Saisie manuelle',
            icon: Icons.keyboard_rounded,
            color: role.accent,
            onTap: () => context.push('/ctrl/manuel'),
          ),
          QuickActionTile(
            label: 'Contrôle bagages',
            icon: Icons.luggage_rounded,
            color: MoncarColors.info,
            onTap: () => context.push('/ctrl/bagages'),
          ),
          QuickActionTile(
            label: 'Manifeste',
            icon: Icons.fact_check_rounded,
            color: MoncarColors.success,
            onTap: () => context.push('/manifeste'),
          ),
          QuickActionTile(
            label: 'Signaler un incident',
            icon: Icons.report_rounded,
            color: MoncarColors.danger,
            onTap: () => context.push('/incidents?nouveau=1'),
          ),
        ],
      ),
    ];
  }

  // ----------------------------- Convoyeur -----------------------------

  List<Widget> _convoyeur(BuildContext context, WidgetRef ref, ProRole role) {
    final t = ref.watch(tripProvider);
    final op = t.operationalStop;
    final drop = op == null ? 0 : t.toDropAt(op.id).length;
    final board = op == null ? 0 : t.toBoardAt(op.id).length;
    final bags = op == null ? 0 : t.bagsToUnloadAt(op.id).length;
    final parcels = op == null ? 0 : t.parcelsToUnloadAt(op.id).length;
    return [
      TripHeroCard(
        trip: t,
        colors: role.gradient,
        onTap: () => context.go('/voyage'),
      ),
      const SizedBox(height: 14),
      BigActionButton(
        label: 'Confirmer les présences',
        icon: Icons.how_to_reg_rounded,
        color: role.accent,
        onPressed: () => context.go('/manifeste'),
      ),
      const SizedBox(height: 10),
      _ManifestBanner(trip: t),
      const SectionTitle('À bord'),
      TwoColumnGrid(
        children: [
          KpiTile(
            label: 'Total prévu',
            value: '${t.expected}',
            icon: Icons.groups_rounded,
            color: MoncarColors.brand,
            onTap: () => context.go('/manifeste'),
          ),
          KpiTile(
            label: 'À bord',
            value: '${t.onBoard}',
            icon: Icons.airline_seat_recline_normal_rounded,
            color: MoncarColors.success,
          ),
          KpiTile(
            label: 'Absents',
            value: '${t.absents}',
            icon: Icons.person_off_rounded,
            color: MoncarColors.warn,
            onTap: () => context.go('/manifeste'),
          ),
          KpiTile(
            label: op == null ? 'Terminus' : 'Arrêt : ${op.shortName}',
            value: op == null ? '—' : fmtTime(etaFor(t.voyage, op)),
            icon: Icons.flag_rounded,
            color: role.accent,
            onTap: () => context.push('/conv/arret'),
          ),
        ],
      ),
      SectionTitle(op == null ? 'Arrêt' : 'À ${op.shortName}'),
      Row(
        children: [
          Expanded(
            child: MiniStat(
              value: '$drop',
              label: 'À descendre',
              color: MoncarColors.warn,
              icon: Icons.south_rounded,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: MiniStat(
              value: '$board',
              label: 'À embarquer',
              color: MoncarColors.info,
              icon: Icons.north_rounded,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: MiniStat(
              value: '$bags',
              label: 'Bagages',
              color: role.accent,
              icon: Icons.luggage_rounded,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: MiniStat(
              value: '$parcels',
              label: 'Colis',
              color: MoncarColors.accent,
              icon: Icons.inventory_2_rounded,
            ),
          ),
        ],
      ),
      const SectionTitle('Actions rapides'),
      TwoColumnGrid(
        children: [
          QuickActionTile(
            label: 'Prochain arrêt',
            icon: Icons.flag_rounded,
            color: role.accent,
            onTap: () => context.push('/conv/arret'),
          ),
          QuickActionTile(
            label: 'Bagages',
            icon: Icons.luggage_rounded,
            color: MoncarColors.info,
            badge: bags > 0 ? '$bags' : null,
            onTap: () => context.push('/conv/bagages'),
          ),
          QuickActionTile(
            label: 'Colis',
            icon: Icons.inventory_2_rounded,
            color: MoncarColors.accent,
            badge: parcels > 0 ? '$parcels' : null,
            onTap: () => context.push('/conv/colis'),
          ),
          QuickActionTile(
            label: 'Signaler un incident',
            icon: Icons.report_rounded,
            color: MoncarColors.danger,
            onTap: () => context.push('/incidents?nouveau=1'),
          ),
        ],
      ),
    ];
  }

  // ----------------------------- Chauffeur -----------------------------

  List<Widget> _chauffeur(BuildContext context, WidgetRef ref, ProRole role) {
    final t = ref.watch(tripProvider);
    final gps = ref.watch(gpsProvider);
    final v = t.voyage;
    final next = v.nextStop;
    final segmentKm = next == null
        ? 0.0
        : next.kmFromOrigin - v.currentStop.kmFromOrigin;
    final doneOnSegment =
        t.phase == DriverPhase.enRoute && gps.distanceToNextKm != null
        ? segmentKm - gps.distanceToNextKm!
        : 0.0;
    final remainingKm = v.totalKm - v.currentStop.kmFromOrigin - doneOnSegment;
    final delay = v.departureActual == null
        ? 0
        : v.departureActual!.difference(v.departurePlanned).inMinutes;
    final openIncidents = t.incidents
        .where((i) => i.status != IncidentStatus.resolu)
        .length;
    return [
      TripHeroCard(
        trip: t,
        colors: role.gradient,
        onTap: () => context.push('/voyage'),
      ),
      const SizedBox(height: 14),
      if (t.phase == DriverPhase.avantDepart)
        SwipeToConfirm(
          label: 'Glisser pour démarrer',
          color: MoncarColors.success,
          icon: Icons.play_arrow_rounded,
          onConfirmed: () async {
            ref.read(tripProvider.notifier).startTrip();
            if (context.mounted) {
              showProToast(
                context,
                'Voyage démarré — heure réelle enregistrée.',
                tone: ToastTone.success,
              );
              context.go('/chauf/actif');
            }
          },
        )
      else
        BigActionButton(
          label: t.phase == DriverPhase.cloture
              ? 'Voyage clôturé'
              : 'Ouvrir la conduite',
          icon: Icons.navigation_rounded,
          color: role.accent,
          onPressed: t.phase == DriverPhase.cloture
              ? null
              : () => context.go('/chauf/actif'),
        ),
      const SectionTitle('Voyage du jour'),
      TwoColumnGrid(
        children: [
          KpiTile(
            label: 'Heure prévue',
            value: fmtTime(v.departurePlanned),
            caption: v.departureActual == null
                ? 'Non démarré'
                : 'Réel ${fmtTime(v.departureActual)}',
            icon: Icons.schedule_rounded,
            color: MoncarColors.brand,
          ),
          KpiTile(
            label: 'ETA destination',
            value: fmtTime(etaFor(v, v.destination)),
            icon: Icons.sports_score_rounded,
            color: MoncarColors.success,
          ),
          KpiTile(
            label: 'Distance restante',
            value: '${remainingKm.clamp(0, v.totalKm).round()} km',
            icon: Icons.straighten_rounded,
            color: role.accent,
            onTap: () => context.go('/chauf/itineraire'),
          ),
          KpiTile(
            label: 'Prochain arrêt',
            value: next?.shortName ?? 'Terminus',
            icon: Icons.flag_rounded,
            color: MoncarColors.info,
          ),
          KpiTile(
            label: 'Retard',
            value: delay > 0 ? '+$delay min' : 'À l’heure',
            icon: Icons.timer_rounded,
            color: delay > 0 ? MoncarColors.warn : MoncarColors.success,
          ),
          KpiTile(
            label: 'Incidents ouverts',
            value: '$openIncidents',
            icon: Icons.report_rounded,
            color: openIncidents > 0
                ? MoncarColors.danger
                : MoncarColors.inkMut,
            onTap: () => context.push('/incidents'),
          ),
        ],
      ),
      const SectionTitle('Actions rapides'),
      TwoColumnGrid(
        children: [
          QuickActionTile(
            label: 'Itinéraire & GPS',
            icon: Icons.map_rounded,
            color: MoncarColors.brand,
            onTap: () => context.go('/chauf/itineraire'),
          ),
          QuickActionTile(
            label: 'Signaler un incident',
            icon: Icons.report_rounded,
            color: MoncarColors.danger,
            onTap: () => context.push('/incidents?nouveau=1'),
          ),
        ],
      ),
    ];
  }

  // ----------------------------- Agent BUSINESS -----------------------------

  List<Widget> _business(BuildContext context, WidgetRef ref, ProRole role) {
    final tasks = ref.watch(businessProvider);
    final todo =
        tasks.where((t) => t.status == RentalTaskStatus.aFaire).toList()
          ..sort((a, b) => a.scheduledAt.compareTo(b.scheduledAt));
    final next = todo.firstOrNull;
    return [
      if (next != null)
        HeroCard(
          colors: role.gradient,
          onTap: () => context.push('/biz/mission/${next.id}'),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text(
                    'PROCHAINE MISSION',
                    style: const TextStyle(
                      fontSize: 12,
                      letterSpacing: 1.2,
                      fontWeight: FontWeight.w800,
                      color: Colors.white70,
                    ),
                  ),
                  const Spacer(),
                  GlassPill(
                    label: next.type.label,
                    icon: next.type == RentalTaskType.remise
                        ? Icons.key_rounded
                        : Icons.assignment_return_rounded,
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                next.vehicleModel,
                style: const TextStyle(
                  fontSize: 21,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                '${next.vehiclePlate} · ${next.ref}',
                style: const TextStyle(color: Colors.white70),
              ),
              const SizedBox(height: 14),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  GlassPill(
                    label: fmtTime(next.scheduledAt),
                    icon: Icons.schedule_rounded,
                  ),
                  GlassPill(label: next.clientName, icon: Icons.person_rounded),
                  if (next.withDriver)
                    const GlassPill(
                      label: 'Avec chauffeur',
                      icon: Icons.badge_rounded,
                    ),
                ],
              ),
            ],
          ),
        )
      else
        const EmptyCard(
          message: 'Aucune mission en attente aujourd’hui.',
          icon: Icons.event_available_rounded,
        ),
      const SizedBox(height: 14),
      BigActionButton(
        label: 'Voir mes missions',
        icon: Icons.car_rental_rounded,
        color: role.accent,
        onPressed: () => context.go('/biz/missions'),
      ),
      const SectionTitle('Aujourd’hui'),
      TwoColumnGrid(
        children: [
          KpiTile(
            label: 'Remises à faire',
            value:
                '${todo.where((t) => t.type == RentalTaskType.remise).length}',
            icon: Icons.key_rounded,
            color: role.accent,
          ),
          KpiTile(
            label: 'Restitutions à faire',
            value:
                '${todo.where((t) => t.type == RentalTaskType.restitution).length}',
            icon: Icons.assignment_return_rounded,
            color: MoncarColors.info,
          ),
          KpiTile(
            label: 'Terminées',
            value: '${tasks.length - todo.length}',
            icon: Icons.task_alt_rounded,
            color: MoncarColors.success,
          ),
          KpiTile(
            label: 'VTC avec chauffeur',
            value: '${tasks.where((t) => t.withDriver).length}',
            icon: Icons.badge_rounded,
            color: MoncarColors.accent,
          ),
        ],
      ),
    ];
  }
}

class _Header extends ConsumerWidget {
  const _Header({required this.user, required this.role});

  final ProUser user;
  final ProRole role;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final unread = ref.watch(unreadCountProvider);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const ProLogo(size: 30),
            const SizedBox(width: 8),
            const ProWordmark(fontSize: 15),
            const Spacer(),
            const SyncPill(),
            const SizedBox(width: 8),
            CircleIconButton(
              icon: Icons.notifications_rounded,
              tooltip: 'Notifications',
              badge: unread,
              onTap: () => context.push('/alertes'),
            ),
          ],
        ),
        const SizedBox(height: 18),
        Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    fmtLongDate(DateTime.now()),
                    style: TextStyle(fontSize: 13, color: MoncarColors.inkMut),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Bonjour, ${user.firstName}',
                    style: TextStyle(
                      fontSize: 26,
                      fontWeight: FontWeight.w900,
                      color: MoncarColors.ink,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      MoncarBadge(
                        label: role.label,
                        icon: role.icon,
                        size: MoncarBadgeSize.sm,
                        backgroundColor: role.soft,
                        textColor: role.accent,
                      ),
                      const SizedBox(width: 6),
                      Flexible(
                        child: Text(
                          user.station,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 13,
                            color: MoncarColors.inkMut,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            GestureDetector(
              onTap: () => context.go('/profile'),
              child: InitialsAvatar(
                initials: user.initials,
                color: role.accent,
                size: 52,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _ManifestBanner extends StatelessWidget {
  const _ManifestBanner({required this.trip});

  final TripState trip;

  @override
  Widget build(BuildContext context) {
    return InfoBanner(
      icon: Icons.offline_pin_rounded,
      color: MoncarColors.success,
      message:
          'Manifeste disponible hors ligne · ${trip.passengers.length} billets '
          'téléchargés ${fmtAgo(trip.manifestAt)}.',
    );
  }
}

class _AlertsSection extends ConsumerWidget {
  const _AlertsSection({required this.role});

  final ProRole role;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final alerts = ref
        .watch(notificationsProvider)
        .where((n) => !n.read && n.category != NotifCategory.information)
        .take(3)
        .toList();
    if (alerts.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SectionTitle(
          'Alertes',
          trailing: TextButton(
            onPressed: () => context.push('/alertes'),
            child: const Text('Tout voir'),
          ),
        ),
        for (final n in alerts) ...[
          MoncarCard(
            padding: const EdgeInsets.all(12),
            onTap: () {
              ref.read(notificationsProvider.notifier).markRead(n.id);
              final r = n.route;
              if (r != null) context.push(r);
            },
            child: Row(
              children: [
                Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: n.category.color.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    n.category.icon,
                    color: n.category.color,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        n.title,
                        style: TextStyle(
                          fontWeight: FontWeight.w800,
                          color: MoncarColors.ink,
                        ),
                      ),
                      Text(
                        n.body,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 12.5,
                          color: MoncarColors.inkMut,
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(Icons.chevron_right_rounded, color: MoncarColors.inkFaint),
              ],
            ),
          ),
          const SizedBox(height: 8),
        ],
      ],
    );
  }
}
