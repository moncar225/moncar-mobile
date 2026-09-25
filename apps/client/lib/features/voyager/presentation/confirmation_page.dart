import 'package:flutter/material.dart';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../shared/foundation.dart';

/// Confirmation après paiement : récapitulatif, prochaines étapes et
/// accès au billet QR / au suivi GPS.
class ConfirmationPage extends ConsumerWidget {
  const ConfirmationPage({super.key, required this.bookingId});

  final String bookingId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.watch(mockStoreChangesProvider);
    final store = ref.read(mockStoreProvider);
    final booking = store.findBooking(bookingId);
    // Billet de l'aller (ou du trajet simple) ; le retour a le sien.
    final ticket = booking?.ticketId == null
        ? null
        : store.findTicket(booking!.ticketId!);
    final returnTicketId = booking?.returnLeg?.ticketId;

    if (booking == null) {
      return const Scaffold(
        appBar: TopBar(title: 'Confirmation', showBell: false),
        body: Padding(
          padding: EdgeInsets.all(16),
          child: MoncarSkeleton(height: 384),
        ),
      );
    }
    final pax = booking.passengers.length;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) context.go('/home');
      },
      child: Scaffold(
        backgroundColor: MoncarColors.background,
        appBar: const TopBar(title: 'Confirmation', showBell: false),
        body: ListView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              clipBehavior: Clip.antiAlias,
              decoration: brandGradientDecoration(
                radius: BorderRadius.circular(24),
              ),
              child: Column(
                children: [
                  Container(
                    width: 80,
                    height: 80,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.white.withValues(alpha: 0.15),
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.3),
                        width: 2,
                      ),
                    ),
                    child: const Icon(
                      Icons.check,
                      size: 40,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Voyage confirmé !',
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Votre billet a été généré et signé par le serveur.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 13,
                      color: Colors.white.withValues(alpha: 0.8),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        MonCarLogo(size: 20),
                        SizedBox(width: 8),
                        Text(
                          'MON CAR',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: Colors.white,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            MoncarCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      const MoncarBadge(
                        label: 'Payé',
                        tone: MoncarBadgeTone.success,
                        icon: Icons.check,
                      ),
                      const Spacer(),
                      Text(
                        booking.reference,
                        style: TextStyle(
                          fontSize: 11,
                          color: MoncarColors.inkFaint,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
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
                      Expanded(
                        child: Column(
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
                              booking.tripSummary,
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
                  Divider(height: 1, color: MoncarColors.hairline),
                  const SizedBox(height: 12),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: _Cell(
                          label: 'Départ',
                          value: booking.departureTime,
                          sub: booking.originStop.split('—').first.trim(),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _Cell(
                          label: 'Siège(s)',
                          value: booking.seats.join(', '),
                          sub: '$pax passager${pax > 1 ? 's' : ''}',
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Divider(height: 1, color: MoncarColors.hairline),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Text(
                        'Total payé',
                        style: TextStyle(
                          fontSize: 13,
                          color: MoncarColors.inkMut,
                        ),
                      ),
                      const Spacer(),
                      Text(
                        formatXOF(booking.totalXOF),
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: MoncarColors.accent,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Padding(
              padding: EdgeInsets.fromLTRB(4, 0, 4, 12),
              child: Text(
                'Prochaines étapes',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: MoncarColors.ink,
                ),
              ),
            ),
            for (final s in [
              (
                icon: Icons.confirmation_number_outlined,
                title: 'Votre billet QR',
                desc: "Présentez-le à l'embarquement",
                color: MoncarColors.accent,
                bg: MoncarColors.accentSoft,
              ),
              (
                icon: Icons.place_outlined,
                title: 'Suivi GPS',
                desc: 'Suivez votre bus en temps réel',
                color: MoncarColors.brand,
                bg: MoncarColors.brandSoft,
              ),
              (
                icon: Icons.calendar_today_outlined,
                title: 'Rappel de départ',
                desc: 'Notification 1h avant le départ',
                color: MoncarColors.success,
                bg: MoncarColors.successSoft,
              ),
            ]) ...[
              MoncarCard(
                padding: const EdgeInsets.all(12),
                child: Row(
                  children: [
                    IconTile(
                      icon: s.icon,
                      color: s.color,
                      background: s.bg,
                      radius: 20,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            s.title,
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: MoncarColors.ink,
                            ),
                          ),
                          Text(
                            s.desc,
                            style: TextStyle(
                              fontSize: 11,
                              color: MoncarColors.inkMut,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Icon(Icons.check, size: 16, color: MoncarColors.success),
                  ],
                ),
              ),
              const SizedBox(height: 8),
            ],
            const SizedBox(height: 12),
            MoncarButton(
              label: returnTicketId == null
                  ? 'Voir mon billet'
                  : 'Voir le billet aller',
              icon: Icons.confirmation_number_outlined,
              variant: MoncarButtonVariant.primary,
              size: MoncarButtonSize.lg,
              expand: true,
              onPressed: ticket == null
                  ? null
                  : () => context.push('/voyager/ticket/${ticket.id}'),
            ),
            if (returnTicketId != null) ...[
              const SizedBox(height: 10),
              MoncarButton(
                label: 'Voir le billet retour',
                icon: Icons.u_turn_left,
                variant: MoncarButtonVariant.outline,
                size: MoncarButtonSize.lg,
                expand: true,
                onPressed: () =>
                    context.push('/voyager/ticket/$returnTicketId'),
              ),
            ],
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: MoncarButton(
                    label: 'Suivi GPS',
                    icon: Icons.place_outlined,
                    variant: MoncarButtonVariant.outline,
                    size: MoncarButtonSize.md,
                    expand: true,
                    onPressed: ticket == null
                        ? null
                        : () => context.push('/tracking/${ticket.tripId}'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: MoncarButton(
                    label: 'Accueil',
                    variant: MoncarButtonVariant.ghost,
                    size: MoncarButtonSize.md,
                    expand: true,
                    onPressed: () {
                      ref.read(bookingDraftProvider.notifier).reset();
                      context.go('/home');
                    },
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _Cell extends StatelessWidget {
  const _Cell({required this.label, required this.value, required this.sub});

  final String label;
  final String value;
  final String sub;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        OverlineText(label),
        Text(
          value,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w700,
            color: MoncarColors.ink,
          ),
        ),
        Text(sub, style: TextStyle(fontSize: 11, color: MoncarColors.inkMut)),
      ],
    );
  }
}
