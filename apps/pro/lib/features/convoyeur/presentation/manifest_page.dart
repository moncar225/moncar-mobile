import 'package:core_ui/core_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/application/session_controller.dart';
import '../../../core/application/trip_controller.dart';
import '../../../core/domain/models.dart';
import '../../../core/ui/format.dart';
import '../../../core/ui/pro_kit.dart';
import '../../../core/ui/role_style.dart';

enum _F {
  tous,
  aBord,
  absents,
  nonControles,
  aDescendre,
  aEmbarquer,
  descendus,
}

/// Manifeste par segment (MAN-001) — toujours recalculé depuis
/// réservations + scans + présences + débarquements, jamais ajusté à la main.
class ManifestPage extends ConsumerStatefulWidget {
  const ManifestPage({super.key});

  @override
  ConsumerState<ManifestPage> createState() => _ManifestPageState();
}

class _ManifestPageState extends ConsumerState<ManifestPage> {
  _F _f = _F.tous;
  String _q = '';

  @override
  Widget build(BuildContext context) {
    final t = ref.watch(tripProvider);
    final role = ref.watch(activeRoleProvider) ?? ProRole.convoyeur;
    final canConfirm = role == ProRole.convoyeur;
    final op = t.operationalStop;
    final aboardIds = t.expectedAboard.map((p) => p.id).toSet();

    bool match(Passenger p, _F f) => switch (f) {
      _F.tous => true,
      _F.aBord => p.isOnBoard,
      _F.absents => aboardIds.contains(p.id) && !p.isOnBoard,
      _F.nonControles => p.ticketState == TicketState.valide && !p.isControlled,
      _F.aDescendre => op != null && p.dropStopId == op.id && p.isOnBoard,
      _F.aEmbarquer =>
        op != null &&
            p.boardStopId == op.id &&
            !p.isOnBoard &&
            p.ticketState == TicketState.valide,
      _F.descendus => p.isDisembarked,
    };
    int count(_F f) => t.passengers.where((p) => match(p, f)).length;

    final q = _q.toLowerCase();
    final list = t.passengers
        .where((p) => match(p, _f))
        .where(
          (p) =>
              q.isEmpty ||
              p.name.toLowerCase().contains(q) ||
              p.ticketRef.toLowerCase().contains(q) ||
              p.seat.toLowerCase() == q,
        )
        .toList();

    return ProPage(
      title: 'Manifeste',
      subtitle:
          '${t.voyage.number} · ${op == null ? 'terminus' : 'segment vers ${op.shortName}'}',
      actions: [
        CircleIconButton(
          icon: Icons.sync_rounded,
          tooltip: 'Actualiser le manifeste',
          onTap: () {
            ref.read(tripProvider.notifier).refreshManifest();
            showProToast(
              context,
              'Manifeste actualisé.',
              tone: ToastTone.success,
            );
          },
        ),
      ],
      children: [
        Row(
          children: [
            Expanded(
              child: MiniStat(
                value: '${t.onBoard}',
                label: 'À bord',
                color: MoncarColors.success,
                icon: Icons.airline_seat_recline_normal_rounded,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: MiniStat(
                value: '${t.absents}',
                label: 'Absents',
                color: MoncarColors.warn,
                icon: Icons.person_off_rounded,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: MiniStat(
                value: '${count(_F.aDescendre)}',
                label: 'À descendre',
                color: MoncarColors.info,
                icon: Icons.south_rounded,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: MiniStat(
                value: '${t.voyage.totalSeats - t.onBoard}',
                label: 'Sièges libres',
                color: role.accent,
                icon: Icons.event_seat_rounded,
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),
        SearchField(
          hint: 'Nom, billet ou siège…',
          onChanged: (v) => setState(() => _q = v),
        ),
        const SizedBox(height: 12),
        FilterBar<_F>(
          accent: role.accent,
          selected: _f,
          onSelected: (v) => setState(() => _f = v),
          options: [
            FilterOption(_F.tous, 'Tous', count: t.passengers.length),
            FilterOption(_F.aBord, 'À bord', count: count(_F.aBord)),
            FilterOption(_F.absents, 'Absents', count: count(_F.absents)),
            FilterOption(
              _F.nonControles,
              'Non contrôlés',
              count: count(_F.nonControles),
            ),
            FilterOption(
              _F.aDescendre,
              'À descendre',
              count: count(_F.aDescendre),
            ),
            FilterOption(
              _F.aEmbarquer,
              'À embarquer',
              count: count(_F.aEmbarquer),
            ),
            FilterOption(_F.descendus, 'Descendus', count: count(_F.descendus)),
          ],
        ),
        const SizedBox(height: 12),
        if (list.isEmpty)
          const EmptyCard(
            message: 'Aucun passager pour ce filtre.',
            icon: Icons.groups_rounded,
          )
        else
          for (final p in list)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: _PassengerRow(
                p: p,
                trip: t,
                accent: role.accent,
                expectedAboard: aboardIds.contains(p.id),
                canConfirm: canConfirm,
                onTap: () => context.push('/manifeste/${p.id}'),
              ),
            ),
        const SizedBox(height: 6),
        Center(
          child: Text(
            'Manifeste téléchargé ${fmtAgo(t.manifestAt)} · disponible hors ligne',
            style: TextStyle(fontSize: 12, color: MoncarColors.inkFaint),
          ),
        ),
      ],
    );
  }
}

class _PassengerRow extends ConsumerWidget {
  const _PassengerRow({
    required this.p,
    required this.trip,
    required this.accent,
    required this.expectedAboard,
    required this.canConfirm,
    required this.onTap,
  });

  final Passenger p;
  final TripState trip;
  final Color accent;
  final bool expectedAboard;
  final bool canConfirm;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cancelled = p.ticketState == TicketState.annule;
    final Widget trailing;
    if (cancelled) {
      trailing = const MoncarBadge(
        label: 'Annulé',
        tone: MoncarBadgeTone.neutral,
        size: MoncarBadgeSize.sm,
      );
    } else if (p.isDisembarked) {
      trailing = const MoncarBadge(
        label: 'Descendu',
        tone: MoncarBadgeTone.brand,
        size: MoncarBadgeSize.sm,
      );
    } else if (canConfirm && expectedAboard && !p.isOnBoard) {
      trailing = SizedBox(
        height: 38,
        child: FilledButton(
          onPressed: () {
            haptic(HapticKind.success);
            ref.read(tripProvider.notifier).confirmPresence(p.id);
          },
          style: FilledButton.styleFrom(
            backgroundColor: accent,
            padding: const EdgeInsets.symmetric(horizontal: 14),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
          child: const Text(
            'Présent',
            style: TextStyle(fontWeight: FontWeight.w800),
          ),
        ),
      );
    } else {
      trailing = Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _Check(ok: p.isControlled, tooltip: 'Contrôle billet'),
          const SizedBox(width: 6),
          _Check(ok: p.isOnBoard, tooltip: 'Présence à bord'),
        ],
      );
    }
    return MoncarCard(
      onTap: onTap,
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
      child: Opacity(
        opacity: cancelled ? 0.55 : 1,
        child: Row(
          children: [
            SeatBadge(p.seat, color: accent),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    p.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontWeight: FontWeight.w800,
                      color: MoncarColors.ink,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          '${trip.stopById(p.boardStopId).shortName} → ${trip.stopById(p.dropStopId).shortName}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 12.5,
                            color: MoncarColors.inkMut,
                          ),
                        ),
                      ),
                      if (p.hasBaggage) ...[
                        const SizedBox(width: 6),
                        Icon(
                          Icons.luggage_rounded,
                          size: 14,
                          color: MoncarColors.inkFaint,
                        ),
                      ],
                      if (p.hasParcel) ...[
                        const SizedBox(width: 4),
                        Icon(
                          Icons.inventory_2_rounded,
                          size: 14,
                          color: MoncarColors.inkFaint,
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            trailing,
          ],
        ),
      ),
    );
  }
}

class _Check extends StatelessWidget {
  const _Check({required this.ok, required this.tooltip});
  final bool ok;
  final String tooltip;

  @override
  Widget build(BuildContext context) => Tooltip(
    message: tooltip,
    child: Icon(
      ok ? Icons.check_circle_rounded : Icons.radio_button_unchecked_rounded,
      size: 22,
      color: ok ? MoncarColors.success : MoncarColors.hairline,
    ),
  );
}
