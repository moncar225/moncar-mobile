import 'package:flutter/material.dart';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../auth/presentation/payment_otp_sheet.dart';
import '../../shared/foundation.dart';
import '../widgets/location_widgets.dart';

enum _Stage { ready, paying, failed }

/// Paiement sécurisé d'une location (§39) — uniquement après la
/// confirmation du fournisseur (règle 10), ou règlement d'une facture
/// complémentaire (prolongation, heures supplémentaires).
class RentalPaymentPage extends ConsumerStatefulWidget {
  const RentalPaymentPage({super.key, required this.rentalId});

  final String rentalId;

  @override
  ConsumerState<RentalPaymentPage> createState() => _RentalPaymentPageState();
}

class _RentalPaymentPageState extends ConsumerState<RentalPaymentPage> {
  PaymentMethod _method = PaymentMethod.orangeMoney;
  _Stage _stage = _Stage.ready;
  String? _error;

  Future<void> _pay(int amount) async {
    final confirmed = await confirmPaymentWithOtp(
      context,
      ref,
      amountXOF: amount,
    );
    if (!confirmed || !mounted) return;
    setState(() {
      _stage = _Stage.paying;
      _error = null;
    });
    final store = ref.read(mockStoreProvider);
    // ⚠️ MOCK : POST /payments puis attente du retour signé du PSP.
    final created = store.createPayment(
      rentalId: widget.rentalId,
      method: _method,
      idempotencyKey: generateIdempotencyKey(),
    );
    final pm = created.payment;
    if (!created.ok || pm == null) {
      setState(() {
        _stage = _Stage.failed;
        _error = created.error ?? 'Paiement impossible.';
      });
      return;
    }
    Payment? result;
    for (var i = 0; i < 6; i++) {
      await Future<void>.delayed(const Duration(milliseconds: 1200));
      if (!mounted) return;
      store.processPayment(pm.id);
      final p = store.findPayment(pm.id);
      if (p != null && p.status != PaymentStatus.enAttente) {
        result = p;
        break;
      }
    }
    if (!mounted) return;
    if (result?.status == PaymentStatus.paye) {
      showMoncarToast(context, 'Paiement confirmé', success: true);
      context.pop();
      return;
    }
    setState(() {
      _stage = _Stage.failed;
      _error = result?.status == PaymentStatus.echoue
          ? (result?.failureReason ?? 'Le paiement a échoué.')
          : "Le paiement n'a pas pu être confirmé à temps. Réessayez.";
    });
  }

  @override
  Widget build(BuildContext context) {
    final r = ref.watch(mockStoreProvider).findRental(widget.rentalId);
    final charge = r?.pendingCharge;
    final payable =
        r != null && (r.status == RentalStatus.confirmee || charge != null);
    if (!payable) {
      return Scaffold(
        appBar: const TopBar(title: 'Paiement', showBack: true),
        body: MoncarEmptyState(
          icon: Icons.lock_outline,
          title: 'Aucun paiement à effectuer',
          message:
              'Le paiement n\'est possible qu\'après la confirmation du fournisseur.',
          actionLabel: 'Retour',
          onAction: () => context.mcBack(),
        ),
      );
    }
    final isInitial = r.status == RentalStatus.confirmee;
    final amount = isInitial ? r.quote.totalXOF : charge!.amountXOF;
    final methods = PAYMENT_METHODS
        .where((m) => m.method != PaymentMethod.especes)
        .toList();

    return Scaffold(
      backgroundColor: MoncarColors.background,
      appBar: TopBar(
        title: isInitial ? 'Paiement de la location' : 'Facture complémentaire',
        subtitle: r.reference,
        showBack: _stage != _Stage.paying,
        showBell: false,
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
        children: [
          if (isInitial)
            RentalInvoiceCard(quote: r.quote, title: r.vehicleSummary)
          else
            MoncarCard(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    charge!.label,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: MoncarColors.ink,
                    ),
                  ),
                  const SizedBox(height: 8),
                  for (final l in charge.lines)
                    RecapRow(label: l.label, value: formatXOF(l.amountXOF)),
                  Divider(color: MoncarColors.hairline),
                  RecapRow(
                    label: 'TOTAL À PAYER',
                    value: formatXOF(charge.amountXOF),
                    bold: true,
                  ),
                ],
              ),
            ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: MoncarColors.successSoft.withValues(alpha: 0.6),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  Icons.shield_outlined,
                  size: 16,
                  color: MoncarColors.success,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Paiement sécurisé : le fournisseur n\'est réglé qu\'après la '
                    'remise du véhicule et votre validation.',
                    style: TextStyle(
                      fontSize: 12,
                      height: 1.45,
                      color: MoncarColors.inkMut,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          const MoncarSectionHeader(title: 'Moyen de paiement'),
          for (final m in methods) ...[
            _MethodTile(
              meta: m,
              selected: _method == m.method,
              enabled: _stage != _Stage.paying,
              onTap: () => setState(() => _method = m.method),
            ),
            const SizedBox(height: 8),
          ],
          if (_error != null) ...[
            const SizedBox(height: 4),
            MoncarInlineError(message: _error!),
          ],
        ],
      ),
      bottomNavigationBar: StickyBottomBar(
        child: MoncarButton(
          label: _stage == _Stage.paying
              ? 'Paiement en cours…'
              : 'Payer ${formatXOF(amount)}',
          icon: Icons.lock_outline,
          variant: MoncarButtonVariant.primary,
          size: MoncarButtonSize.xl,
          expand: true,
          isLoading: _stage == _Stage.paying,
          onPressed: _stage == _Stage.paying ? null : () => _pay(amount),
        ),
      ),
    );
  }
}

class _MethodTile extends StatelessWidget {
  const _MethodTile({
    required this.meta,
    required this.selected,
    required this.enabled,
    required this.onTap,
  });

  final PaymentMethodMeta meta;
  final bool selected;
  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: enabled ? onTap : null,
      borderRadius: BorderRadius.circular(14),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: selected
              ? MoncarColors.accentSoft.withValues(alpha: 0.4)
              : MoncarColors.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: selected ? MoncarColors.accent : MoncarColors.hairline,
            width: 2,
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: hexColor(meta.color),
                shape: BoxShape.circle,
              ),
              child: Text(
                meta.icon,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                  color: meta.textDark ? MoncarColors.ink : Colors.white,
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    meta.label,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: MoncarColors.ink,
                    ),
                  ),
                  Text(
                    meta.desc,
                    style: TextStyle(fontSize: 11, color: MoncarColors.inkMut),
                  ),
                ],
              ),
            ),
            Icon(
              selected ? Icons.radio_button_checked : Icons.radio_button_off,
              color: selected ? MoncarColors.accent : MoncarColors.inkFaint,
            ),
          ],
        ),
      ),
    );
  }
}
