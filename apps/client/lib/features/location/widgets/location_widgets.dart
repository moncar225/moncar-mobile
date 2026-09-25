import 'package:flutter/material.dart';

import '../../shared/foundation.dart';
import '../data/vehicle_reviews.dart';

IconData vehicleIcon(VehicleType t) => switch (t) {
  VehicleType.suv || VehicleType.quatreQuatre => Icons.directions_car_filled,
  VehicleType.monospace => Icons.airport_shuttle,
  VehicleType.utilitaire => Icons.local_shipping,
  VehicleType.bus ||
  VehicleType.minibus ||
  VehicleType.autocar => Icons.directions_bus,
  VehicleType.berline || VehicleType.car => Icons.directions_car,
  VehicleType.vtc => Icons.local_taxi,
};

String vehicleLabel(VehicleType t) => switch (t) {
  VehicleType.car => 'Voiture',
  VehicleType.minibus => 'Minibus',
  VehicleType.bus => 'Bus',
  VehicleType.autocar => 'Car / Autocar',
  VehicleType.berline => 'Berline',
  VehicleType.suv => 'SUV',
  VehicleType.quatreQuatre => '4x4',
  VehicleType.monospace => 'Monospace',
  VehicleType.utilitaire => 'Utilitaire',
  VehicleType.vtc => 'VTC',
};

/// Types proposés à la location (§30).
const privateVehicleTypes = [
  VehicleType.berline,
  VehicleType.suv,
  VehicleType.quatreQuatre,
  VehicleType.monospace,
  VehicleType.utilitaire,
  VehicleType.vtc,
];
const collectiveVehicleTypes = [
  VehicleType.minibus,
  VehicleType.bus,
  VehicleType.autocar,
];

const _months = [
  'janv.',
  'févr.',
  'mars',
  'avr.',
  'mai',
  'juin',
  'juil.',
  'août',
  'sept.',
  'oct.',
  'nov.',
  'déc.',
];

String _p(int n) => n.toString().padLeft(2, '0');

/// « 24 sept. 2026 · 08h00 ».
String formatRentalDateTime(DateTime d) =>
    '${_p(d.day)} ${_months[d.month - 1]} ${d.year} · ${_p(d.hour)}h${_p(d.minute)}';

/// Variante à partir d'une chaîne ISO (« — » si invalide).
String formatRentalIso(String? iso) {
  final d = DateTime.tryParse(iso ?? '');
  return d == null ? '—' : formatRentalDateTime(d);
}

/// Retard / avance lisible : « 17 min de retard ».
String formatDelay(int minutes) {
  if (minutes.abs() < 2) return "À l'heure";
  final m = minutes.abs();
  final txt = m >= 60 ? '${m ~/ 60} h ${_p(m % 60)}' : '$m min';
  return minutes > 0 ? '$txt de retard' : '$txt d\'avance';
}

/// Sélecteur date + heure.
Future<DateTime?> pickRentalDateTime(
  BuildContext context,
  DateTime current, {
  DateTime? first,
}) async {
  final now = DateTime.now();
  final min = first ?? now;
  final date = await showDatePicker(
    context: context,
    initialDate: current.isBefore(min) ? min : current,
    firstDate: DateTime(min.year, min.month, min.day),
    lastDate: now.add(const Duration(days: 365)),
  );
  if (date == null || !context.mounted) return null;
  final time = await showTimePicker(
    context: context,
    initialTime: TimeOfDay.fromDateTime(current),
  );
  if (time == null) return null;
  return DateTime(date.year, date.month, date.day, time.hour, time.minute);
}

/// Ton du badge de statut d'une location.
MoncarBadgeTone rentalStatusTone(RentalStatus s) => switch (s) {
  RentalStatus.demandee => MoncarBadgeTone.warn,
  RentalStatus.confirmee => MoncarBadgeTone.accent,
  RentalStatus.payee || RentalStatus.remise => MoncarBadgeTone.brand,
  RentalStatus.active || RentalStatus.restituee => MoncarBadgeTone.success,
  RentalStatus.terminee => MoncarBadgeTone.neutral,
  RentalStatus.refusee || RentalStatus.annulee => MoncarBadgeTone.danger,
};

class RentalStatusBadge extends StatelessWidget {
  const RentalStatusBadge(this.status, {super.key});

  final RentalStatus status;

  @override
  Widget build(BuildContext context) {
    return MoncarBadge(
      label: status.label,
      tone: rentalStatusTone(status),
      size: MoncarBadgeSize.sm,
    );
  }
}

/// AGENCE | COMPAGNIE | INDIVIDUEL — toujours clairement identifié (§34).
class ProviderKindBadge extends StatelessWidget {
  const ProviderKindBadge(this.kind, {super.key});

  final RentalProviderKind kind;

  @override
  Widget build(BuildContext context) {
    return MoncarBadge(
      label: kind.label,
      tone: switch (kind) {
        RentalProviderKind.agence => MoncarBadgeTone.brand,
        RentalProviderKind.compagnie => MoncarBadgeTone.accent,
        RentalProviderKind.individuel => MoncarBadgeTone.neutral,
      },
      size: MoncarBadgeSize.sm,
      icon: switch (kind) {
        RentalProviderKind.agence => Icons.storefront_outlined,
        RentalProviderKind.compagnie => Icons.directions_bus_outlined,
        RentalProviderKind.individuel => Icons.person_outline,
      },
    );
  }
}

/// Libellé chauffeur d'un véhicule (règle VTC incluse).
String driverOfferLabel(RentalVehicle v) {
  if (v.isVtc) return 'VTC · avec chauffeur';
  return switch (v.driverOffer) {
    DriverOffer.avecChauffeur => 'Avec chauffeur',
    DriverOffer.sansChauffeur => 'Sans chauffeur',
    DriverOffer.auChoix => 'Avec ou sans chauffeur',
  };
}

/// « Photo » stylisée du véhicule : dégradé de sa couleur + icône.
class VehiclePhoto extends StatelessWidget {
  const VehiclePhoto({
    super.key,
    required this.vehicle,
    this.size = 112,
    this.height,
    this.iconSize = 48,
    this.radius = 14,
    this.showUnavailable = false,
    this.angle = 0,
  });

  final RentalVehicle vehicle;
  final double? size;
  final double? height;
  final double iconSize;
  final double radius;
  final bool showUnavailable;

  /// Variante de galerie (0 à 3) : décale le dégradé.
  final int angle;

  @override
  Widget build(BuildContext context) {
    final c = hexColor(vehicle.photoColor);
    const alignments = [
      (Alignment.topLeft, Alignment.bottomRight),
      (Alignment.topRight, Alignment.bottomLeft),
      (Alignment.bottomLeft, Alignment.topRight),
      (Alignment.centerLeft, Alignment.centerRight),
    ];
    final (begin, end) = alignments[angle % alignments.length];
    return ClipRRect(
      borderRadius: BorderRadius.circular(radius),
      child: Container(
        width: size,
        height: height ?? size,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: begin,
            end: end,
            colors: [c, c.withValues(alpha: 0.8), c.withValues(alpha: 0.33)],
            stops: const [0, 0.6, 1],
          ),
        ),
        child: Stack(
          alignment: Alignment.center,
          children: [
            Positioned(
              right: -16,
              bottom: -16,
              child: Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white.withValues(alpha: 0.15),
                ),
              ),
            ),
            Icon(
              vehicleIcon(vehicle.type),
              size: iconSize,
              color: Colors.white.withValues(alpha: 0.95),
            ),
            if (showUnavailable && !vehicle.available)
              Positioned.fill(
                child: ColoredBox(
                  color: MoncarColors.ink.withValues(alpha: 0.55),
                  child: const Center(
                    child: Text(
                      'INDISPONIBLE',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.5,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// Jauge de carburant en huitièmes.
class FuelGauge extends StatelessWidget {
  const FuelGauge({super.key, required this.eighths, this.compact = false});

  final int eighths;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final color = eighths <= 2
        ? MoncarColors.danger
        : eighths <= 4
        ? MoncarColors.warn
        : MoncarColors.success;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          Icons.local_gas_station_outlined,
          size: compact ? 14 : 16,
          color: MoncarColors.inkMut,
        ),
        const SizedBox(width: 6),
        for (var i = 1; i <= 8; i++)
          Container(
            width: compact ? 5 : 7,
            height: compact ? 10 : 14,
            margin: const EdgeInsets.only(right: 2),
            decoration: BoxDecoration(
              color: i <= eighths ? color : MoncarColors.hairline,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
        const SizedBox(width: 4),
        Text(
          '$eighths/8',
          style: TextStyle(
            fontSize: compact ? 11 : 12,
            fontWeight: FontWeight.w600,
            color: MoncarColors.ink,
          ),
        ),
      ],
    );
  }
}

/// Facture avant paiement : X + Y + Z = TOTAL (§38). La commission
/// MON CAR n'apparaît jamais.
class RentalInvoiceCard extends StatelessWidget {
  const RentalInvoiceCard({super.key, required this.quote, this.title});

  final RentalQuote quote;
  final String? title;

  @override
  Widget build(BuildContext context) {
    TextStyle label([bool strong = false]) => TextStyle(
      fontSize: 13,
      fontWeight: strong ? FontWeight.w700 : FontWeight.w400,
      color: strong ? MoncarColors.ink : MoncarColors.inkMut,
    );
    Widget row(String l, int amount, {bool strong = false, bool sub = false}) =>
        Padding(
          padding: EdgeInsets.only(bottom: 6, left: sub ? 12 : 0),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(
                  l,
                  style: sub
                      ? TextStyle(fontSize: 12, color: MoncarColors.inkFaint)
                      : label(strong),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                formatXOF(amount),
                style: sub
                    ? TextStyle(fontSize: 12, color: MoncarColors.inkFaint)
                    : label(strong),
              ),
            ],
          ),
        );
    return MoncarCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (title != null) ...[
            Text(
              title!,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: MoncarColors.ink,
              ),
            ),
            const SizedBox(height: 12),
          ],
          row('Montant brut de la location', quote.brutXOF, strong: true),
          for (final l in quote.brutLines) row(l.label, l.amountXOF, sub: true),
          const SizedBox(height: 4),
          row("Frais d'opération", quote.feesXOF),
          row('Autres frais applicables', quote.otherFeesXOF),
          for (final l in quote.otherFees) row(l.label, l.amountXOF, sub: true),
          Divider(height: 20, color: MoncarColors.hairline),
          Row(
            children: [
              Expanded(
                child: Text(
                  'TOTAL À PAYER',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.3,
                    color: MoncarColors.ink,
                  ),
                ),
              ),
              Text(
                formatXOF(quote.totalXOF),
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: MoncarColors.accent,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Carte « clé : valeur » compacte (fiches, récapitulatifs).
class InfoGrid extends StatelessWidget {
  const InfoGrid({super.key, required this.items});

  final List<(IconData, String, String)> items;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        for (final (icon, label, value) in items)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(icon, size: 16, color: MoncarColors.inkMut),
                const SizedBox(width: 10),
                SizedBox(
                  width: 112,
                  child: Text(
                    label,
                    style: TextStyle(fontSize: 12, color: MoncarColors.inkMut),
                  ),
                ),
                Expanded(
                  child: Text(
                    value,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: MoncarColors.ink,
                    ),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

/// Étapes du parcours de location (frise de progression).
const rentalSteps = [
  'Demande',
  'Confirmation',
  'Paiement',
  'Remise',
  'En cours',
  'Retour',
];

int rentalStepIndex(RentalStatus s) => switch (s) {
  RentalStatus.demandee || RentalStatus.refusee => 0,
  RentalStatus.confirmee => 1,
  RentalStatus.payee => 2,
  RentalStatus.remise => 3,
  RentalStatus.active => 4,
  RentalStatus.restituee || RentalStatus.terminee => 5,
  RentalStatus.annulee => 0,
};

class RentalProgress extends StatelessWidget {
  const RentalProgress({super.key, required this.status});

  final RentalStatus status;

  @override
  Widget build(BuildContext context) {
    final current = rentalStepIndex(status);
    final done = status == RentalStatus.terminee;
    return Row(
      children: [
        for (var i = 0; i < rentalSteps.length; i++)
          Expanded(
            child: Column(
              children: [
                Container(
                  height: 4,
                  margin: const EdgeInsets.symmetric(horizontal: 2),
                  decoration: BoxDecoration(
                    color: done || i < current
                        ? MoncarColors.brand
                        : i == current
                        ? MoncarColors.accent
                        : MoncarColors.hairline,
                    borderRadius: BorderRadius.circular(999),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  rentalSteps[i],
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 9.5,
                    fontWeight: i == current && !done
                        ? FontWeight.w700
                        : FontWeight.w500,
                    color: i == current && !done
                        ? MoncarColors.ink
                        : MoncarColors.inkFaint,
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

/// Carte d'un avis client (détail véhicule, liste des avis).
class ReviewCard extends StatelessWidget {
  const ReviewCard({super.key, required this.review});

  final VehicleReview review;

  @override
  Widget build(BuildContext context) {
    final r = review;
    return MoncarCard(
      padding: const EdgeInsets.all(14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          MoncarAvatar(initials: r.initials),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        r.name,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: MoncarColors.ink,
                        ),
                      ),
                    ),
                    Text(
                      r.date,
                      style: TextStyle(
                        fontSize: 11,
                        color: MoncarColors.inkFaint,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                Row(
                  children: [
                    for (var i = 0; i < 5; i++)
                      Icon(
                        i < r.rating
                            ? Icons.star_rounded
                            : Icons.star_outline_rounded,
                        size: 12,
                        color: i < r.rating
                            ? MoncarColors.accent
                            : MoncarColors.inkFaint,
                      ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  r.body,
                  style: TextStyle(
                    fontSize: 12,
                    height: 1.5,
                    color: MoncarColors.inkMut,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
