import 'package:core_ui/core_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/application/app_providers.dart';
import '../../../core/application/gps_controller.dart';
import '../../../core/application/trip_controller.dart';
import '../../../core/domain/models.dart';
import '../../../core/ui/format.dart';
import '../../../core/ui/pro_kit.dart';
import '../../../core/ui/role_style.dart';
import '../../../core/ui/status_widgets.dart';
import '../../../core/ui/trip_widgets.dart';
import '../widgets/trip_map.dart';

/// Chauffeur · Conduite (CHAUF-03 → 06) : carte d'abord, une seule grande
/// action à la fois selon la phase. Chaque transition est confirmée par
/// le serveur (heure réelle enregistrée).
class DrivePage extends ConsumerStatefulWidget {
  const DrivePage({super.key});

  @override
  ConsumerState<DrivePage> createState() => _DrivePageState();
}

class _DrivePageState extends ConsumerState<DrivePage> {
  final _mapKey = GlobalKey<TripMapState>();

  void _toast(String msg) {
    final online = ref.read(networkProvider).online;
    showProToast(
      context,
      online ? msg : '$msg (hors ligne — envoi différé)',
      tone: online ? ToastTone.success : ToastTone.warning,
    );
  }

  @override
  Widget build(BuildContext context) {
    final t = ref.watch(tripProvider);
    final gps = ref.watch(gpsProvider);
    final settings = ref.watch(settingsProvider);
    final role = ProRole.chauffeur;
    final v = t.voyage;
    final next = v.nextStop;
    final notifier = ref.read(tripProvider.notifier);

    return Scaffold(
      backgroundColor: MoncarColors.background,
      body: Stack(
        children: [
          Positioned.fill(
            bottom: 300,
            child: TripMap(
              key: _mapKey,
              trip: t,
              gps: gps,
              accent: role.accent,
              focusSegment: true,
              follow: t.phase == DriverPhase.enRoute,
            ),
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
              child: Row(
                children: [
                  _MapChip(
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.circle,
                          size: 10,
                          color: gps.tracking
                              ? MoncarColors.success
                              : MoncarColors.inkFaint,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          gps.tracking ? 'GPS actif' : 'GPS en pause',
                          style: TextStyle(
                            fontWeight: FontWeight.w800,
                            color: MoncarColors.ink,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Spacer(),
                  const SyncPill(),
                  const SizedBox(width: 8),
                  CircleIconButton(
                    icon: settings.voiceAlerts
                        ? Icons.volume_up_rounded
                        : Icons.volume_off_rounded,
                    tooltip: 'Alertes vocales',
                    background: MoncarColors.surface,
                    onTap: () {
                      ref
                          .read(settingsProvider.notifier)
                          .setVoiceAlerts(!settings.voiceAlerts);
                      if (!settings.voiceAlerts) {
                        ref
                            .read(voiceProvider)
                            .speak('Alertes vocales activées.');
                      }
                    },
                  ),
                  const SizedBox(width: 8),
                  CircleIconButton(
                    icon: Icons.center_focus_strong_rounded,
                    tooltip: 'Recentrer',
                    background: MoncarColors.surface,
                    onTap: () => _mapKey.currentState?.recenter(),
                  ),
                ],
              ),
            ),
          ),
          Align(
            alignment: Alignment.bottomCenter,
            child: Container(
              constraints: const BoxConstraints(minHeight: 320),
              decoration: BoxDecoration(
                color: MoncarColors.surface,
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(28),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.18),
                    blurRadius: 24,
                    offset: const Offset(0, -6),
                  ),
                ],
              ),
              padding: const EdgeInsets.fromLTRB(20, 10, 20, 16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: MoncarColors.hairline,
                      borderRadius: BorderRadius.circular(99),
                    ),
                  ),
                  const SizedBox(height: 12),
                  _PhaseHeader(trip: t, gps: gps),
                  const SizedBox(height: 14),
                  _PhaseSteps(phase: t.phase, accent: role.accent),
                  const SizedBox(height: 16),
                  switch (t.phase) {
                    DriverPhase.avantDepart => SwipeToConfirm(
                      label: 'Glisser pour démarrer le voyage',
                      color: MoncarColors.success,
                      icon: Icons.play_arrow_rounded,
                      onConfirmed: () async {
                        notifier.startTrip();
                        _toast(
                          'Voyage démarré — contrôleur et convoyeur notifiés.',
                        );
                      },
                    ),
                    DriverPhase.enRoute => BigActionButton(
                      label: next == null
                          ? 'Arrivé'
                          : next.id == v.destination.id
                          ? 'Arrivé à destination'
                          : 'Arrivé à ${next.shortName}',
                      icon: Icons.flag_rounded,
                      color: MoncarColors.brand,
                      onPressed: () {
                        haptic(HapticKind.heavy);
                        notifier.arriveAtStop();
                        _toast('Arrivée enregistrée.');
                      },
                    ),
                    DriverPhase.aLArret => SwipeToConfirm(
                      label:
                          'Glisser pour repartir de ${v.currentStop.shortName}',
                      color: MoncarColors.success,
                      icon: Icons.play_arrow_rounded,
                      onConfirmed: () async {
                        notifier.departFromStop();
                        _toast('Départ de l’arrêt enregistré.');
                      },
                    ),
                    DriverPhase.arriveDestination => BigActionButton(
                      label: 'Clôturer le voyage',
                      icon: Icons.task_alt_rounded,
                      color: MoncarColors.danger,
                      onPressed: () => context.push('/chauf/cloture'),
                    ),
                    DriverPhase.cloture => InfoBanner(
                      icon: Icons.task_alt_rounded,
                      color: MoncarColors.success,
                      message:
                          'Voyage ${v.number} clôturé. Merci et bonne route !',
                    ),
                  },
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: _SmallAction(
                          icon: Icons.report_rounded,
                          label: 'Incident',
                          color: MoncarColors.danger,
                          onTap: () => context.push('/incidents?nouveau=1'),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: _SmallAction(
                          icon: Icons.map_rounded,
                          label: 'Itinéraire',
                          color: MoncarColors.brand,
                          onTap: () => context.go('/chauf/itineraire'),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: _SmallAction(
                          icon: Icons.directions_bus_rounded,
                          label: 'Voyage',
                          color: role.accent,
                          onTap: () => context.push('/voyage'),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _PhaseHeader extends StatelessWidget {
  const _PhaseHeader({required this.trip, required this.gps});

  final TripState trip;
  final GpsState gps;

  @override
  Widget build(BuildContext context) {
    final v = trip.voyage;
    final next = v.nextStop;
    final (overline, title) = switch (trip.phase) {
      DriverPhase.avantDepart => ('PRÊT AU DÉPART', v.origin.name),
      DriverPhase.enRoute => (
        'PROCHAIN ARRÊT',
        next?.name ?? v.destination.name,
      ),
      DriverPhase.aLArret => ('À L’ARRÊT', v.currentStop.name),
      DriverPhase.arriveDestination => (
        'ARRIVÉ À DESTINATION',
        v.destination.name,
      ),
      DriverPhase.cloture => ('VOYAGE CLÔTURÉ', v.destination.name),
    };
    final stats = <(String, String)>[
      if (trip.phase == DriverPhase.enRoute && next != null) ...[
        ('ETA', fmtTime(etaFor(v, next))),
        (
          'Distance',
          gps.distanceToNextKm == null
              ? '${(next.kmFromOrigin - v.currentStop.kmFromOrigin).round()} km'
              : '${gps.distanceToNextKm!.toStringAsFixed(gps.distanceToNextKm! < 10 ? 1 : 0)} km',
        ),
        ('Vitesse', '${gps.speedKmh.round()} km/h'),
      ] else if (trip.phase == DriverPhase.avantDepart) ...[
        ('Départ', fmtTime(v.departurePlanned)),
        ('À bord', '${trip.onBoard}'),
        ('Car', v.vehiclePlate.split(' ').take(2).join(' ')),
      ] else ...[
        ('Heure', fmtTime(DateTime.now())),
        ('À bord', '${trip.onBoard}'),
        ('Restant', '${(v.totalKm - v.currentStop.kmFromOrigin).round()} km'),
      ],
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          overline,
          style: TextStyle(
            fontSize: 11.5,
            letterSpacing: 1.2,
            fontWeight: FontWeight.w800,
            color: ProRole.chauffeur.accent,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          title,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.w900,
            color: MoncarColors.ink,
          ),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            for (final (i, (label, value)) in stats.indexed) ...[
              if (i > 0)
                Container(
                  width: 1,
                  height: 34,
                  color: MoncarColors.hairline,
                  margin: const EdgeInsets.symmetric(horizontal: 12),
                ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label,
                      style: TextStyle(
                        fontSize: 12,
                        color: MoncarColors.inkMut,
                      ),
                    ),
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(
                        value,
                        style: TextStyle(
                          fontSize: 19,
                          fontWeight: FontWeight.w900,
                          color: MoncarColors.ink,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ],
    );
  }
}

class _PhaseSteps extends StatelessWidget {
  const _PhaseSteps({required this.phase, required this.accent});

  final DriverPhase phase;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    const steps = [
      (DriverPhase.avantDepart, 'Départ'),
      (DriverPhase.enRoute, 'En route'),
      (DriverPhase.aLArret, 'Arrêts'),
      (DriverPhase.arriveDestination, 'Arrivée'),
      (DriverPhase.cloture, 'Clôture'),
    ];
    final current = phase.index;
    return Row(
      children: [
        for (final (i, (p, label)) in steps.indexed) ...[
          Expanded(
            child: Column(
              children: [
                Container(
                  height: 5,
                  decoration: BoxDecoration(
                    color: p.index < current
                        ? MoncarColors.success
                        : p.index == current
                        ? accent
                        : MoncarColors.hairline,
                    borderRadius: BorderRadius.circular(99),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 10.5,
                    fontWeight: p.index == current
                        ? FontWeight.w900
                        : FontWeight.w600,
                    color: p.index == current ? accent : MoncarColors.inkMut,
                  ),
                ),
              ],
            ),
          ),
          if (i < steps.length - 1) const SizedBox(width: 4),
        ],
      ],
    );
  }
}

class _MapChip extends StatelessWidget {
  const _MapChip({required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
    decoration: BoxDecoration(
      color: MoncarColors.surface,
      borderRadius: BorderRadius.circular(99),
      boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 8)],
    ),
    child: child,
  );
}

class _SmallAction extends StatelessWidget {
  const _SmallAction({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: color.withValues(alpha: MoncarColors.isDark ? 0.18 : 0.08),
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: Column(
            children: [
              Icon(icon, color: color),
              const SizedBox(height: 4),
              Text(
                label,
                style: TextStyle(
                  fontWeight: FontWeight.w800,
                  color: color,
                  fontSize: 12.5,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
