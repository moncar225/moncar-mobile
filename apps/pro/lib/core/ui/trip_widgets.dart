// Widgets « voyage » partagés entre profils (carte héros, itinéraire).
library;

import 'package:core_ui/core_ui.dart';
import 'package:flutter/material.dart';

import '../application/trip_controller.dart';
import '../domain/models.dart';
import 'format.dart';
import 'pro_kit.dart';

/// ETA affichée d'un arrêt. ⚠️ MOCK : horaire de référence + retard au
/// départ ; l'ETA réelle par arrêt est calculée côté serveur (GPS-001).
DateTime etaFor(Voyage v, Stop s) {
  final actual = v.departureActual;
  final delay = actual == null
      ? v.delayMin
      : actual.difference(v.departurePlanned).inMinutes.clamp(0, 600);
  return s.plannedAt.add(Duration(minutes: delay));
}

/// Carte « Voyage du jour » (dashboard de tous les profils terrain).
class TripHeroCard extends StatelessWidget {
  const TripHeroCard({
    super.key,
    required this.trip,
    required this.colors,
    this.onTap,
  });

  final TripState trip;
  final List<Color> colors;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final v = trip.voyage;
    final op = trip.operationalStop;
    final atStop =
        trip.phase == DriverPhase.aLArret ||
        trip.phase == DriverPhase.avantDepart;
    return HeroCard(
      colors: colors,
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Flexible(
                child: Text(
                  'VOYAGE ${v.number}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 12,
                    letterSpacing: 1.2,
                    fontWeight: FontWeight.w800,
                    color: Colors.white70,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              const Spacer(),
              GlassPill(label: v.status.label, icon: _statusIcon(v.status)),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(
                child: _Place(
                  label:
                      'Départ ${fmtTime(v.departureActual ?? v.departurePlanned)}',
                  city: v.origin.shortName,
                ),
              ),
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                child: Icon(Icons.east_rounded, size: 26),
              ),
              Expanded(
                child: _Place(
                  label: 'Arrivée ${fmtTime(etaFor(v, v.destination))}',
                  city: v.destination.shortName,
                  end: true,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          RouteProgressBar(voyage: v),
          const SizedBox(height: 14),
          Row(
            children: [
              Icon(atStop ? Icons.place_rounded : Icons.flag_rounded, size: 18),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  op == null
                      ? 'Terminus atteint'
                      : '${atStop ? 'À quai' : 'Prochain arrêt'} : ${op.shortName}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 14,
                  ),
                ),
              ),
              if (op != null && !atStop)
                Text(
                  'ETA ${fmtTime(etaFor(v, op))}',
                  style: const TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 14,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              GlassPill(
                label: v.vehiclePlate,
                icon: Icons.directions_bus_rounded,
              ),
              GlassPill(
                label: '${trip.onBoard}/${v.totalSeats} à bord',
                icon: Icons.airline_seat_recline_normal_rounded,
              ),
              if (v.departureActual != null &&
                  v.departureActual!.difference(v.departurePlanned).inMinutes >
                      0)
                GlassPill(
                  label:
                      '+${v.departureActual!.difference(v.departurePlanned).inMinutes} min',
                  icon: Icons.schedule_rounded,
                ),
            ],
          ),
        ],
      ),
    );
  }

  static IconData _statusIcon(VoyageStatus s) => switch (s) {
    VoyageStatus.embarquement => Icons.how_to_reg_rounded,
    VoyageStatus.enCours => Icons.route_rounded,
    VoyageStatus.arrive => Icons.flag_rounded,
    VoyageStatus.cloture => Icons.task_alt_rounded,
    _ => Icons.event_rounded,
  };
}

class _Place extends StatelessWidget {
  const _Place({required this.label, required this.city, this.end = false});

  final String label;
  final String city;
  final bool end;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: end
          ? CrossAxisAlignment.end
          : CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(fontSize: 12, color: Colors.white70),
        ),
        const SizedBox(height: 2),
        FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(
            city,
            style: const TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w900,
              height: 1.1,
            ),
          ),
        ),
      ],
    );
  }
}

/// Barre de progression horizontale avec les arrêts (sur fond coloré).
class RouteProgressBar extends StatelessWidget {
  const RouteProgressBar({super.key, required this.voyage, this.onDark = true});

  final Voyage voyage;
  final bool onDark;

  @override
  Widget build(BuildContext context) {
    final track = onDark
        ? Colors.white.withValues(alpha: 0.25)
        : MoncarColors.muted;
    final fill = onDark ? Colors.white : MoncarColors.accent;
    return LayoutBuilder(
      builder: (context, c) {
        final w = c.maxWidth;
        return SizedBox(
          height: 18,
          child: Stack(
            alignment: Alignment.centerLeft,
            children: [
              Container(
                height: 5,
                decoration: BoxDecoration(
                  color: track,
                  borderRadius: BorderRadius.circular(99),
                ),
              ),
              AnimatedContainer(
                duration: const Duration(milliseconds: 500),
                curve: Curves.easeOutCubic,
                height: 5,
                width: w * voyage.progress,
                decoration: BoxDecoration(
                  color: fill,
                  borderRadius: BorderRadius.circular(99),
                ),
              ),
              for (final s in voyage.stops)
                Positioned(
                  left:
                      (w - 14) *
                      (voyage.totalKm == 0
                          ? 0
                          : s.kmFromOrigin / voyage.totalKm),
                  child: Container(
                    width: 14,
                    height: 14,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: s.order <= voyage.currentStopIndex ? fill : track,
                      border: Border.all(
                        color: onDark ? Colors.white : MoncarColors.surface,
                        width: 2,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}

/// Itinéraire vertical : arrêts passés, en cours et à venir.
class StopsTimeline extends StatelessWidget {
  const StopsTimeline({
    super.key,
    required this.trip,
    required this.accent,
    this.showCounts = true,
  });

  final TripState trip;
  final Color accent;
  final bool showCounts;

  @override
  Widget build(BuildContext context) {
    final v = trip.voyage;
    return Column(
      children: [
        for (final s in v.stops)
          _StopRow(
            stop: s,
            eta: etaFor(v, s),
            passed:
                s.order < v.currentStopIndex ||
                (s.order == v.currentStopIndex &&
                    trip.phase == DriverPhase.enRoute),
            current:
                s.order == v.currentStopIndex &&
                trip.phase != DriverPhase.enRoute,
            next:
                trip.phase == DriverPhase.enRoute &&
                s.order == v.currentStopIndex + 1,
            last: s.order == v.stops.length - 1,
            accent: accent,
            off: showCounts
                ? trip.passengers.where((p) => p.dropStopId == s.id).length
                : 0,
            on: showCounts
                ? trip.validTickets.where((p) => p.boardStopId == s.id).length
                : 0,
          ),
      ],
    );
  }
}

class _StopRow extends StatelessWidget {
  const _StopRow({
    required this.stop,
    required this.eta,
    required this.passed,
    required this.current,
    required this.next,
    required this.last,
    required this.accent,
    required this.off,
    required this.on,
  });

  final Stop stop;
  final DateTime eta;
  final bool passed;
  final bool current;
  final bool next;
  final bool last;
  final Color accent;
  final int off;
  final int on;

  @override
  Widget build(BuildContext context) {
    final dotColor = passed
        ? MoncarColors.success
        : (current || next)
        ? accent
        : MoncarColors.hairline;
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            width: 28,
            child: Column(
              children: [
                const SizedBox(height: 4),
                Container(
                  width: current || next ? 18 : 14,
                  height: current || next ? 18 : 14,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: passed || current || next
                        ? dotColor
                        : MoncarColors.surface,
                    border: Border.all(color: dotColor, width: 3),
                  ),
                  child: passed
                      ? const Icon(Icons.check, size: 9, color: Colors.white)
                      : null,
                ),
                if (!last)
                  Expanded(
                    child: Container(
                      width: 3,
                      margin: const EdgeInsets.symmetric(vertical: 2),
                      color: passed
                          ? MoncarColors.success
                          : MoncarColors.hairline,
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Padding(
              padding: EdgeInsets.only(bottom: last ? 0 : 18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          stop.name,
                          style: TextStyle(
                            fontSize: 14.5,
                            fontWeight: current || next
                                ? FontWeight.w800
                                : FontWeight.w600,
                            color: passed
                                ? MoncarColors.inkMut
                                : MoncarColors.ink,
                          ),
                        ),
                      ),
                      Text(
                        fmtTime(eta),
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          color: current || next ? accent : MoncarColors.inkMut,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 3),
                  Row(
                    children: [
                      if (current)
                        _Tag('À quai', accent)
                      else if (next)
                        _Tag('Prochain arrêt', accent),
                      if (current || next) const SizedBox(width: 6),
                      Text(
                        '${stop.kmFromOrigin.round()} km'
                        '${on > 0 ? ' · $on montée${on > 1 ? 's' : ''}' : ''}'
                        '${off > 0 ? ' · $off descente${off > 1 ? 's' : ''}' : ''}',
                        style: TextStyle(
                          fontSize: 12,
                          color: MoncarColors.inkMut,
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

class _Tag extends StatelessWidget {
  const _Tag(this.label, this.color);

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(99),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 10.5,
          fontWeight: FontWeight.w800,
          color: color,
        ),
      ),
    );
  }
}
