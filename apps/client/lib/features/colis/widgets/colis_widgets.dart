import 'package:flutter/material.dart';

import '../../shared/foundation.dart';

/// Libellé court d'un statut de colis (listes, badges).
String parcelStatusLabel(ParcelStatus s) => switch (s) {
  ParcelStatus.depose => 'Déposé',
  ParcelStatus.enTransit => 'En transit',
  ParcelStatus.arriveGare => 'Arrivé en gare',
  ParcelStatus.attenteRetrait => 'Attente de retrait',
  ParcelStatus.livre => 'Livré',
  ParcelStatus.litige => 'Litige',
  ParcelStatus.annule => 'Annulé',
};

/// Tonalité de badge d'un statut de colis.
MoncarBadgeTone parcelStatusTone(ParcelStatus s) => switch (s) {
  ParcelStatus.depose => MoncarBadgeTone.neutral,
  ParcelStatus.enTransit => MoncarBadgeTone.accent,
  ParcelStatus.arriveGare => MoncarBadgeTone.brand,
  ParcelStatus.attenteRetrait => MoncarBadgeTone.warn,
  ParcelStatus.livre => MoncarBadgeTone.success,
  ParcelStatus.litige => MoncarBadgeTone.danger,
  ParcelStatus.annule => MoncarBadgeTone.neutral,
};

/// Pourcentage d'étapes réalisées dans la chronologie (0..100).
int parcelProgressPct(Parcel p) {
  final total = p.timeline.isEmpty ? 1 : p.timeline.length;
  final done = p.timeline.where((t) => t.done).length;
  return (done / total * 100).round();
}

/// Barre de progression fine (couleur selon le statut du colis).
class ParcelProgressBar extends StatelessWidget {
  const ParcelProgressBar({super.key, required this.parcel, this.height = 6});

  final Parcel parcel;
  final double height;

  @override
  Widget build(BuildContext context) {
    final pct = parcelProgressPct(parcel);
    final solid = switch (parcel.status) {
      ParcelStatus.livre => MoncarColors.success,
      ParcelStatus.litige => MoncarColors.danger,
      ParcelStatus.annule => MoncarColors.inkFaint,
      _ => null,
    };
    return ClipRRect(
      borderRadius: BorderRadius.circular(999),
      child: Container(
        height: height,
        color: MoncarColors.muted,
        alignment: Alignment.centerLeft,
        child: AnimatedFractionallySizedBox(
          duration: const Duration(milliseconds: 400),
          widthFactor: pct / 100,
          child: Container(
            decoration: solid != null
                ? BoxDecoration(color: solid)
                : accentGradientDecoration(),
          ),
        ),
      ),
    );
  }
}
