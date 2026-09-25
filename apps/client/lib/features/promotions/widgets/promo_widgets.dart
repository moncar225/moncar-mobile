import 'package:flutter/material.dart';

import '../../shared/foundation.dart';

String promoServiceLabel(PromoService s) => switch (s) {
  PromoService.voyager => 'Voyager',
  PromoService.colis => 'Colis',
  PromoService.location => 'Location',
  PromoService.tous => 'Tous services',
};

MoncarBadgeTone promoServiceTone(PromoService s) => switch (s) {
  PromoService.voyager => MoncarBadgeTone.brand,
  PromoService.colis => MoncarBadgeTone.success,
  PromoService.location => MoncarBadgeTone.accent,
  PromoService.tous => MoncarBadgeTone.neutral,
};

/// « -20% » ou « -1 000 FCFA ».
String formatPromoValue(Promotion p) =>
    p.type == PromoType.pourcentage ? '-${p.value}%' : '-${formatXOF(p.value)}';

int promoUsagePct(Promotion p) =>
    (p.usageCount / (p.usageMax < 1 ? 1 : p.usageMax) * 100).round().clamp(
      0,
      100,
    );

/// Dégradé de la couleur d'une promotion (cartes, en-têtes).
LinearGradient promoGradient(String color) {
  final c = hexColor(color);
  return LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [c, c.withValues(alpha: 0.85), c.withValues(alpha: 0.6)],
    stops: const [0, 0.55, 1],
  );
}

/// Barre d'utilisation (rouge ≥ 85 %, accent ≥ 60 %, marque sinon).
class PromoUsageBar extends StatelessWidget {
  const PromoUsageBar({super.key, required this.promo, this.height = 6});

  final Promotion promo;
  final double height;

  @override
  Widget build(BuildContext context) {
    final pct = promoUsagePct(promo);
    final decoration = pct >= 85
        ? BoxDecoration(color: MoncarColors.danger)
        : pct >= 60
        ? accentGradientDecoration()
        : brandGradientDecoration();
    return ClipRRect(
      borderRadius: BorderRadius.circular(999),
      child: Container(
        height: height,
        color: MoncarColors.muted,
        alignment: Alignment.centerLeft,
        child: FractionallySizedBox(
          widthFactor: pct / 100,
          child: Container(decoration: decoration),
        ),
      ),
    );
  }
}
