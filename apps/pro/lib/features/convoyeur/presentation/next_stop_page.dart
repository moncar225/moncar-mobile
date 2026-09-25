import 'package:core_ui/core_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/application/trip_controller.dart';
import '../../../core/domain/models.dart';
import '../../../core/ui/format.dart';
import '../../../core/ui/pro_kit.dart';
import '../../../core/ui/role_style.dart';
import '../../../core/ui/trip_widgets.dart';

/// Convoyeur · Prochain arrêt (vue « gare suivante », MAN-002) :
/// passagers à descendre, à embarquer, sièges libérés, bagages et colis.
class NextStopPage extends ConsumerWidget {
  const NextStopPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = ref.watch(tripProvider);
    final role = ProRole.convoyeur;
    final op = t.operationalStop;
    if (op == null) {
      return const ProPage(
        title: 'Prochain arrêt',
        children: [
          EmptyCard(message: 'Terminus atteint : aucun arrêt restant.'),
        ],
      );
    }
    final atStop = t.phase != DriverPhase.enRoute;
    final drop = t.toDropAt(op.id);
    final board = t.toBoardAt(op.id);
    final bags = t.bagsToUnloadAt(op.id);
    final parcels = t.parcelsToUnloadAt(op.id);
    final notifier = ref.read(tripProvider.notifier);

    return ProPage(
      title: atStop ? 'Arrêt en cours' : 'Prochain arrêt',
      subtitle: t.voyage.number,
      children: [
        HeroCard(
          colors: role.gradient,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text(
                    atStop ? 'À QUAI' : 'PROCHAINE GARE',
                    style: const TextStyle(
                      fontSize: 12,
                      letterSpacing: 1.2,
                      fontWeight: FontWeight.w800,
                      color: Colors.white70,
                    ),
                  ),
                  const Spacer(),
                  GlassPill(
                    label: atStop
                        ? 'Arrivé'
                        : 'ETA ${fmtTime(etaFor(t.voyage, op))}',
                    icon: Icons.schedule_rounded,
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Text(
                op.name,
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Km ${op.kmFromOrigin.round()} · ${plural(drop.length, 'descente')} · ${plural(board.length, 'montée')}',
                style: const TextStyle(color: Colors.white70),
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        Row(
          children: [
            Expanded(
              child: MiniStat(
                value: '${drop.length}',
                label: 'Sièges libérés',
                color: MoncarColors.success,
                icon: Icons.event_seat_rounded,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: MiniStat(
                value: '${bags.length}',
                label: 'Bagages',
                color: role.accent,
                icon: Icons.luggage_rounded,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: MiniStat(
                value: '${parcels.length}',
                label: 'Colis',
                color: MoncarColors.accent,
                icon: Icons.inventory_2_rounded,
              ),
            ),
          ],
        ),
        if (t.voyage.departureActual != null &&
            t.voyage.departureActual!
                    .difference(t.voyage.departurePlanned)
                    .inMinutes >
                0) ...[
          const SizedBox(height: 12),
          InfoBanner(
            icon: Icons.schedule_rounded,
            color: MoncarColors.warn,
            message:
                'Retard estimé : ${t.voyage.departureActual!.difference(t.voyage.departurePlanned).inMinutes} min — la gare de ${op.shortName} est informée.',
          ),
        ],
        SectionTitle('À descendre (${drop.length})'),
        if (drop.isEmpty)
          const EmptyCard(
            message: 'Aucun passager à débarquer ici.',
            icon: Icons.south_rounded,
          )
        else
          for (final p in drop)
            _PaxTile(
              p: p,
              accent: role.accent,
              actionLabel: atStop ? 'Descendu' : null,
              onAction: () {
                haptic(HapticKind.success);
                notifier.confirmDisembark(p.id);
              },
              onTap: () => context.push('/manifeste/${p.id}'),
            ),
        SectionTitle('À embarquer (${board.length})'),
        if (board.isEmpty)
          const EmptyCard(
            message: 'Aucun embarquement prévu ici.',
            icon: Icons.north_rounded,
          )
        else
          for (final p in board)
            _PaxTile(
              p: p,
              accent: role.accent,
              actionLabel: atStop ? 'À bord' : null,
              onAction: () {
                haptic(HapticKind.success);
                notifier.confirmPresence(p.id);
              },
              onTap: () => context.push('/manifeste/${p.id}'),
            ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: QuickActionTile(
                label: 'Bagages à décharger',
                icon: Icons.luggage_rounded,
                color: role.accent,
                badge: bags.isEmpty ? null : '${bags.length}',
                onTap: () => context.push('/conv/bagages'),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: QuickActionTile(
                label: 'Colis à décharger',
                icon: Icons.inventory_2_rounded,
                color: MoncarColors.accent,
                badge: parcels.isEmpty ? null : '${parcels.length}',
                onTap: () => context.push('/conv/colis'),
              ),
            ),
          ],
        ),
        if (!atStop) ...[
          const SizedBox(height: 12),
          const InfoBanner(
            message:
                'Les confirmations de descente et de montée s’activent quand le chauffeur signale l’arrivée à l’arrêt.',
          ),
        ],
      ],
    );
  }
}

class _PaxTile extends StatelessWidget {
  const _PaxTile({
    required this.p,
    required this.accent,
    required this.onAction,
    required this.onTap,
    this.actionLabel,
  });

  final Passenger p;
  final Color accent;
  final String? actionLabel;
  final VoidCallback onAction;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: MoncarCard(
        onTap: onTap,
        padding: const EdgeInsets.all(12),
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
                    style: TextStyle(
                      fontWeight: FontWeight.w800,
                      color: MoncarColors.ink,
                    ),
                  ),
                  Row(
                    children: [
                      Text(
                        p.ticketRef,
                        style: TextStyle(
                          fontSize: 12.5,
                          color: MoncarColors.inkMut,
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
            if (actionLabel != null)
              SizedBox(
                height: 38,
                child: FilledButton(
                  onPressed: onAction,
                  style: FilledButton.styleFrom(
                    backgroundColor: accent,
                    padding: const EdgeInsets.symmetric(horizontal: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: Text(
                    actionLabel!,
                    style: const TextStyle(fontWeight: FontWeight.w800),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
