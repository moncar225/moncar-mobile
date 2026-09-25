import 'package:flutter/material.dart';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../shared/foundation.dart';

const _tierAccent = {
  LoyaltyTier.standard: Color(0xFF6B7690),
  LoyaltyTier.argent: Color(0xFF9AA3B8),
  LoyaltyTier.or: Color(0xFFFF6600),
  LoyaltyTier.vip: Color(0xFF002060),
};

const _tierThreshold = {
  LoyaltyTier.standard: 0,
  LoyaltyTier.argent: 500,
  LoyaltyTier.or: 2000,
  LoyaltyTier.vip: 5000,
};

const _tierBenefits = {
  LoyaltyTier.standard: [
    '1 FCFA dépensé = 1 point',
    'Accès aux promotions standards',
    'Support client standard',
  ],
  LoyaltyTier.argent: [
    'Sièges prioritaires sur les trajets',
    '+10% de points sur chaque trajet',
    'Annulation flexible offerte',
    'Support prioritaire',
  ],
  LoyaltyTier.or: [
    '+25% de points sur chaque trajet',
    'Accès aux promos réservées Or',
    'Snack offert à bord',
    'Garantie remboursement 48h',
    'Service client VIP',
  ],
  LoyaltyTier.vip: [
    '+50% de points à vie',
    'Trajet gratuit annuel (longue distance)',
    'Chauffeur privé (-15% location)',
    'Conciergerie 24/7',
    "Salle VIP en gare d'Adjamé",
  ],
};

IconData _rewardIcon(LoyaltyRewardType t) => switch (t) {
  LoyaltyRewardType.remise => Icons.sell_outlined,
  LoyaltyRewardType.trajetGratuit => Icons.confirmation_number_outlined,
  LoyaltyRewardType.upgrade => Icons.star_border,
  LoyaltyRewardType.cadeau => Icons.card_giftcard,
};

String _rewardTypeLabel(LoyaltyRewardType t) => switch (t) {
  LoyaltyRewardType.remise => 'Bon de réduction',
  LoyaltyRewardType.trajetGratuit => 'Trajet gratuit',
  LoyaltyRewardType.upgrade => 'Upgrade',
  LoyaltyRewardType.cadeau => 'Cadeau',
};

/// Tableau de bord fidélité : carte de niveau, avantages, catalogue
/// de récompenses, historique des points et comparatif des niveaux.
/// Les points et le niveau sont la vérité serveur : l'échange n'est
/// jamais débité côté client.
class LoyaltyPage extends ConsumerStatefulWidget {
  const LoyaltyPage({super.key});

  @override
  ConsumerState<LoyaltyPage> createState() => _LoyaltyPageState();
}

class _LoyaltyPageState extends ConsumerState<LoyaltyPage> {
  LoyaltyReward? _exchanged;

  @override
  Widget build(BuildContext context) {
    ref.watch(mockStoreChangesProvider);
    final loyalty = ref.read(mockStoreProvider).loyalty;
    final userTier = ref.watch(authProvider).user?.loyaltyTier ?? loyalty.tier;
    const topBar = TopBar(title: 'Fidélité', showBack: true, showBell: false);

    final exchanged = _exchanged;
    if (exchanged != null) {
      return Scaffold(
        appBar: topBar,
        body: MoncarSuccessState(
          title: 'Récompense échangée !',
          message:
              'Votre ${exchanged.title.toLowerCase()} est en cours de crédit sur votre compte. Les points seront débités sous 24h.',
          actionLabel: 'Retour à la fidélité',
          onAction: () => setState(() => _exchanged = null),
          secondaryLabel: 'Voir mes points',
          onSecondary: () => setState(() => _exchanged = null),
        ),
      );
    }

    return Scaffold(
      backgroundColor: MoncarColors.background,
      appBar: topBar,
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
        children: [
          _TierCard(loyalty: loyalty),
          const SizedBox(height: 20),
          MoncarCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      Icons.verified_user_outlined,
                      size: 16,
                      color: MoncarColors.accent,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Vos avantages ${loyalty.tier.label}',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: MoncarColors.ink,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                for (final b in loyalty.tierBenefits)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          width: 20,
                          height: 20,
                          decoration: BoxDecoration(
                            color: MoncarColors.successSoft,
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            Icons.check,
                            size: 12,
                            color: MoncarColors.success,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            b,
                            style: TextStyle(
                              fontSize: 13,
                              height: 1.35,
                              color: MoncarColors.ink,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          const MoncarSectionHeader(title: 'Récompenses disponibles'),
          for (final r in loyalty.rewards) ...[
            _RewardCard(
              reward: r,
              userTier: userTier,
              userPoints: loyalty.points,
              onExchange: () {
                setState(() => _exchanged = r);
                showMoncarToast(
                  context,
                  'Récompense échangée — ${r.title} : ${r.pointCost} pts seront débités.',
                  success: true,
                );
              },
            ),
            const SizedBox(height: 12),
          ],
          const SizedBox(height: 8),
          const MoncarSectionHeader(title: 'Historique des points'),
          MoncarCard(
            child: loyalty.history.isEmpty
                ? Padding(
                    padding: EdgeInsets.symmetric(vertical: 16),
                    child: Text(
                      'Aucun mouvement de points pour le moment.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 12,
                        color: MoncarColors.inkMut,
                      ),
                    ),
                  )
                : Column(
                    children: [
                      for (var i = 0; i < loyalty.history.length; i++)
                        _HistoryItem(
                          m: loyalty.history[i],
                          isLast: i == loyalty.history.length - 1,
                        ),
                    ],
                  ),
          ),
          const SizedBox(height: 20),
          MoncarCard(
            color: MoncarColors.brandSoft.withValues(alpha: 0.6),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Icon(
                      Icons.info_outline,
                      size: 16,
                      color: MoncarColors.brand,
                    ),
                    SizedBox(width: 8),
                    Text(
                      'Comment gagner des points',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: MoncarColors.ink,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                _EarnRow(
                  icon: Icons.directions_bus_outlined,
                  color: MoncarColors.brand,
                  bg: MoncarColors.brandSoft,
                  text: '1 FCFA dépensé sur un trajet',
                  value: '+1 pt',
                ),
                _EarnRow(
                  icon: Icons.inventory_2_outlined,
                  color: MoncarColors.success,
                  bg: MoncarColors.successSoft,
                  text: '1 FCFA dépensé sur un colis',
                  value: '+1 pt',
                ),
                _EarnRow(
                  icon: Icons.directions_car_outlined,
                  color: MoncarColors.accent,
                  bg: MoncarColors.accentSoft,
                  text: '1 FCFA dépensé sur une location',
                  value: '+1 pt',
                ),
                _EarnRow(
                  icon: Icons.emoji_events_outlined,
                  color: MoncarColors.warn,
                  bg: MoncarColors.warnSoft,
                  text: 'Bonus de bienvenue (1ère commande)',
                  value: '+200 pts',
                ),
                _EarnRow(
                  icon: Icons.auto_awesome,
                  color: MoncarColors.brand,
                  bg: MoncarColors.brandSoft,
                  text: "Bonus selon votre niveau (jusqu'à +50%)",
                  value: 'auto',
                ),
                Divider(color: MoncarColors.hairline),
                Text(
                  'Vos points expirent le ${formatDateLong(loyalty.expiryDate)} si vous restez inactif.',
                  style: TextStyle(fontSize: 11, color: MoncarColors.inkMut),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          const MoncarSectionHeader(title: 'Comparer les niveaux'),
          for (final t in LoyaltyTier.values) ...[
            _TierColumn(tier: t, isCurrent: t == userTier),
            const SizedBox(height: 8),
          ],
          const SizedBox(height: 4),
          Text(
            "Plus votre niveau est élevé, plus vous cumulez d'avantages exclusifs.",
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 11, color: MoncarColors.inkMut),
          ),
        ],
      ),
    );
  }
}

class _TierCard extends StatefulWidget {
  const _TierCard({required this.loyalty});

  final Loyalty loyalty;

  @override
  State<_TierCard> createState() => _TierCardState();
}

class _TierCardState extends State<_TierCard>
    with SingleTickerProviderStateMixin {
  late final AnimationController _shine = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 4500),
  )..repeat();

  @override
  void dispose() {
    _shine.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l = widget.loyalty;
    final white70 = Colors.white.withValues(alpha: 0.7);
    final next = l.nextTier;
    return MoncarCard(
      padding: EdgeInsets.zero,
      child: Column(
        children: [
          ClipRRect(
            borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
            child: Container(
              decoration: brandGradientDecoration(),
              child: Stack(
                children: [
                  Positioned(
                    top: -40,
                    right: -40,
                    child: Container(
                      width: 160,
                      height: 160,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: MoncarColors.accent.withValues(alpha: 0.25),
                        boxShadow: [
                          BoxShadow(
                            color: MoncarColors.accent.withValues(alpha: 0.25),
                            blurRadius: 40,
                          ),
                        ],
                      ),
                    ),
                  ),
                  // Reflet animé (« shine sweep »).
                  Positioned.fill(
                    child: AnimatedBuilder(
                      animation: _shine,
                      builder: (context, _) {
                        final t = (_shine.value / 0.6).clamp(0.0, 1.0);
                        return FractionalTranslation(
                          translation: Offset(-1.2 + 3.4 * t, 0),
                          child: Transform(
                            transform: Matrix4.skewX(-0.2),
                            child: Container(
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  colors: [
                                    Colors.transparent,
                                    Colors.white.withValues(alpha: 0.07),
                                    Colors.transparent,
                                  ],
                                  stops: const [0, 0.45, 0.6],
                                ),
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            MoncarBadge(
                              label: 'Programme fidélité',
                              icon: Icons.workspace_premium_outlined,
                              size: MoncarBadgeSize.sm,
                              backgroundColor: Colors.white.withValues(
                                alpha: 0.2,
                              ),
                              textColor: Colors.white,
                            ),
                            const Spacer(),
                            Container(
                              width: 48,
                              height: 48,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: Colors.white.withValues(alpha: 0.15),
                              ),
                              child: Icon(
                                Icons.emoji_events,
                                size: 24,
                                color: MoncarColors.accent,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        OverlineText('Votre niveau', color: white70),
                        Text(
                          l.tier.label,
                          style: const TextStyle(
                            fontSize: 34,
                            height: 1.2,
                            fontWeight: FontWeight.w800,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(height: 12),
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                OverlineText('Solde de points', color: white70),
                                Text(
                                  formatNumber(l.points),
                                  style: const TextStyle(
                                    fontSize: 28,
                                    height: 1,
                                    fontWeight: FontWeight.w800,
                                    color: Colors.white,
                                  ),
                                ),
                              ],
                            ),
                            const Spacer(),
                            if (next != null)
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  OverlineText(
                                    'Niveau suivant',
                                    color: white70,
                                  ),
                                  Text(
                                    next.label,
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w700,
                                      color: MoncarColors.accent2,
                                    ),
                                  ),
                                ],
                              ),
                          ],
                        ),
                        if (next != null) ...[
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              Text(
                                'Progression',
                                style: TextStyle(
                                  fontSize: 10,
                                  color: Colors.white.withValues(alpha: 0.8),
                                ),
                              ),
                              const Spacer(),
                              Text(
                                '${l.progressPct}%',
                                style: const TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.white,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          ClipRRect(
                            borderRadius: BorderRadius.circular(999),
                            child: Container(
                              height: 8,
                              color: Colors.white.withValues(alpha: 0.15),
                              alignment: Alignment.centerLeft,
                              child: FractionallySizedBox(
                                widthFactor: (l.progressPct / 100)
                                    .clamp(0, 1)
                                    .toDouble(),
                                child: Container(
                                  decoration: accentGradientDecoration(),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 6),
                          Row(
                            children: [
                              Icon(
                                Icons.trending_up,
                                size: 12,
                                color: Colors.white.withValues(alpha: 0.85),
                              ),
                              const SizedBox(width: 4),
                              Expanded(
                                child: RichText(
                                  text: TextSpan(
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: Colors.white.withValues(
                                        alpha: 0.85,
                                      ),
                                    ),
                                    children: [
                                      const TextSpan(text: 'Plus que '),
                                      TextSpan(
                                        text: formatNumber(l.pointsToNextTier),
                                        style: const TextStyle(
                                          fontWeight: FontWeight.w700,
                                          color: Colors.white,
                                        ),
                                      ),
                                      TextSpan(
                                        text: ' pts pour passer ${next.label}.',
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Icon(
                              Icons.military_tech_outlined,
                              size: 12,
                              color: Colors.white.withValues(alpha: 0.8),
                            ),
                            const SizedBox(width: 6),
                            Text(
                              "Points valables jusqu'au ${formatDateLong(l.expiryDate)}.",
                              style: TextStyle(
                                fontSize: 11,
                                color: Colors.white.withValues(alpha: 0.8),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _Stat(
                  label: 'Niveau',
                  value: l.tier.label,
                  color: _tierAccent[l.tier],
                ),
                VerticalDivider(width: 1, color: MoncarColors.hairline),
                _Stat(label: 'Pts', value: formatNumber(l.points)),
                VerticalDivider(width: 1, color: MoncarColors.hairline),
                _Stat(label: 'Récompenses', value: '${l.rewards.length}'),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat({required this.label, required this.value, this.color});

  final String label;
  final String value;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          children: [
            OverlineText(label),
            const SizedBox(height: 2),
            Text(
              value,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: color ?? MoncarColors.ink,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _RewardCard extends StatelessWidget {
  const _RewardCard({
    required this.reward,
    required this.userTier,
    required this.userPoints,
    required this.onExchange,
  });

  final LoyaltyReward reward;
  final LoyaltyTier userTier;
  final int userPoints;
  final VoidCallback onExchange;

  @override
  Widget build(BuildContext context) {
    final r = reward;
    final tierOk = loyaltyTierRank(userTier) >= loyaltyTierRank(r.tierMin);
    final pointsOk = userPoints >= r.pointCost;
    final canAfford = tierOk && pointsOk;
    final c = hexColor(r.imageColor);

    final button = MoncarButton(
      label: canAfford
          ? 'Échanger (${r.pointCost} pts)'
          : !pointsOk
          ? 'Points insuffisants'
          : 'Niveau ${r.tierMin.label} requis',
      icon: canAfford ? Icons.card_giftcard : null,
      variant: canAfford
          ? MoncarButtonVariant.primary
          : MoncarButtonVariant.outline,
      size: MoncarButtonSize.md,
      expand: true,
      onPressed: canAfford ? onExchange : null,
    );

    return MoncarCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [c, c.withValues(alpha: 0.8)],
                  ),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(_rewardIcon(r.type), size: 24, color: Colors.white),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Wrap(
                      spacing: 6,
                      runSpacing: 4,
                      children: [
                        MoncarBadge(
                          label: _rewardTypeLabel(r.type),
                          size: MoncarBadgeSize.sm,
                        ),
                        MoncarBadge(
                          label: '${r.tierMin.label}+',
                          tone: r.tierMin == LoyaltyTier.standard
                              ? MoncarBadgeTone.neutral
                              : MoncarBadgeTone.warn,
                          size: MoncarBadgeSize.sm,
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      r.title,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: MoncarColors.ink,
                      ),
                    ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  const OverlineText('Coût'),
                  Text(
                    '${r.pointCost}',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      color: MoncarColors.brand,
                    ),
                  ),
                  Text(
                    'PTS',
                    style: TextStyle(fontSize: 9, color: MoncarColors.inkMut),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            r.description,
            style: TextStyle(
              fontSize: 12,
              height: 1.35,
              color: MoncarColors.inkMut,
            ),
          ),
          const SizedBox(height: 12),
          if (canAfford)
            button
          else
            Tooltip(
              message: !pointsOk
                  ? 'Il vous manque ${formatNumber(r.pointCost - userPoints)} pts'
                  : 'Passez ${r.tierMin.label} pour débloquer',
              triggerMode: TooltipTriggerMode.tap,
              decoration: BoxDecoration(
                color: MoncarColors.danger,
                borderRadius: BorderRadius.circular(8),
              ),
              child: button,
            ),
        ],
      ),
    );
  }
}

class _HistoryItem extends StatelessWidget {
  const _HistoryItem({required this.m, required this.isLast});

  final LoyaltyPointMovement m;
  final bool isLast;

  @override
  Widget build(BuildContext context) {
    final isGain = m.type == 'gain';
    final isSpend = m.type == 'spend';
    final (color, bg) = isGain
        ? (MoncarColors.success, MoncarColors.successSoft)
        : isSpend
        ? (MoncarColors.accent, MoncarColors.accentSoft)
        : (MoncarColors.inkFaint, MoncarColors.muted);
    final points = isGain
        ? '+${formatNumber(m.points)}'
        : '−${formatNumber(m.points.abs())}';
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Column(
            children: [
              Container(
                width: 28,
                height: 28,
                decoration: BoxDecoration(color: bg, shape: BoxShape.circle),
                child: Icon(
                  isGain ? Icons.arrow_upward : Icons.arrow_downward,
                  size: 14,
                  color: color,
                ),
              ),
              if (!isLast)
                Expanded(
                  child: Container(
                    width: 2,
                    constraints: const BoxConstraints(minHeight: 24),
                    color: MoncarColors.hairline,
                  ),
                ),
            ],
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Padding(
              padding: EdgeInsets.only(bottom: isLast ? 0 : 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Text(
                          m.reason,
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: MoncarColors.ink,
                          ),
                        ),
                      ),
                      Text(
                        points,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: color,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${isGain
                        ? 'Gain'
                        : isSpend
                        ? 'Débit'
                        : 'Expiration'} • ${timeAgo(m.at)}',
                    style: TextStyle(fontSize: 11, color: MoncarColors.inkMut),
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

class _EarnRow extends StatelessWidget {
  const _EarnRow({
    required this.icon,
    required this.color,
    required this.bg,
    required this.text,
    required this.value,
  });

  final IconData icon;
  final Color color;
  final Color bg;
  final String text;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          IconTile(
            icon: icon,
            color: color,
            background: bg,
            size: 32,
            radius: 16,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: TextStyle(fontSize: 13, color: MoncarColors.ink),
            ),
          ),
          Text(
            value,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: MoncarColors.brand,
            ),
          ),
        ],
      ),
    );
  }
}

class _TierColumn extends StatelessWidget {
  const _TierColumn({required this.tier, required this.isCurrent});

  final LoyaltyTier tier;
  final bool isCurrent;

  @override
  Widget build(BuildContext context) {
    final accent = _tierAccent[tier]!;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: MoncarColors.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isCurrent
              ? MoncarColors.accent.withValues(alpha: 0.6)
              : MoncarColors.hairline,
          width: isCurrent ? 2 : 1,
        ),
      ),
      child: Column(
        children: [
          IconTile(
            icon: Icons.emoji_events_outlined,
            color: accent,
            background: accent.withValues(alpha: 0.13),
            size: 40,
            radius: 20,
          ),
          const SizedBox(height: 6),
          Text(
            tier.label,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: accent,
            ),
          ),
          Text(
            'Dès ${formatNumber(_tierThreshold[tier]!)} pts',
            style: TextStyle(fontSize: 10, color: MoncarColors.inkMut),
          ),
          if (isCurrent) ...[
            const SizedBox(height: 6),
            const MoncarBadge(
              label: 'Vous',
              tone: MoncarBadgeTone.accent,
              size: MoncarBadgeSize.sm,
            ),
          ],
          const SizedBox(height: 12),
          for (final b in _tierBenefits[tier]!)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Icon(Icons.check, size: 12, color: accent),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      b,
                      style: TextStyle(
                        fontSize: 11,
                        height: 1.35,
                        color: MoncarColors.ink,
                      ),
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
