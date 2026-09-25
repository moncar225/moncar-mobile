import 'package:core_ui/core_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/application/session_controller.dart';
import '../../../core/application/trip_controller.dart';
import '../../../core/domain/models.dart';
import '../../../core/ui/format.dart';
import '../../../core/ui/pro_kit.dart';
import '../../../core/ui/role_style.dart';
import '../../../core/ui/status_widgets.dart';
import '../../../core/ui/trip_widgets.dart';

/// Détail du voyage affecté : véhicule, équipage, itinéraire, horaires.
class VoyagePage extends ConsumerWidget {
  const VoyagePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = ref.watch(tripProvider);
    final role = ref.watch(activeRoleProvider) ?? ProRole.controleur;
    final v = t.voyage;
    return ProPage(
      title: 'Voyage ${v.number}',
      subtitle: v.companyName,
      actions: [
        MoncarBadge(label: v.status.label, tone: v.status.tone),
        const SizedBox(width: 4),
      ],
      children: [
        TripHeroCard(trip: t, colors: role.gradient),
        const SectionTitle('Véhicule et équipage'),
        MoncarCard(
          child: Column(
            children: [
              DetailRow(
                label: 'Véhicule',
                value: v.vehiclePlate,
                icon: Icons.directions_bus_rounded,
              ),
              DetailRow(
                label: 'Type',
                value: v.vehicleType,
                icon: Icons.info_outline_rounded,
              ),
              DetailRow(
                label: 'Chauffeur',
                value: v.driverName,
                icon: Icons.airline_seat_recline_normal_rounded,
              ),
              DetailRow(
                label: 'Convoyeur',
                value: v.convoyeurName,
                icon: Icons.fact_check_rounded,
              ),
              DetailRow(
                label: 'Contrôleur',
                value: v.controleurName,
                icon: Icons.qr_code_scanner_rounded,
              ),
            ],
          ),
        ),
        const SectionTitle('Horaires'),
        MoncarCard(
          child: Column(
            children: [
              DetailRow(
                label: 'Départ prévu',
                value: fmtTime(v.departurePlanned),
              ),
              DetailRow(
                label: 'Départ réel',
                value: v.departureActual == null
                    ? 'Non démarré'
                    : fmtTime(v.departureActual),
              ),
              DetailRow(
                label: 'Arrivée estimée',
                value: fmtTime(etaFor(v, v.destination)),
              ),
              DetailRow(label: 'Distance', value: '${v.totalKm.round()} km'),
              DetailRow(
                label: 'Places',
                value:
                    '${t.onBoard} à bord · ${v.totalSeats - t.onBoard} libres',
              ),
            ],
          ),
        ),
        const SectionTitle('Itinéraire'),
        MoncarCard(
          child: StopsTimeline(trip: t, accent: role.accent),
        ),
      ],
    );
  }
}
