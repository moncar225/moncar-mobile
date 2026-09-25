import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../shared/foundation.dart';
import '../widgets/voyager_widgets.dart';

String _classLabel(SeatClass c) => switch (c) {
  SeatClass.standard => 'Standard',
  SeatClass.confort => 'Confort',
  SeatClass.vip => 'VIP',
};

String _positionLabel(SeatPosition p) => switch (p) {
  SeatPosition.fenetre => 'Fenêtre',
  SeatPosition.allee => 'Allée',
  SeatPosition.milieu => 'Milieu',
};

/// Plan de sièges : le nombre de sièges attendu est celui des passagers
/// choisis à la recherche (ajustable, [maxPassengers] au plus). Le
/// montant estimé se met à jour à chaque siège. Étape suivante :
/// informations des passagers (`PassengersPage`).
class SeatsPage extends ConsumerStatefulWidget {
  const SeatsPage({super.key, required this.tripId});

  final String tripId;

  @override
  ConsumerState<SeatsPage> createState() => _SeatsPageState();
}

class _SeatsPageState extends ConsumerState<SeatsPage> {
  late List<String> _selected = List.of(
    ref.read(bookingDraftProvider).selectedSeats,
  );
  late int _passengers = ref
      .read(bookingDraftProvider)
      .passengerCount
      .clamp(1, maxPassengers);

  ({String boarding, String alighting}) _stops(Trip? trip) {
    final q = GoRouterState.of(context).uri.queryParameters;
    final draft = ref.read(bookingDraftProvider);
    return (
      boarding:
          q['boarding'] ?? draft.boardingStopId ?? trip?.stops.first.id ?? '',
      alighting:
          q['alighting'] ?? draft.alightingStopId ?? trip?.stops.last.id ?? '',
    );
  }

  bool get _isReturn =>
      GoRouterState.of(context).uri.queryParameters['leg'] == 'retour';

  /// Étape suivante. Aller-retour : l'aller mène au choix du retour,
  /// le retour mène aux passagers (saisis une seule fois pour les deux
  /// segments, sur la base de l'aller).
  void _continue(Trip? trip, ({String boarding, String alighting}) stops) {
    final notifier = ref.read(bookingDraftProvider.notifier);
    final draft = ref.read(bookingDraftProvider);
    if (trip != null && draft.tripType == TripType.allerRetour) {
      final current = DraftLeg(
        trip: trip,
        boardingStopId: stops.boarding,
        alightingStopId: stops.alighting,
        seats: List.of(_selected),
      );
      if (!_isReturn) {
        notifier.update(
          (d) => d.copyWith(outboundLeg: current, clearLegs: true),
        );
        final query = Uri(
          queryParameters: {
            'origin': trip.destinationCityName,
            'destination': trip.originCityName,
            'date': draft.returnDate ?? trip.date,
            'passengers': '${_selected.length}',
            'type': TripType.allerRetour.apiName,
            'leg': 'retour',
          },
        ).query;
        context.push('/voyager?$query');
        return;
      }
      final out = draft.outboundLeg;
      if (out == null) {
        showMoncarToast(
          context,
          "Choisissez d'abord votre trajet aller.",
          error: true,
        );
        return;
      }
      if (out.seats.length != _selected.length) {
        showMoncarToast(
          context,
          'Choisissez ${out.seats.length} siège${out.seats.length > 1 ? 's' : ''}, comme à l\'aller.',
          error: true,
        );
        return;
      }
      // Les champs principaux reprennent l'aller pour la saisie des
      // passagers ; le retour est mémorisé à part.
      notifier.update(
        (d) => d.copyWith(
          returnLeg: current,
          trip: out.trip,
          boardingStopId: out.boardingStopId,
          alightingStopId: out.alightingStopId,
          selectedSeats: out.seats,
        ),
      );
      context.push(
        '/voyager/passengers/${out.trip.id}'
        '?boarding=${out.boardingStopId}&alighting=${out.alightingStopId}',
      );
      return;
    }
    context.push(
      '/voyager/passengers/${widget.tripId}'
      '?boarding=${stops.boarding}&alighting=${stops.alighting}',
    );
  }

  void _setSelected(List<String> seats) {
    setState(() => _selected = seats);
    ref
        .read(bookingDraftProvider.notifier)
        .update((d) => d.copyWith(selectedSeats: seats));
  }

  void _toggle(Seat seat) {
    if (seat.status == SeatStatus.taken || seat.status == SeatStatus.blocked) {
      showMoncarToast(context, 'Ce siège est indisponible.', error: true);
      return;
    }
    HapticFeedback.selectionClick();
    if (_selected.contains(seat.number)) {
      _setSelected(_selected.where((s) => s != seat.number).toList());
    } else if (_selected.length >= _passengers) {
      showMoncarToast(
        context,
        _passengers >= maxPassengers
            ? '$maxPassengers sièges maximum par réservation.'
            : 'Vous voyagez à $_passengers. Ajoutez un passager pour choisir un siège de plus.',
        error: true,
      );
    } else {
      _setSelected([..._selected, seat.number]);
    }
  }

  void _setPassengers(int n) {
    final count = n.clamp(1, maxPassengers);
    setState(() => _passengers = count);
    ref
        .read(bookingDraftProvider.notifier)
        .update((d) => d.copyWith(passengerCount: count));
    // Moins de passagers que de sièges : on retire les derniers choisis.
    if (_selected.length > count) _setSelected(_selected.take(count).toList());
  }

  @override
  Widget build(BuildContext context) {
    ref.watch(mockStoreChangesProvider);
    final store = ref.read(mockStoreProvider);
    final trip = store.findTrip(widget.tripId);
    final stops = _stops(trip);
    final seatMap = store.getSeatMap(
      widget.tripId,
      stops.boarding,
      stops.alighting,
    );

    if (seatMap == null) {
      return Scaffold(
        appBar: const TopBar(
          title: 'Choix des sièges',
          showBack: true,
          showBell: false,
        ),
        body: MoncarErrorState(
          message: 'Plan de sièges indisponible',
          onRetry: () => setState(() {}),
        ),
      );
    }

    final rows = <int, List<Seat>>{};
    for (final s in seatMap.seats) {
      rows.putIfAbsent(s.row, () => []).add(s);
    }
    final rowKeys = rows.keys.toList()..sort();
    for (final k in rowKeys) {
      rows[k]!.sort((a, b) => a.col.compareTo(b.col));
    }
    final selectedData = seatMap.seats
        .where((s) => _selected.contains(s.number))
        .toList();
    final total = selectedData.fold<int>(0, (sum, s) => sum + s.priceXOF);
    final cols = seatMap.layout.cols;
    final n = _selected.length;
    final remaining = _passengers - n;
    final complete = remaining == 0;

    return Scaffold(
      backgroundColor: MoncarColors.background,
      appBar: TopBar(
        title: 'Choix des sièges',
        subtitle: seatMap.vehicleModel,
        showBack: true,
        showBell: false,
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
        children: [
          if (ref.read(bookingDraftProvider).tripType ==
              TripType.allerRetour) ...[
            RoundTripBanner(
              isReturn: _isReturn,
              outbound: ref.read(bookingDraftProvider).outboundLeg,
            ),
            const SizedBox(height: 12),
          ],
          _PassengerCard(
            passengers: _passengers,
            selected: n,
            onChanged: _setPassengers,
          ),
          const SizedBox(height: 12),
          MoncarCard(
            padding: const EdgeInsets.all(12),
            child: Column(
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    for (final l in seatMap.legend)
                      Expanded(
                        child: Column(
                          children: [
                            _LegendSwatch(status: l.status),
                            const SizedBox(height: 4),
                            Text(
                              l.label,
                              textAlign: TextAlign.center,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 10,
                                color: MoncarColors.inkMut,
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 8),
                Divider(height: 1, color: MoncarColors.hairline),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        '${seatMap.availableCount} sièges libres',
                        style: TextStyle(
                          fontSize: 11,
                          color: MoncarColors.inkMut,
                        ),
                      ),
                    ),
                    Text(
                      '$n / $_passengers sélectionné${n > 1 ? 's' : ''}',
                      style: TextStyle(
                        fontSize: 11,
                        color: MoncarColors.inkMut,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          MoncarCard(
            child: Column(
              children: [
                const _BusEndLabel(icon: Icons.speed, label: 'Avant du bus'),
                const SizedBox(height: 12),
                for (final rowNum in rowKeys)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        SizedBox(
                          width: 20,
                          child: Text(
                            '$rowNum',
                            textAlign: TextAlign.right,
                            style: TextStyle(
                              fontSize: 10,
                              fontFamily: 'monospace',
                              color: MoncarColors.inkFaint,
                            ),
                          ),
                        ),
                        for (var ci = 0; ci < cols; ci++) ...[
                          // Allée centrale entre les colonnes 2 et 3.
                          if (ci == 2) const SizedBox(width: 16),
                          const SizedBox(width: 6),
                          if (ci < rows[rowNum]!.length)
                            _SeatButton(
                              seat: rows[rowNum]![ci],
                              selected: _selected.contains(
                                rows[rowNum]![ci].number,
                              ),
                              onTap: () => _toggle(rows[rowNum]![ci]),
                            )
                          else
                            const SizedBox(width: 36),
                        ],
                      ],
                    ),
                  ),
                const SizedBox(height: 4),
                const _BusEndLabel(label: 'Arrière du bus'),
              ],
            ),
          ),
          if (selectedData.isNotEmpty) ...[
            const SizedBox(height: 16),
            Padding(
              padding: EdgeInsets.fromLTRB(4, 0, 4, 12),
              child: Text(
                'Vos sièges',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: MoncarColors.ink,
                ),
              ),
            ),
            for (final s in selectedData) ...[
              MoncarCard(
                padding: const EdgeInsets.all(12),
                child: Row(
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      alignment: Alignment.center,
                      decoration: accentGradientDecoration(
                        radius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        s.number,
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Siège ${s.number}',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: MoncarColors.ink,
                            ),
                          ),
                          Text(
                            '${_classLabel(s.seatClass)} · ${_positionLabel(s.position)}',
                            style: TextStyle(
                              fontSize: 11,
                              color: MoncarColors.inkMut,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Text(
                      formatXOF(s.priceXOF),
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: MoncarColors.accent,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
            ],
          ],
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
                    OverlineText(
                      n == 0
                          ? 'Total estimé'
                          : 'Total estimé · $n siège${n > 1 ? 's' : ''}',
                    ),
                    TweenAnimationBuilder<int>(
                      tween: IntTween(end: total),
                      duration: const Duration(milliseconds: 300),
                      builder: (_, v, _) => Text(
                        formatXOF(v),
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                          color: MoncarColors.ink,
                        ),
                      ),
                    ),
                  ],
                ),
                const Spacer(),
                Icon(
                  Icons.info_outline,
                  size: 12,
                  color: MoncarColors.inkFaint,
                ),
                const SizedBox(width: 4),
                Flexible(
                  child: Text(
                    'Montant final calculé par le serveur',
                    style: TextStyle(
                      fontSize: 11,
                      color: MoncarColors.inkFaint,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            MoncarButton(
              label: complete
                  ? 'Continuer ($n siège${n > 1 ? 's' : ''})'
                  : 'Choisissez encore $remaining siège${remaining > 1 ? 's' : ''}',
              icon: complete ? Icons.arrow_forward : null,
              variant: MoncarButtonVariant.primary,
              size: MoncarButtonSize.lg,
              expand: true,
              onPressed: !complete ? null : () => _continue(trip, stops),
            ),
          ],
        ),
      ),
    );
  }
}

/// Nombre de passagers (repris de la recherche, modifiable) et
/// progression du choix des sièges.
class _PassengerCard extends StatelessWidget {
  const _PassengerCard({
    required this.passengers,
    required this.selected,
    required this.onChanged,
  });

  final int passengers;
  final int selected;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    final done = selected == passengers;
    return MoncarCard(
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              IconTile(
                icon: Icons.group_outlined,
                background: MoncarColors.brandSoft,
                size: 36,
                radius: 18,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '$passengers passager${passengers > 1 ? 's' : ''}',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: MoncarColors.ink,
                      ),
                    ),
                    Text(
                      '1 siège par passager · $maxPassengers max',
                      style: TextStyle(
                        fontSize: 11,
                        color: MoncarColors.inkMut,
                      ),
                    ),
                  ],
                ),
              ),
              _StepButton(
                icon: Icons.remove,
                onTap: passengers > 1 ? () => onChanged(passengers - 1) : null,
              ),
              SizedBox(
                width: 28,
                child: Text(
                  '$passengers',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: MoncarColors.ink,
                  ),
                ),
              ),
              _StepButton(
                icon: Icons.add,
                onTap: passengers < maxPassengers
                    ? () => onChanged(passengers + 1)
                    : null,
              ),
            ],
          ),
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: LinearProgressIndicator(
              value: selected / passengers,
              minHeight: 6,
              backgroundColor: MoncarColors.hairline,
              color: done ? MoncarColors.success : MoncarColors.accent,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            done
                ? 'Tous les sièges sont choisis.'
                : 'Sièges choisis : $selected sur $passengers',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: done ? MoncarColors.success : MoncarColors.inkMut,
            ),
          ),
        ],
      ),
    );
  }
}

class _StepButton extends StatelessWidget {
  const _StepButton({required this.icon, this.onTap});

  final IconData icon;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final enabled = onTap != null;
    return InkWell(
      onTap: onTap,
      customBorder: const CircleBorder(),
      child: Container(
        width: 32,
        height: 32,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(
            color: enabled ? MoncarColors.brand : MoncarColors.hairline,
          ),
        ),
        child: Icon(
          icon,
          size: 16,
          color: enabled ? MoncarColors.brand : MoncarColors.inkFaint,
        ),
      ),
    );
  }
}

class _BusEndLabel extends StatelessWidget {
  const _BusEndLabel({required this.label, this.icon});

  final String label;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: MoncarColors.brandSoft.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 14, color: MoncarColors.inkFaint),
            const SizedBox(width: 6),
          ],
          Text(
            label,
            style: TextStyle(fontSize: 11, color: MoncarColors.inkFaint),
          ),
        ],
      ),
    );
  }
}

class _LegendSwatch extends StatelessWidget {
  const _LegendSwatch({required this.status});

  final SeatStatus status;

  @override
  Widget build(BuildContext context) {
    final (bg, border) = switch (status) {
      SeatStatus.available => (MoncarColors.surface, MoncarColors.success),
      SeatStatus.selected => (MoncarColors.accent, MoncarColors.accent),
      SeatStatus.taken => (
        MoncarColors.inkFaint.withValues(alpha: 0.4),
        MoncarColors.inkFaint.withValues(alpha: 0.4),
      ),
      _ => (MoncarColors.hairline, MoncarColors.hairline),
    };
    return Container(
      width: 24,
      height: 24,
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: border, width: 2),
      ),
    );
  }
}

class _SeatButton extends StatelessWidget {
  const _SeatButton({
    required this.seat,
    required this.selected,
    required this.onTap,
  });

  final Seat seat;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final taken = seat.status == SeatStatus.taken;
    final blocked = seat.status == SeatStatus.blocked;
    final free = !selected && !taken && !blocked;
    final isVip = seat.seatClass == SeatClass.vip;
    final isConfort = seat.seatClass == SeatClass.confort;

    Color border;
    Color fg;
    Color? bg;
    if (selected) {
      border = MoncarColors.accent;
      fg = Colors.white;
    } else if (taken) {
      bg = MoncarColors.inkFaint.withValues(alpha: 0.3);
      border = MoncarColors.inkFaint.withValues(alpha: 0.3);
      fg = MoncarColors.inkFaint.withValues(alpha: 0.5);
    } else if (blocked) {
      bg = MoncarColors.hairline;
      border = MoncarColors.hairline;
      fg = MoncarColors.inkFaint.withValues(alpha: 0.3);
    } else if (isVip) {
      bg = MoncarColors.surface;
      border = MoncarColors.brand;
      fg = MoncarColors.brand;
    } else if (isConfort) {
      bg = MoncarColors.surface;
      border = MoncarColors.brand.withValues(alpha: 0.6);
      fg = MoncarColors.brand.withValues(alpha: 0.8);
    } else {
      bg = MoncarColors.surface;
      border = MoncarColors.success;
      fg = MoncarColors.success;
    }

    final state = taken
        ? 'occupé'
        : blocked
        ? 'indisponible'
        : selected
        ? 'sélectionné'
        : 'libre';
    return Semantics(
      button: true,
      label: 'Siège ${seat.number} $state',
      child: GestureDetector(
        onTap: taken || blocked ? null : onTap,
        child: AnimatedScale(
          scale: selected ? 1.05 : 1,
          duration: const Duration(milliseconds: 150),
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              Container(
                width: 36,
                height: 36,
                alignment: Alignment.center,
                decoration:
                    (selected
                            ? accentGradientDecoration(
                                radius: BorderRadius.circular(8),
                              )
                            : BoxDecoration(
                                color: bg,
                                borderRadius: BorderRadius.circular(8),
                              ))
                        .copyWith(border: Border.all(color: border, width: 2)),
                child: selected
                    ? const Icon(Icons.check, size: 14, color: Colors.white)
                    : Text(
                        seat.number,
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          color: fg,
                        ),
                      ),
              ),
              if (isVip && free)
                Positioned(
                  top: -4,
                  right: -4,
                  child: Container(
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(
                      color: MoncarColors.brand,
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
