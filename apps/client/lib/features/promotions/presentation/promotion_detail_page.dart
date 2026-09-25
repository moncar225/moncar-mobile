import 'package:flutter/material.dart';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../shared/foundation.dart';
import '../widgets/promo_widgets.dart';

IconData _serviceIcon(PromoService s) => switch (s) {
  PromoService.voyager => Icons.directions_bus_outlined,
  PromoService.colis => Icons.inventory_2_outlined,
  PromoService.location => Icons.directions_car_outlined,
  PromoService.tous => Icons.auto_awesome,
};

String _serviceRoute(PromoService s) => switch (s) {
  PromoService.colis => '/colis',
  PromoService.location => '/location',
  _ => '/voyager',
};

/// Détail d'une promotion : code copiable, valeur, niveau requis,
/// validité, quota d'utilisation et conditions. L'éligibilité réelle
/// reste vérifiée par le serveur au paiement.
class PromotionDetailPage extends ConsumerWidget {
  const PromotionDetailPage({super.key, required this.promoId});

  final String promoId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final promo = ref.read(mockStoreProvider).findPromotionById(promoId.trim());
    return Scaffold(
      backgroundColor: MoncarColors.background,
      appBar: const TopBar(
        title: 'Détail promotion',
        showBack: true,
        showBell: false,
      ),
      body: promo == null
          ? Padding(
              padding: const EdgeInsets.all(16),
              child: MoncarErrorState(
                title: 'Promotion introuvable',
                message: "Cette promotion n'existe plus ou a expiré.",
                onRetry: () => context.go('/promotions'),
              ),
            )
          : _Detail(promo: promo),
    );
  }
}

class _Detail extends ConsumerWidget {
  const _Detail({required this.promo});

  final Promotion promo;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final p = promo;
    final userTier =
        ref.watch(authProvider).user?.loyaltyTier ?? LoyaltyTier.standard;
    final tierOk = loyaltyTierRank(userTier) >= loyaltyTierRank(p.minTier);
    final usageLeft = (p.usageMax - p.usageCount).clamp(0, p.usageMax);
    final isPct = p.type == PromoType.pourcentage;
    final glass = Colors.white.withValues(alpha: 0.2);

    Future<void> copyCode() => copyWithToast(
      context,
      p.code,
      message:
          'Code copié : ${p.code}. Collez-le lors du paiement pour appliquer la réduction.',
    );

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
      children: [
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            gradient: promoGradient(p.imageColor),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Semantics(
                    button: true,
                    label: 'Copier le code ${p.code}',
                    child: InkWell(
                      onTap: copyCode,
                      borderRadius: BorderRadius.circular(12),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: Colors.white.withValues(alpha: 0.25),
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              p.code,
                              style: const TextStyle(
                                fontSize: 18,
                                fontFamily: 'monospace',
                                fontWeight: FontWeight.w700,
                                letterSpacing: 1.5,
                                color: Colors.white,
                              ),
                            ),
                            const SizedBox(width: 8),
                            const Icon(
                              Icons.copy,
                              size: 14,
                              color: Colors.white70,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const Spacer(),
                  if (p.featured)
                    MoncarBadge(
                      label: 'À la une',
                      icon: Icons.auto_awesome,
                      size: MoncarBadgeSize.sm,
                      backgroundColor: Colors.white.withValues(alpha: 0.25),
                      textColor: Colors.white,
                    ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                crossAxisAlignment: CrossAxisAlignment.baseline,
                textBaseline: TextBaseline.alphabetic,
                children: [
                  Text(
                    formatPromoValue(p),
                    style: const TextStyle(
                      fontSize: 36,
                      height: 1,
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(width: 8),
                  OverlineText(
                    'de remise',
                    color: Colors.white.withValues(alpha: 0.8),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                p.title,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                p.description,
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.white.withValues(alpha: 0.85),
                ),
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                children: [
                  MoncarBadge(
                    label: promoServiceLabel(p.service),
                    icon: _serviceIcon(p.service),
                    size: MoncarBadgeSize.sm,
                    backgroundColor: glass,
                    textColor: Colors.white,
                  ),
                  MoncarBadge(
                    label: isPct ? 'Pourcentage' : 'Montant fixe',
                    icon: isPct ? Icons.percent : Icons.sell_outlined,
                    size: MoncarBadgeSize.sm,
                    backgroundColor: glass,
                    textColor: Colors.white,
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        MoncarCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  IconTile(
                    icon: tierOk
                        ? Icons.verified_user_outlined
                        : Icons.warning_amber_rounded,
                    color: tierOk ? MoncarColors.success : MoncarColors.warn,
                    background: tierOk
                        ? MoncarColors.successSoft
                        : MoncarColors.warnSoft,
                    size: 40,
                    radius: 20,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const OverlineText('Réservé aux membres'),
                        Text(
                          'Membre ${p.minTier.label} ou supérieur',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: MoncarColors.ink,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          tierOk
                              ? '✓ Vous êtes ${userTier.label} — vous en profitez !'
                              : 'Votre niveau : ${userTier.label} — passez ${p.minTier.label} pour en profiter.',
                          style: TextStyle(
                            fontSize: 11,
                            color: tierOk
                                ? MoncarColors.success
                                : MoncarColors.warn,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              if (!tierOk) ...[
                const SizedBox(height: 12),
                MoncarButton(
                  label: 'Voir mon programme fidélité',
                  icon: Icons.arrow_forward,
                  variant: MoncarButtonVariant.soft,
                  size: MoncarButtonSize.sm,
                  expand: true,
                  onPressed: () => context.push('/loyalty'),
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 12),
        MoncarCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  IconTile(
                    icon: Icons.calendar_today_outlined,
                    background: MoncarColors.brandSoft,
                    size: 36,
                    radius: 18,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const OverlineText('Période de validité'),
                        Text(
                          'Du ${formatDateLong(p.validFrom)}',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: MoncarColors.ink,
                          ),
                        ),
                        Text(
                          'au ${formatDateLong(p.validUntil)}',
                          style: TextStyle(
                            fontSize: 13,
                            color: MoncarColors.inkMut,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Divider(height: 1, color: MoncarColors.hairline),
              const SizedBox(height: 16),
              Row(
                children: [
                  Icon(
                    Icons.group_outlined,
                    size: 12,
                    color: MoncarColors.inkMut,
                  ),
                  const SizedBox(width: 4),
                  const OverlineText('Utilisations'),
                  const Spacer(),
                  Text(
                    '${formatNumber(p.usageCount)} / ${formatNumber(p.usageMax)}',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: MoncarColors.ink,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              PromoUsageBar(promo: p, height: 8),
              const SizedBox(height: 6),
              Text(
                usageLeft > 0
                    ? '${formatNumber(usageLeft)} places restantes'
                    : 'Quota atteint — code plus valide',
                textAlign: TextAlign.right,
                style: TextStyle(fontSize: 11, color: MoncarColors.inkMut),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        MoncarCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(
                    Icons.description_outlined,
                    size: 16,
                    color: MoncarColors.brand,
                  ),
                  SizedBox(width: 8),
                  Text(
                    "Conditions d'utilisation",
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: MoncarColors.ink,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                p.terms,
                style: TextStyle(
                  fontSize: 12,
                  height: 1.5,
                  color: MoncarColors.inkMut,
                ),
              ),
              const SizedBox(height: 12),
              for (final line in const [
                "Code saisissable à l'étape de paiement du panier.",
                "Non cumulable avec d'autres promotions en cours.",
                "L'éligibilité finale est vérifiée par nos serveurs au paiement.",
              ])
                Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Padding(
                        padding: EdgeInsets.only(top: 2),
                        child: Icon(
                          Icons.check,
                          size: 12,
                          color: MoncarColors.success,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          line,
                          style: TextStyle(
                            fontSize: 12,
                            color: MoncarColors.inkMut,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        MoncarButton(
          label: usageLeft == 0
              ? 'Quota atteint'
              : 'Utiliser cette promo — ${promoServiceLabel(p.service)}',
          icon: Icons.confirmation_number_outlined,
          variant: MoncarButtonVariant.primary,
          size: MoncarButtonSize.xl,
          expand: true,
          onPressed: usageLeft == 0
              ? null
              : () async {
                  await copyCode();
                  if (!context.mounted) return;
                  showMoncarToast(
                    context,
                    'Code ${p.code} copié pour votre ${promoServiceLabel(p.service)}.',
                  );
                  context.go(_serviceRoute(p.service));
                },
        ),
        const SizedBox(height: 10),
        MoncarButton(
          label: 'Partager',
          icon: Icons.share_outlined,
          variant: MoncarButtonVariant.outline,
          size: MoncarButtonSize.lg,
          expand: true,
          onPressed: () => copyWithToast(
            context,
            'Code promo MON CAR : ${p.code} — ${p.title}',
            message: 'Promotion copiée dans le presse-papier.',
          ),
        ),
      ],
    );
  }
}
