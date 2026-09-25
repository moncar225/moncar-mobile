import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../shared/foundation.dart';
import '../widgets/promo_widgets.dart';

enum _Filter { tous, voyager, colis, location, fidelite }

const _filters = [
  (key: _Filter.tous, label: 'Tous'),
  (key: _Filter.voyager, label: 'Voyager'),
  (key: _Filter.colis, label: 'Colis'),
  (key: _Filter.location, label: 'Location'),
  (key: _Filter.fidelite, label: 'Fidélité'),
];

/// Liste des promotions : filtres, carrousel « À la une », liste
/// complète et vérification d'un code (réponse serveur uniquement).
class PromotionsPage extends ConsumerStatefulWidget {
  const PromotionsPage({super.key});

  @override
  ConsumerState<PromotionsPage> createState() => _PromotionsPageState();
}

class _PromotionsPageState extends ConsumerState<PromotionsPage> {
  _Filter _filter = _Filter.tous;

  List<Promotion> _apply(List<Promotion> all) => switch (_filter) {
    _Filter.tous => all,
    // Promo Fidélité = réservées aux membres Argent / Or / VIP.
    _Filter.fidelite =>
      all.where((p) => p.minTier != LoyaltyTier.standard).toList(),
    _ => all.where((p) {
      final s = switch (_filter) {
        _Filter.voyager => PromoService.voyager,
        _Filter.colis => PromoService.colis,
        _ => PromoService.location,
      };
      return p.service == s || p.service == PromoService.tous;
    }).toList(),
  };

  void _openCodeSheet() {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: MoncarColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => const _ValidatePromoSheet(),
    );
  }

  @override
  Widget build(BuildContext context) {
    ref.watch(mockStoreChangesProvider);
    final all = ref.read(mockStoreProvider).promotions;
    final featured = all.where((p) => p.featured).toList();
    final filtered = _apply(all);

    return Scaffold(
      backgroundColor: MoncarColors.background,
      appBar: const TopBar(
        title: 'Promotions',
        showBack: true,
        showBell: false,
      ),
      body: ListView(
        padding: const EdgeInsets.only(bottom: 40),
        children: [
          Container(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
            decoration: accentGradientDecoration(
              radius: const BorderRadius.vertical(bottom: Radius.circular(28)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                MoncarBadge(
                  label: 'Offres',
                  icon: Icons.card_giftcard,
                  size: MoncarBadgeSize.sm,
                  backgroundColor: Colors.white.withValues(alpha: 0.2),
                  textColor: Colors.white,
                ),
                const SizedBox(height: 8),
                const Text(
                  'Offres du moment',
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Économisez sur vos trajets, colis et locations.',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.white.withValues(alpha: 0.85),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          SizedBox(
            height: 36,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              children: [
                for (final f in _filters) ...[
                  MoncarChip(
                    label: f.label,
                    active: _filter == f.key,
                    onTap: () => setState(() => _filter = f.key),
                  ),
                  const SizedBox(width: 8),
                ],
              ],
            ),
          ),
          if (_filter == _Filter.tous && featured.isNotEmpty) ...[
            const SizedBox(height: 16),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 16),
              child: MoncarSectionHeader(title: 'À la une'),
            ),
            PromoCarousel(promos: featured),
          ],
          const SizedBox(height: 16),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                MoncarSectionHeader(
                  title: _filter == _Filter.tous
                      ? 'Toutes les promotions'
                      : 'Résultats',
                ),
                if (filtered.isEmpty)
                  const MoncarEmptyState(
                    icon: Icons.card_giftcard,
                    title: 'Aucune promotion',
                    message:
                        'Aucune offre disponible dans cette catégorie pour le moment. Revenez bientôt !',
                  )
                else
                  for (final p in filtered) ...[
                    _PromoListItem(
                      promo: p,
                      onTap: () => context.push('/promotions/${p.id}'),
                    ),
                    const SizedBox(height: 12),
                  ],
                const SizedBox(height: 8),
                MoncarButton(
                  label: 'Saisir un code',
                  icon: Icons.confirmation_number_outlined,
                  variant: MoncarButtonVariant.brand,
                  size: MoncarButtonSize.xl,
                  expand: true,
                  onPressed: _openCodeSheet,
                ),
                const SizedBox(height: 8),
                Text(
                  'Vous avez reçu un code ? Saisissez-le pour vérifier votre réduction.',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 11, color: MoncarColors.inkMut),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _PromoListItem extends StatelessWidget {
  const _PromoListItem({required this.promo, required this.onTap});

  final Promotion promo;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final p = promo;
    final isPct = p.type == PromoType.pourcentage;
    return MoncarCard(
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: MoncarColors.brandSoft,
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            p.code,
                            style: TextStyle(
                              fontSize: 11,
                              fontFamily: 'monospace',
                              fontWeight: FontWeight.w700,
                              letterSpacing: 1,
                              color: MoncarColors.brand,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        MoncarBadge(
                          label: formatPromoValue(p),
                          tone: isPct
                              ? MoncarBadgeTone.accent
                              : MoncarBadgeTone.brand,
                          size: MoncarBadgeSize.sm,
                          icon: isPct ? Icons.percent : Icons.sell_outlined,
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      p.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: MoncarColors.ink,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  gradient: promoGradient(p.imageColor),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.card_giftcard,
                  size: 20,
                  color: Colors.white,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 6,
            runSpacing: 4,
            children: [
              MoncarBadge(
                label: promoServiceLabel(p.service),
                tone: promoServiceTone(p.service),
                size: MoncarBadgeSize.sm,
              ),
              MoncarBadge(
                label: 'Membre ${p.minTier.label}+',
                tone: MoncarBadgeTone.warn,
                size: MoncarBadgeSize.sm,
                icon: Icons.group_outlined,
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Icon(
                Icons.calendar_today_outlined,
                size: 12,
                color: MoncarColors.inkMut,
              ),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  'Du ${formatDateShort(p.validFrom)} au ${formatDateLong(p.validUntil)}',
                  style: TextStyle(fontSize: 11, color: MoncarColors.inkMut),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              const OverlineText('Utilisations'),
              const Spacer(),
              Text(
                '${formatNumber(p.usageCount)} / ${formatNumber(p.usageMax)}',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w500,
                  color: MoncarColors.inkFaint,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          PromoUsageBar(promo: p),
        ],
      ),
    );
  }
}

class _ValidatePromoSheet extends ConsumerStatefulWidget {
  const _ValidatePromoSheet();

  @override
  ConsumerState<_ValidatePromoSheet> createState() =>
      _ValidatePromoSheetState();
}

class _ValidatePromoSheetState extends ConsumerState<_ValidatePromoSheet> {
  static const _presets = [
    (service: PromoService.voyager, label: 'Voyager', amount: 5000),
    (service: PromoService.colis, label: 'Colis', amount: 3000),
    (service: PromoService.location, label: 'Location', amount: 25000),
  ];

  final _code = TextEditingController();
  final _amount = TextEditingController(text: '5000');
  PromoService _service = PromoService.voyager;
  int _baseAmount = 5000;
  PromoValidation? _validation;
  bool _loading = false;

  @override
  void dispose() {
    _code.dispose();
    _amount.dispose();
    super.dispose();
  }

  Future<void> _validate() async {
    final code = _code.text.trim().toUpperCase();
    if (code.isEmpty) {
      showMoncarToast(context, 'Entrez un code promotionnel.', error: true);
      return;
    }
    setState(() {
      _loading = true;
      _validation = null;
    });
    // ⚠️ MOCK : GET /promotions/validate.
    await Future<void>.delayed(const Duration(milliseconds: 400));
    if (!mounted) return;
    final r = ref
        .read(mockStoreProvider)
        .validatePromo(code, _baseAmount, _service);
    setState(() {
      _loading = false;
      _validation = r;
    });
  }

  @override
  Widget build(BuildContext context) {
    final v = _validation;
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: EdgeInsets.fromLTRB(16, 20, 16, 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      Icons.confirmation_number_outlined,
                      size: 16,
                      color: MoncarColors.accent,
                    ),
                    SizedBox(width: 8),
                    Text(
                      'Saisir un code',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: MoncarColors.ink,
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 4),
                Text(
                  "Vérifiez l'éligibilité et la réduction de votre code avant de l'appliquer.",
                  style: TextStyle(fontSize: 12, color: MoncarColors.inkMut),
                ),
              ],
            ),
          ),
          Divider(height: 1, color: MoncarColors.hairline),
          Flexible(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const MoncarLabel('Code promotionnel'),
                  Row(
                    children: [
                      Expanded(
                        child: MoncarTextField(
                          controller: _code,
                          hint: 'MONCAR20',
                          textCapitalization: TextCapitalization.characters,
                          onChanged: (_) => setState(() {}),
                        ),
                      ),
                      const SizedBox(width: 8),
                      IconButton.outlined(
                        tooltip: 'Copier le code',
                        onPressed: _code.text.isEmpty
                            ? null
                            : () => copyWithToast(
                                context,
                                _code.text.trim().toUpperCase(),
                                message: 'Code copié.',
                              ),
                        icon: const Icon(Icons.copy, size: 16),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  const MoncarLabel('Service concerné'),
                  Row(
                    children: [
                      for (var i = 0; i < _presets.length; i++) ...[
                        if (i > 0) const SizedBox(width: 8),
                        Expanded(
                          child: InkWell(
                            onTap: () => setState(() {
                              _service = _presets[i].service;
                              _baseAmount = _presets[i].amount;
                              _amount.text = '$_baseAmount';
                            }),
                            borderRadius: BorderRadius.circular(12),
                            child: Container(
                              padding: const EdgeInsets.symmetric(vertical: 10),
                              alignment: Alignment.center,
                              decoration: BoxDecoration(
                                color: _service == _presets[i].service
                                    ? MoncarColors.accentSoft
                                    : MoncarColors.surface,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: _service == _presets[i].service
                                      ? MoncarColors.accent
                                      : MoncarColors.hairline,
                                  width: 2,
                                ),
                              ),
                              child: Text(
                                _presets[i].label,
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: _service == _presets[i].service
                                      ? MoncarColors.accentInk
                                      : MoncarColors.inkMut,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 16),
                  MoncarTextField(
                    label: 'Montant de base (FCFA)',
                    controller: _amount,
                    keyboardType: TextInputType.number,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    onChanged: (s) => _baseAmount = int.tryParse(s) ?? 0,
                  ),
                  const SizedBox(height: 16),
                  MoncarButton(
                    label: 'Vérifier le code',
                    icon: Icons.check_circle_outline,
                    variant: MoncarButtonVariant.primary,
                    size: MoncarButtonSize.lg,
                    expand: true,
                    isLoading: _loading,
                    onPressed: _code.text.trim().isEmpty ? null : _validate,
                  ),
                  AnimatedSize(
                    duration: const Duration(milliseconds: 250),
                    child: v == null
                        ? const SizedBox(width: double.infinity)
                        : Padding(
                            padding: const EdgeInsets.only(top: 16),
                            child: _ValidationResult(
                              result: v,
                              baseAmount: _baseAmount,
                            ),
                          ),
                  ),
                ],
              ),
            ),
          ),
          Divider(height: 1, color: MoncarColors.hairline),
          SafeArea(
            top: false,
            child: Align(
              alignment: Alignment.centerRight,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                child: TextButton.icon(
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.close, size: 16),
                  label: const Text('Fermer'),
                  style: TextButton.styleFrom(
                    foregroundColor: MoncarColors.brand,
                    textStyle: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ValidationResult extends StatelessWidget {
  const _ValidationResult({required this.result, required this.baseAmount});

  final PromoValidation result;
  final int baseAmount;

  @override
  Widget build(BuildContext context) {
    final r = result;
    if (!r.valid) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: MoncarColors.dangerSoft,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: MoncarColors.danger.withValues(alpha: 0.3),
            width: 2,
          ),
        ),
        child: Row(
          children: [
            IconTile(
              icon: Icons.cancel_outlined,
              color: MoncarColors.danger,
              background: MoncarColors.danger.withValues(alpha: 0.15),
              size: 36,
              radius: 18,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Code refusé',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: MoncarColors.ink,
                    ),
                  ),
                  Text(
                    r.message,
                    style: TextStyle(fontSize: 11, color: MoncarColors.inkMut),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    }
    final saved = baseAmount - r.newTotalXOF;
    Widget cell(String label, String value, Color fg, Color bg) => Expanded(
      child: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Column(
          children: [
            OverlineText(
              label,
              color: fg == MoncarColors.ink ? MoncarColors.inkMut : fg,
            ),
            const SizedBox(height: 2),
            Text(
              value,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: fg,
              ),
            ),
          ],
        ),
      ),
    );
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: MoncarColors.successSoft,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: MoncarColors.success.withValues(alpha: 0.3),
          width: 2,
        ),
      ),
      child: Column(
        children: [
          Row(
            children: [
              IconTile(
                icon: Icons.check_circle_outline,
                color: MoncarColors.success,
                background: MoncarColors.success.withValues(alpha: 0.15),
                size: 36,
                radius: 18,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Code valide !',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: MoncarColors.ink,
                      ),
                    ),
                    Text(
                      r.message,
                      style: TextStyle(
                        fontSize: 11,
                        color: MoncarColors.inkMut,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              cell(
                'Base',
                formatXOF(baseAmount),
                MoncarColors.ink,
                Colors.white.withValues(alpha: 0.7),
              ),
              const SizedBox(width: 8),
              cell(
                'Réduction',
                '−${formatXOF(r.discountXOF)}',
                MoncarColors.success,
                MoncarColors.success.withValues(alpha: 0.15),
              ),
              const SizedBox(width: 8),
              cell(
                'À payer',
                formatXOF(r.newTotalXOF),
                MoncarColors.brand,
                MoncarColors.brandSoft,
              ),
            ],
          ),
          const SizedBox(height: 12),
          RichText(
            textAlign: TextAlign.center,
            text: TextSpan(
              style: TextStyle(fontSize: 11, color: MoncarColors.inkMut),
              children: [
                const TextSpan(text: 'Vous économisez '),
                TextSpan(
                  text: formatXOF(saved),
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    color: MoncarColors.success,
                  ),
                ),
                const TextSpan(text: ' sur cet achat.'),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
