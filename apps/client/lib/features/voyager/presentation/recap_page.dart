import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../shared/foundation.dart';
import '../widgets/voyager_widgets.dart';

/// Récapitulatif de réservation : trajet, passagers, code promo et
/// détail du prix (totaux calculés et verrouillés par le serveur).
class RecapPage extends ConsumerStatefulWidget {
  const RecapPage({super.key, required this.bookingId});

  final String bookingId;

  @override
  ConsumerState<RecapPage> createState() => _RecapPageState();
}

class _RecapPageState extends ConsumerState<RecapPage> {
  final _promo = TextEditingController();
  bool _validating = false;
  PromoValidation? _validation;

  @override
  void dispose() {
    _promo.dispose();
    super.dispose();
  }

  Future<void> _applyPromo(Booking booking) async {
    final code = _promo.text.trim();
    if (code.isEmpty) return;
    setState(() => _validating = true);
    // ⚠️ MOCK : GET /promotions/validate.
    await Future<void>.delayed(const Duration(milliseconds: 400));
    if (!mounted) return;
    final r = ref
        .read(mockStoreProvider)
        .validatePromo(
          code,
          booking.amountXOF + booking.feesXOF,
          PromoService.voyager,
        );
    setState(() {
      _validating = false;
      _validation = r;
    });
    if (r.valid) {
      ref
          .read(bookingDraftProvider.notifier)
          .update((d) => d.copyWith(promoCode: code));
      showMoncarToast(
        context,
        'Promo appliquée: -${formatXOF(r.discountXOF)}',
        success: true,
      );
    } else {
      showMoncarToast(context, r.message, error: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    ref.watch(mockStoreChangesProvider);
    final booking = ref.read(mockStoreProvider).findBooking(widget.bookingId);
    if (booking == null) {
      return Scaffold(
        appBar: const TopBar(
          title: 'Récapitulatif',
          showBack: true,
          showBell: false,
        ),
        body: MoncarErrorState(
          message: 'Réservation introuvable',
          onRetry: () => setState(() {}),
        ),
      );
    }
    final seatCount = booking.seats.length;
    final v = _validation;

    return Scaffold(
      backgroundColor: MoncarColors.background,
      appBar: TopBar(
        title: 'Récapitulatif',
        subtitle: booking.reference,
        showBack: true,
        showBell: false,
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
        children: [
          if (booking.returnLeg != null) const SectionTitle('Aller'),
          MoncarCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      decoration: brandGradientDecoration(
                        radius: BorderRadius.circular(8),
                      ),
                      child: const Icon(
                        Icons.directions_bus,
                        size: 20,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          booking.companyName,
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: MoncarColors.ink,
                          ),
                        ),
                        Text(
                          'Réf. ${booking.reference}',
                          style: TextStyle(
                            fontSize: 11,
                            color: MoncarColors.inkMut,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: _Endpoint(
                        time: booking.departureTime,
                        place: booking.originStop.split('—').first.trim(),
                      ),
                    ),
                    Expanded(
                      child: Column(
                        children: [
                          Text(
                            booking.tripSummary,
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 10,
                              color: MoncarColors.inkFaint,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              Container(
                                width: 8,
                                height: 8,
                                decoration: BoxDecoration(
                                  color: MoncarColors.brand,
                                  shape: BoxShape.circle,
                                ),
                              ),
                              const Expanded(child: DashedLine()),
                              Icon(
                                Icons.arrow_forward,
                                size: 14,
                                color: MoncarColors.accent,
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    Expanded(
                      child: _Endpoint(
                        time: booking.arrivalTime,
                        place: booking.destinationStop.split('—').first.trim(),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Divider(height: 1, color: MoncarColors.hairline),
                const SizedBox(height: 12),
                _InfoLine(
                  icon: Icons.calendar_today_outlined,
                  text: formatDateFull(booking.date),
                ),
                _InfoLine(
                  icon: Icons.place_outlined,
                  text: '${booking.originStop} → ${booking.destinationStop}',
                ),
                _InfoLine(
                  icon: Icons.confirmation_number_outlined,
                  text:
                      '$seatCount siège${seatCount > 1 ? 's' : ''}: ${booking.seats.join(', ')}',
                ),
              ],
            ),
          ),
          if (booking.returnLeg case final leg?) ...[
            const SizedBox(height: 16),
            const SectionTitle('Retour'),
            ReturnLegCard(leg: leg),
          ],
          const SizedBox(height: 16),
          const SectionTitle('Passagers'),
          for (final p in booking.passengers) ...[
            MoncarCard(
              padding: const EdgeInsets.all(14),
              child: Row(
                children: [
                  IconTile(
                    icon: Icons.person_outline,
                    background: MoncarColors.brandSoft,
                    size: 36,
                    radius: 18,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${p.firstName} ${p.lastName}',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: MoncarColors.ink,
                          ),
                        ),
                        Text(
                          '${p.phone} · ${p.type.name}',
                          style: TextStyle(
                            fontSize: 11,
                            color: MoncarColors.inkMut,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (p.seatNumber != null)
                    MoncarBadge(
                      label: booking.returnLeg == null
                          ? 'Siège ${p.seatNumber}'
                          : 'Aller ${p.seatNumber} · Retour '
                                '${booking.returnLeg!.seats.elementAtOrNull(booking.passengers.indexOf(p)) ?? '—'}',
                      tone: MoncarBadgeTone.accent,
                      size: MoncarBadgeSize.sm,
                    ),
                ],
              ),
            ),
            const SizedBox(height: 8),
          ],
          const SizedBox(height: 8),
          const SectionTitle('Code promotionnel'),
          MoncarCard(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: MoncarTextField(
                        controller: _promo,
                        hint: 'MONCAR20',
                        prefixIcon: Icons.sell_outlined,
                        textCapitalization: TextCapitalization.characters,
                        inputFormatters: [_UpperCaseFormatter()],
                        onChanged: (_) => setState(() {}),
                      ),
                    ),
                    const SizedBox(width: 8),
                    MoncarButton(
                      label: 'Appliquer',
                      variant: MoncarButtonVariant.brand,
                      size: MoncarButtonSize.md,
                      isLoading: _validating,
                      onPressed: _promo.text.trim().isEmpty
                          ? null
                          : () => _applyPromo(booking),
                    ),
                  ],
                ),
                if (v != null) ...[
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: v.valid
                          ? MoncarColors.successSoft
                          : MoncarColors.dangerSoft,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          v.valid ? Icons.check : Icons.close,
                          size: 14,
                          color: v.valid
                              ? MoncarColors.success
                              : MoncarColors.danger,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            v.message,
                            style: TextStyle(
                              fontSize: 12,
                              color: v.valid
                                  ? MoncarColors.success
                                  : MoncarColors.danger,
                            ),
                          ),
                        ),
                        if (v.valid)
                          Text(
                            '-${formatXOF(v.discountXOF)}',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: MoncarColors.success,
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
                const SizedBox(height: 8),
                Text(
                  'Astuce: essayez MONCAR20 ou BIENVENUE',
                  style: TextStyle(fontSize: 10, color: MoncarColors.inkFaint),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          const SectionTitle('Détail du prix'),
          MoncarCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                RecapRow(
                  label: 'Billets ($seatCount)',
                  value: formatXOF(booking.amountXOF),
                ),
                RecapRow(
                  label: 'Frais de service',
                  value: formatXOF(booking.feesXOF),
                ),
                if (booking.discountXOF > 0)
                  RecapRow(
                    label: 'Réduction',
                    value: '-${formatXOF(booking.discountXOF)}',
                    valueColor: MoncarColors.success,
                  ),
                Divider(color: MoncarColors.hairline),
                Row(
                  children: [
                    Text(
                      'Total',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: MoncarColors.ink,
                      ),
                    ),
                    const Spacer(),
                    Text(
                      formatXOF(booking.totalXOF),
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                        color: MoncarColors.accent,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    Icon(Icons.check, size: 12, color: MoncarColors.success),
                    SizedBox(width: 6),
                    Text(
                      'Montant calculé et verrouillé par le serveur',
                      style: TextStyle(
                        fontSize: 10,
                        color: MoncarColors.inkFaint,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          MoncarCard(
            padding: const EdgeInsets.all(14),
            color: MoncarColors.brandSoft.withValues(alpha: 0.3),
            child: RichText(
              text: TextSpan(
                style: TextStyle(fontSize: 12, color: MoncarColors.inkMut),
                children: [
                  TextSpan(
                    text:
                        'Annulation ${cancellationLabel(booking.cancellationPolicy)}. ',
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      color: MoncarColors.brand,
                    ),
                  ),
                  TextSpan(
                    text: switch (booking.cancellationPolicy) {
                      CancellationPolicy.flexible =>
                        "Remboursement intégral jusqu'à 24h avant le départ.",
                      CancellationPolicy.modere =>
                        "Remboursement à 50% jusqu'à 12h avant le départ.",
                      CancellationPolicy.strict =>
                        'Pas de remboursement possible.',
                    },
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
      bottomNavigationBar: StickyBottomBar(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const OverlineText('À payer'),
                    Text(
                      formatXOF(booking.totalXOF),
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: MoncarColors.ink,
                      ),
                    ),
                  ],
                ),
                const Spacer(),
                const MoncarBadge(
                  label: 'Réservation valable 15 min',
                  tone: MoncarBadgeTone.warn,
                  size: MoncarBadgeSize.sm,
                ),
              ],
            ),
            const SizedBox(height: 8),
            MoncarButton(
              label: 'Payer maintenant',
              icon: Icons.arrow_forward,
              variant: MoncarButtonVariant.primary,
              size: MoncarButtonSize.lg,
              expand: true,
              onPressed: () => context.push('/voyager/payment/${booking.id}'),
            ),
          ],
        ),
      ),
    );
  }
}

class _UpperCaseFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) => newValue.copyWith(text: newValue.text.toUpperCase());
}

class _Endpoint extends StatelessWidget {
  const _Endpoint({required this.time, required this.place});

  final String time;
  final String place;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          time,
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: MoncarColors.ink,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          place,
          textAlign: TextAlign.center,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(fontSize: 11, color: MoncarColors.inkMut),
        ),
      ],
    );
  }
}

class _InfoLine extends StatelessWidget {
  const _InfoLine({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 14, color: MoncarColors.inkMut),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: TextStyle(fontSize: 12, color: MoncarColors.inkMut),
            ),
          ),
        ],
      ),
    );
  }
}
