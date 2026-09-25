import 'package:flutter/material.dart';

import '../../shared/foundation.dart';

/// Icône associée à un équipement de trajet (Climatisation, Wi-Fi…).
IconData amenityIcon(String amenity) => switch (amenity) {
  'Climatisation' => Icons.ac_unit,
  'Wi-Fi' => Icons.wifi,
  'Sièges confort' || 'Sièges inclinables' => Icons.event_seat_outlined,
  'Prise USB' => Icons.power_outlined,
  'TV' => Icons.tv,
  'Snack' => Icons.restaurant,
  _ => Icons.star_border,
};

/// Libellé français d'un type de véhicule.
String vehicleTypeLabel(VehicleType t) => switch (t) {
  VehicleType.car => 'car',
  VehicleType.minibus => 'minibus',
  VehicleType.bus => 'bus',
  VehicleType.berline => 'berline',
  VehicleType.suv => 'SUV',
  VehicleType.monospace => 'monospace',
  VehicleType.utilitaire => 'utilitaire',
  VehicleType.vtc => 'VTC',
  VehicleType.quatreQuatre => '4x4',
  VehicleType.autocar => 'autocar',
};

/// Libellé français d'une politique d'annulation.
String cancellationLabel(CancellationPolicy p) => switch (p) {
  CancellationPolicy.flexible => 'flexible',
  CancellationPolicy.modere => 'modérée',
  CancellationPolicy.strict => 'stricte',
};

/// Carré coloré aux initiales de la compagnie.
class CompanyLogo extends StatelessWidget {
  const CompanyLogo({
    super.key,
    required this.name,
    required this.color,
    this.size = 32,
    this.radius = 8,
  });

  final String name;
  final String color;
  final double size;
  final double radius;

  @override
  Widget build(BuildContext context) {
    final initials = name.length >= 2 ? name.substring(0, 2) : name;
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: hexColor(color),
        borderRadius: BorderRadius.circular(radius),
      ),
      child: Text(
        initials.toUpperCase(),
        style: TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.w700,
          fontSize: size * 0.34,
        ),
      ),
    );
  }
}

/// Ligne pointillée horizontale (tracé de trajet).
class DashedLine extends StatelessWidget {
  const DashedLine({super.key, this.color, this.height = 1});

  final Color? color;
  final double height;

  @override
  Widget build(BuildContext context) {
    final color = this.color ?? MoncarColors.hairline;
    return LayoutBuilder(
      builder: (context, c) {
        const dash = 4.0;
        const gap = 3.0;
        final count = (c.maxWidth / (dash + gap)).floor().clamp(1, 1000);
        return Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: List.generate(
            count,
            (_) => SizedBox(
              width: dash,
              height: height,
              child: ColoredBox(color: color),
            ),
          ),
        );
      },
    );
  }
}

/// Titre de section simple des écrans de détail.
class SectionTitle extends StatelessWidget {
  const SectionTitle(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 0, 4, 12),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 15,
          fontWeight: FontWeight.w700,
          color: MoncarColors.ink,
        ),
      ),
    );
  }
}

/// Bandeau d'étape d'un aller-retour : « Étape 1/2 · Aller » puis
/// « Étape 2/2 · Retour » avec le rappel de l'aller déjà choisi.
class RoundTripBanner extends StatelessWidget {
  const RoundTripBanner({super.key, required this.isReturn, this.outbound});

  final bool isReturn;

  /// Aller déjà choisi (affiché pendant le choix du retour).
  final DraftLeg? outbound;

  @override
  Widget build(BuildContext context) {
    final out = outbound;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isReturn ? MoncarColors.accentSoft : MoncarColors.brandSoft,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Container(
            width: 32,
            height: 32,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: isReturn ? MoncarColors.accent : MoncarColors.brand,
              shape: BoxShape.circle,
            ),
            child: Icon(
              isReturn ? Icons.u_turn_left : Icons.arrow_forward,
              size: 16,
              color: Colors.white,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isReturn
                      ? 'Étape 2/2 · Choisissez votre retour'
                      : 'Étape 1/2 · Choisissez votre aller',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: isReturn
                        ? MoncarColors.accentInk
                        : MoncarColors.brand,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  isReturn && out != null
                      ? 'Aller : ${out.trip.companyName} · '
                            '${formatDateNumeric(out.trip.date)} à ${out.trip.departureTime} · '
                            'siège${out.seats.length > 1 ? 's' : ''} ${out.seats.join(', ')}'
                      : 'Vous choisirez ensuite le trajet retour.',
                  style: TextStyle(fontSize: 11.5, color: MoncarColors.inkMut),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Carte du segment retour d'une réservation aller-retour
/// (récapitulatif, confirmation).
class ReturnLegCard extends StatelessWidget {
  const ReturnLegCard({super.key, required this.leg});

  final ReturnLeg leg;

  @override
  Widget build(BuildContext context) {
    final n = leg.seats.length;
    return MoncarCard(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const MoncarBadge(
                label: 'RETOUR',
                tone: MoncarBadgeTone.accent,
                size: MoncarBadgeSize.sm,
                icon: Icons.u_turn_left,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  leg.companyName,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: MoncarColors.ink,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            leg.tripSummary,
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: MoncarColors.ink,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            '${formatDateFull(leg.date)} · ${leg.departureTime} → ${leg.arrivalTime}',
            style: TextStyle(fontSize: 12, color: MoncarColors.inkMut),
          ),
          const SizedBox(height: 2),
          Text(
            '${leg.originStop} → ${leg.destinationStop}',
            style: TextStyle(fontSize: 12, color: MoncarColors.inkMut),
          ),
          const SizedBox(height: 2),
          Text(
            '$n siège${n > 1 ? 's' : ''} : ${leg.seats.join(', ')}',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: MoncarColors.ink,
            ),
          ),
        ],
      ),
    );
  }
}
