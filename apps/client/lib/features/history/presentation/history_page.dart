import 'package:flutter/material.dart';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../colis/widgets/colis_widgets.dart';
import '../../location/presentation/my_rentals_page.dart';
import '../../shared/foundation.dart';

enum _Tab { all, trajets, tickets, parcels, rentals, payments }

enum _Filter { all, upcoming, past, cancelled }

enum _When { upcoming, past, cancelled }

const _tabs = [
  (key: _Tab.all, label: 'Tous', icon: Icons.inbox_outlined),
  (key: _Tab.trajets, label: 'Trajets', icon: Icons.directions_bus_outlined),
  (
    key: _Tab.tickets,
    label: 'Billets',
    icon: Icons.confirmation_number_outlined,
  ),
  (key: _Tab.parcels, label: 'Colis', icon: Icons.inventory_2_outlined),
  (key: _Tab.rentals, label: 'Locations', icon: Icons.directions_car_outlined),
  (
    key: _Tab.payments,
    label: 'Paiements',
    icon: Icons.account_balance_wallet_outlined,
  ),
];

const _filters = [
  (key: _Filter.all, label: 'Tous'),
  (key: _Filter.upcoming, label: 'À venir'),
  (key: _Filter.past, label: 'Passés'),
  (key: _Filter.cancelled, label: 'Annulés'),
];

_Tab _parseTab(String? v) =>
    _Tab.values.where((t) => t.name == v).firstOrNull ?? _Tab.all;

bool _matches(_Filter f, _When w) => switch (f) {
  _Filter.all => true,
  _Filter.upcoming => w == _When.upcoming,
  _Filter.past => w == _When.past,
  _Filter.cancelled => w == _When.cancelled,
};

(String, MoncarBadgeTone) _bookingMeta(BookingStatus s) => switch (s) {
  BookingStatus.enAttente => ('En attente', MoncarBadgeTone.warn),
  BookingStatus.paye => ('Payé', MoncarBadgeTone.success),
  BookingStatus.embarque => ('Embarqué', MoncarBadgeTone.accent),
  BookingStatus.descendu => ('Terminé', MoncarBadgeTone.neutral),
  BookingStatus.annule => ('Annulé', MoncarBadgeTone.danger),
  BookingStatus.expire => ('Expiré', MoncarBadgeTone.danger),
};

(String, MoncarBadgeTone) _ticketMeta(TicketStatus s) => switch (s) {
  TicketStatus.emis => ('Émis', MoncarBadgeTone.success),
  TicketStatus.embarque => ('Embarqué', MoncarBadgeTone.accent),
  TicketStatus.descendu => ('Terminé', MoncarBadgeTone.neutral),
  TicketStatus.annule => ('Annulé', MoncarBadgeTone.danger),
  TicketStatus.expire => ('Expiré', MoncarBadgeTone.danger),
};

(String, MoncarBadgeTone) _paymentMeta(PaymentStatus s) => switch (s) {
  PaymentStatus.enAttente => ('En attente', MoncarBadgeTone.warn),
  PaymentStatus.paye => ('Payé', MoncarBadgeTone.success),
  PaymentStatus.echoue => ('Échoué', MoncarBadgeTone.danger),
  PaymentStatus.expire => ('Expiré', MoncarBadgeTone.danger),
  PaymentStatus.annule => ('Annulé', MoncarBadgeTone.danger),
};

String _methodLabel(PaymentMethod m) => switch (m) {
  PaymentMethod.orangeMoney => 'Orange Money',
  PaymentMethod.mtnMoney => 'MTN MoMo',
  PaymentMethod.moovMoney => 'Moov Money',
  PaymentMethod.wave => 'Wave',
  PaymentMethod.carteBancaire => 'Carte bancaire',
  PaymentMethod.especes => 'Espèces',
};

_When _bookingWhen(BookingStatus s) => switch (s) {
  BookingStatus.annule || BookingStatus.expire => _When.cancelled,
  BookingStatus.descendu => _When.past,
  _ => _When.upcoming,
};

_When _ticketWhen(TicketStatus s) => switch (s) {
  TicketStatus.annule || TicketStatus.expire => _When.cancelled,
  TicketStatus.descendu => _When.past,
  _ => _When.upcoming,
};

_When _parcelWhen(ParcelStatus s) => switch (s) {
  ParcelStatus.annule || ParcelStatus.litige => _When.cancelled,
  ParcelStatus.livre => _When.past,
  _ => _When.upcoming,
};

_When _rentalWhen(RentalStatus s) => switch (s) {
  RentalStatus.annulee || RentalStatus.refusee => _When.cancelled,
  RentalStatus.terminee => _When.past,
  _ => _When.upcoming,
};

_When _paymentWhen(PaymentStatus s) => switch (s) {
  PaymentStatus.echoue ||
  PaymentStatus.expire ||
  PaymentStatus.annule => _When.cancelled,
  PaymentStatus.paye => _When.past,
  _ => _When.upcoming,
};

/// Historique unifié (`?tab=tickets|parcels|rentals|…`) : trajets,
/// billets, colis, locations et paiements, filtrables par période.
class HistoryPage extends ConsumerStatefulWidget {
  const HistoryPage({super.key});

  @override
  ConsumerState<HistoryPage> createState() => _HistoryPageState();
}

class _HistoryPageState extends ConsumerState<HistoryPage> {
  _Tab? _tab;
  _Filter _filter = _Filter.all;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Synchronise l'onglet avec l'URL (ex. « Mes billets » depuis le profil).
    final fromUrl = _parseTab(
      GoRouterState.of(context).uri.queryParameters['tab'],
    );
    _tab ??= fromUrl;
  }

  @override
  Widget build(BuildContext context) {
    ref.watch(mockStoreChangesProvider);
    final tab = _tab ?? _Tab.all;
    return Scaffold(
      backgroundColor: MoncarColors.background,
      appBar: const TopBar(
        title: 'Historique',
        showBack: true,
        showBell: false,
      ),
      body: Column(
        children: [
          SizedBox(
            height: 48,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
              children: [
                for (final t in _tabs) ...[
                  _TabPill(
                    label: t.label,
                    icon: t.icon,
                    active: tab == t.key,
                    onTap: () => setState(() => _tab = t.key),
                  ),
                  const SizedBox(width: 8),
                ],
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
            child: Row(
              children: [
                Expanded(
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        for (final f in _filters) ...[
                          _FilterPill(
                            label: f.label,
                            active: _filter == f.key,
                            onTap: () => setState(() => _filter = f.key),
                          ),
                          const SizedBox(width: 6),
                        ],
                      ],
                    ),
                  ),
                ),
                TextButton.icon(
                  onPressed: () => showMoncarToast(
                    context,
                    'Export en cours… Vous recevrez votre historique par email à la fin du traitement.',
                    success: true,
                  ),
                  icon: const Icon(Icons.download_outlined, size: 14),
                  label: const Text('Exporter'),
                  style: TextButton.styleFrom(
                    foregroundColor: MoncarColors.brand,
                    textStyle: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                    visualDensity: VisualDensity.compact,
                  ),
                ),
              ],
            ),
          ),
          Expanded(child: _buildContent(tab)),
        ],
      ),
    );
  }

  Widget _list(List<Widget> cards) => ListView.separated(
    padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
    itemCount: cards.length,
    separatorBuilder: (_, _) => const SizedBox(height: 10),
    itemBuilder: (_, i) => cards[i],
  );

  Widget _empty({
    required IconData icon,
    required String title,
    required String allMessage,
    required String category,
    String? action,
    String? route,
  }) {
    return MoncarEmptyState(
      icon: icon,
      title: title,
      message: _filter == _Filter.all
          ? allMessage
          : 'Aucun $category dans cette catégorie.',
      actionLabel: action,
      onAction: route == null ? null : () => context.go(route),
    );
  }

  Widget _buildContent(_Tab tab) {
    final store = ref.read(mockStoreProvider);
    switch (tab) {
      case _Tab.all || _Tab.trajets:
        final list = store.bookings
            .where((b) => _matches(_filter, _bookingWhen(b.status)))
            .toList();
        if (list.isEmpty) {
          return _empty(
            icon: Icons.directions_bus_outlined,
            title: 'Aucun trajet',
            allMessage: 'Réservez votre premier trajet pour le retrouver ici.',
            category: 'trajet',
            action: 'Réserver',
            route: '/voyager',
          );
        }
        return _list([for (final b in list) _BookingCard(b: b)]);
      case _Tab.tickets:
        final list = store.tickets
            .where((t) => _matches(_filter, _ticketWhen(t.status)))
            .toList();
        if (list.isEmpty) {
          return _empty(
            icon: Icons.confirmation_number_outlined,
            title: 'Aucun billet',
            allMessage: 'Vos billets électroniques apparaîtront ici.',
            category: 'billet',
          );
        }
        // Réservations aller-retour : deux billets pour une même réservation.
        final roundTrips = {
          for (final t in store.tickets)
            if (t.leg == TicketLeg.retour) t.bookingId,
        };
        return _list([
          for (final t in list)
            _TicketCard(t: t, roundTrip: roundTrips.contains(t.bookingId)),
        ]);
      case _Tab.parcels:
        final list = store.parcels
            .where((p) => _matches(_filter, _parcelWhen(p.status)))
            .toList();
        if (list.isEmpty) {
          return _empty(
            icon: Icons.inventory_2_outlined,
            title: 'Aucun colis',
            allMessage: 'Envoyez un premier colis pour le retrouver ici.',
            category: 'colis',
            action: 'Envoyer',
            route: '/colis/new',
          );
        }
        return _list([for (final p in list) _ParcelCard(p: p)]);
      case _Tab.rentals:
        final list = store.rentals
            .where((r) => _matches(_filter, _rentalWhen(r.status)))
            .toList();
        if (list.isEmpty) {
          return _empty(
            icon: Icons.directions_car_outlined,
            title: 'Aucune location',
            allMessage:
                'Louez un véhicule pour retrouver votre réservation ici.',
            category: 'location',
            action: 'Louer',
            route: '/location',
          );
        }
        return _list([for (final r in list) RentalListCard(rental: r)]);
      case _Tab.payments:
        final list = store.payments
            .where((p) => _matches(_filter, _paymentWhen(p.status)))
            .toList();
        if (list.isEmpty) {
          return _empty(
            icon: Icons.account_balance_wallet_outlined,
            title: 'Aucun paiement',
            allMessage: 'Vos paiements apparaîtront ici.',
            category: 'paiement',
          );
        }
        return _list([for (final p in list) _PaymentCard(p: p)]);
    }
  }
}

class _TabPill extends StatelessWidget {
  const _TabPill({
    required this.label,
    required this.icon,
    required this.active,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(999),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 14),
        decoration: BoxDecoration(
          color: active ? MoncarColors.brand : MoncarColors.surface,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(
            color: active ? MoncarColors.brand : MoncarColors.hairline,
          ),
        ),
        child: Row(
          children: [
            Icon(
              icon,
              size: 14,
              color: active ? Colors.white : MoncarColors.inkMut,
            ),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: active ? Colors.white : MoncarColors.inkMut,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _FilterPill extends StatelessWidget {
  const _FilterPill({
    required this.label,
    required this.active,
    required this.onTap,
  });

  final String label;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(999),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: active ? MoncarColors.accentSoft : MoncarColors.surface,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(
            color: active
                ? MoncarColors.accent.withValues(alpha: 0.3)
                : MoncarColors.hairline,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            color: active ? MoncarColors.accentInk : MoncarColors.inkMut,
          ),
        ),
      ),
    );
  }
}

// ----------------------------- Cartes -----------------------------

class _CardHeader extends StatelessWidget {
  const _CardHeader({required this.meta, required this.reference});

  final (String, MoncarBadgeTone) meta;
  final String reference;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        MoncarBadge(label: meta.$1, tone: meta.$2),
        const Spacer(),
        Text(
          reference,
          style: TextStyle(
            fontSize: 11,
            fontFamily: 'monospace',
            color: MoncarColors.inkFaint,
          ),
        ),
      ],
    );
  }
}

class _Route extends StatelessWidget {
  const _Route({required this.from, required this.to});

  final String from;
  final String to;

  @override
  Widget build(BuildContext context) {
    final style = TextStyle(
      fontSize: 14,
      fontWeight: FontWeight.w700,
      color: MoncarColors.ink,
    );
    return Row(
      children: [
        Flexible(
          child: Text(from, overflow: TextOverflow.ellipsis, style: style),
        ),
        Padding(
          padding: EdgeInsets.symmetric(horizontal: 6),
          child: Icon(
            Icons.arrow_forward,
            size: 14,
            color: MoncarColors.accent,
          ),
        ),
        Flexible(
          child: Text(to, overflow: TextOverflow.ellipsis, style: style),
        ),
      ],
    );
  }
}

class _Meta extends StatelessWidget {
  const _Meta({required this.icon, required this.text});

  final IconData? icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (icon != null) ...[
          Icon(icon, size: 12, color: MoncarColors.inkMut),
          const SizedBox(width: 4),
        ],
        Flexible(
          child: Text(
            text,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(fontSize: 11, color: MoncarColors.inkMut),
          ),
        ),
      ],
    );
  }
}

class _AmountFooter extends StatelessWidget {
  const _AmountFooter({
    required this.label,
    required this.value,
    this.trailing,
  });

  final String label;
  final String value;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(top: 10),
      padding: const EdgeInsets.only(top: 10),
      decoration: BoxDecoration(
        border: Border(
          top: BorderSide(color: MoncarColors.hairline.withValues(alpha: 0.7)),
        ),
      ),
      child: Row(
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              OverlineText(label, color: MoncarColors.inkFaint),
              Text(
                value,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: MoncarColors.brand,
                ),
              ),
            ],
          ),
          const Spacer(),
          ?trailing,
        ],
      ),
    );
  }
}

class _BookingCard extends StatelessWidget {
  const _BookingCard({required this.b});

  final Booking b;

  @override
  Widget build(BuildContext context) {
    final parts = b.tripSummary.split(' → ');
    final ticketId = b.ticketId;
    return MoncarCard(
      padding: const EdgeInsets.all(14),
      onTap: ticketId == null
          ? null
          : () => context.push('/voyager/ticket/$ticketId'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _CardHeader(meta: _bookingMeta(b.status), reference: b.reference),
          const SizedBox(height: 10),
          _Route(from: parts.first, to: parts.length > 1 ? parts[1] : ''),
          const SizedBox(height: 4),
          Wrap(
            spacing: 8,
            runSpacing: 2,
            children: [
              _Meta(
                icon: Icons.calendar_today_outlined,
                text: formatDateWithDay(b.date),
              ),
              _Meta(icon: Icons.schedule, text: b.departureTime),
              if (b.seats.isNotEmpty)
                _Meta(
                  icon: Icons.place_outlined,
                  text: 'Siège ${b.seats.join(', ')}',
                ),
            ],
          ),
          _AmountFooter(
            label: 'Montant',
            value: formatXOF(b.totalXOF),
            trailing: ticketId != null
                ? MoncarButton(
                    label: 'Voir billet',
                    icon: Icons.confirmation_number_outlined,
                    variant: MoncarButtonVariant.soft,
                    size: MoncarButtonSize.sm,
                    onPressed: () => context.push('/voyager/ticket/$ticketId'),
                  )
                : Text(
                    'Billet non émis',
                    style: TextStyle(
                      fontSize: 11,
                      color: MoncarColors.inkFaint,
                    ),
                  ),
          ),
          const SizedBox(height: 8),
          Text(
            b.companyName,
            style: TextStyle(fontSize: 10, color: MoncarColors.inkFaint),
          ),
        ],
      ),
    );
  }
}

class _TicketCard extends StatelessWidget {
  const _TicketCard({required this.t, this.roundTrip = false});

  final Ticket t;
  final bool roundTrip;

  @override
  Widget build(BuildContext context) {
    return MoncarCard(
      padding: const EdgeInsets.all(14),
      onTap: () => context.push('/voyager/ticket/${t.id}'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _CardHeader(meta: _ticketMeta(t.status), reference: t.number),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: _Route(from: t.originCity, to: t.destinationCity),
              ),
              if (roundTrip)
                MoncarBadge(
                  label: t.leg.label,
                  tone: t.leg == TicketLeg.retour
                      ? MoncarBadgeTone.accent
                      : MoncarBadgeTone.brand,
                  size: MoncarBadgeSize.sm,
                ),
            ],
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              Expanded(
                child: _Meta(
                  icon: Icons.calendar_today_outlined,
                  text: formatDateWithDay(t.date),
                ),
              ),
              Expanded(
                child: _Meta(
                  icon: Icons.schedule,
                  text: '${t.departureTime} → ${t.arrivalTime}',
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Row(
            children: [
              Expanded(
                child: _Meta(
                  icon: Icons.place_outlined,
                  text: 'Siège ${t.seatNumber}',
                ),
              ),
              Expanded(
                child: _Meta(
                  icon: Icons.directions_bus_outlined,
                  text: t.vehicleModel,
                ),
              ),
            ],
          ),
          Container(
            margin: const EdgeInsets.only(top: 10),
            padding: const EdgeInsets.only(top: 10),
            decoration: BoxDecoration(
              border: Border(
                top: BorderSide(
                  color: MoncarColors.hairline.withValues(alpha: 0.7),
                ),
              ),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      OverlineText('Passager', color: MoncarColors.inkFaint),
                      Text(
                        t.passengerName,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w600,
                          color: MoncarColors.ink,
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(
                  Icons.chevron_right,
                  size: 16,
                  color: MoncarColors.inkFaint,
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          Text(
            t.companyName,
            style: TextStyle(fontSize: 10, color: MoncarColors.inkFaint),
          ),
        ],
      ),
    );
  }
}

class _ParcelCard extends StatelessWidget {
  const _ParcelCard({required this.p});

  final Parcel p;

  @override
  Widget build(BuildContext context) {
    final total = p.timeline.isEmpty ? 1 : p.timeline.length;
    final done = p.timeline.where((t) => t.done).length;
    // L'historique affiche aussi les colis annulés en rouge.
    final tone = p.status == ParcelStatus.annule
        ? MoncarBadgeTone.danger
        : parcelStatusTone(p.status);
    return MoncarCard(
      padding: const EdgeInsets.all(14),
      onTap: () => context.push('/colis/${p.id}'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _CardHeader(
            meta: (parcelStatusLabel(p.status), tone),
            reference: p.trackingNumber,
          ),
          const SizedBox(height: 8),
          _Route(from: p.originCity, to: p.destinationCity),
          const SizedBox(height: 4),
          Row(
            children: [
              Flexible(
                child: _Meta(
                  icon: null,
                  text: '${p.recipientName} • ${p.weightKg} kg • ',
                ),
              ),
              Text(
                formatXOF(p.amountXOF),
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: MoncarColors.brand,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          ParcelProgressBar(parcel: p),
          const SizedBox(height: 6),
          Text(
            '$done/$total étapes • Déposé ${timeAgo(p.createdAt)}',
            style: TextStyle(fontSize: 10, color: MoncarColors.inkFaint),
          ),
        ],
      ),
    );
  }
}

class _PaymentCard extends StatelessWidget {
  const _PaymentCard({required this.p});

  final Payment p;

  @override
  Widget build(BuildContext context) {
    return MoncarCard(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _CardHeader(meta: _paymentMeta(p.status), reference: p.reference),
          const SizedBox(height: 8),
          Row(
            children: [
              Icon(
                Icons.receipt_long_outlined,
                size: 16,
                color: MoncarColors.brand,
              ),
              const SizedBox(width: 8),
              Text(
                _methodLabel(p.method),
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: MoncarColors.ink,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Wrap(
            spacing: 8,
            children: [
              _Meta(
                icon: Icons.calendar_today_outlined,
                text: formatDateLong(p.createdAt),
              ),
              if (p.gatewayRef != null)
                _Meta(icon: null, text: '• gw ${p.gatewayRef}'),
            ],
          ),
          if (p.failureReason != null)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Text(
                p.failureReason!,
                style: TextStyle(fontSize: 11, color: MoncarColors.danger),
              ),
            ),
          _AmountFooter(
            label: 'Montant',
            value: formatXOF(p.amountXOF),
            trailing: p.confirmedAt != null
                ? Text(
                    'Confirmé ${timeAgo(p.confirmedAt!)}',
                    style: TextStyle(
                      fontSize: 11,
                      color: MoncarColors.inkFaint,
                    ),
                  )
                : null,
          ),
        ],
      ),
    );
  }
}
