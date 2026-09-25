import 'package:core_ui/core_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/application/app_providers.dart';
import '../../../core/application/session_controller.dart';
import '../../../core/application/trip_controller.dart';
import '../../../core/domain/models.dart';
import '../../../core/ui/format.dart';
import '../../../core/ui/pro_kit.dart';
import '../../../core/ui/role_style.dart';

/// Fiche passager : contrôle billet, présence à bord, débarquement.
/// Le débarquement libère le siège sur les segments suivants (serveur).
class PassengerPage extends ConsumerWidget {
  const PassengerPage({super.key, required this.passengerId});

  final String passengerId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = ref.watch(tripProvider);
    final p = t.passengers.where((x) => x.id == passengerId).firstOrNull;
    if (p == null) {
      return const ProPage(
        title: 'Passager',
        children: [
          EmptyCard(message: 'Passager introuvable dans le manifeste.'),
        ],
      );
    }
    final role = ref.watch(activeRoleProvider) ?? ProRole.convoyeur;
    final accent = role.accent;
    final isConv = role == ProRole.convoyeur;
    final boardIdx = t.stopIndex(p.boardStopId);
    final canBoard =
        isConv &&
        p.ticketState == TicketState.valide &&
        !p.isOnBoard &&
        !p.isDisembarked &&
        boardIdx <= t.voyage.currentStopIndex;
    final atStop =
        t.phase == DriverPhase.aLArret ||
        t.phase == DriverPhase.arriveDestination;
    final canDrop = isConv && p.isOnBoard && atStop;
    final online = ref.watch(networkProvider.select((n) => n.online));

    Future<void> presence() async {
      final ok = await confirmAction(
        context,
        title: 'Confirmer la présence à bord ?',
        message:
            '${p.name} — siège ${p.seat}. L’heure terrain est enregistrée.',
        confirmLabel: 'Confirmer la présence',
        icon: Icons.how_to_reg_rounded,
        color: accent,
      );
      if (!ok) return;
      ref.read(tripProvider.notifier).confirmPresence(p.id);
      haptic(HapticKind.success);
      if (context.mounted) {
        showProToast(
          context,
          online ? 'Présence confirmée.' : 'Présence enregistrée hors ligne.',
          tone: online ? ToastTone.success : ToastTone.warning,
        );
      }
    }

    Future<void> disembark() async {
      final ok = await confirmAction(
        context,
        title: 'Confirmer le débarquement ?',
        message:
            '${p.name} descend à ${t.voyage.currentStop.shortName}. '
            'Le siège ${p.seat} sera libéré pour les segments suivants.',
        confirmLabel: 'Confirmer la descente',
        icon: Icons.logout_rounded,
        color: MoncarColors.info,
      );
      if (!ok) return;
      ref.read(tripProvider.notifier).confirmDisembark(p.id);
      haptic(HapticKind.success);
      if (context.mounted) {
        showProToast(
          context,
          'Débarquement confirmé.',
          tone: ToastTone.success,
        );
      }
    }

    return ProPage(
      title: p.name,
      subtitle: 'Siège ${p.seat} · ${p.ticketRef}',
      bottom: canBoard
          ? BigActionButton(
              label: boardIdx < t.voyage.currentStopIndex || boardIdx == 0
                  ? 'Confirmer la présence'
                  : 'Confirmer l’embarquement',
              icon: Icons.how_to_reg_rounded,
              color: accent,
              onPressed: presence,
            )
          : canDrop
          ? BigActionButton(
              label: 'Confirmer le débarquement',
              icon: Icons.logout_rounded,
              color: MoncarColors.info,
              onPressed: disembark,
            )
          : null,
      children: [
        MoncarCard(
          child: Column(
            children: [
              Row(
                children: [
                  InitialsAvatar(initials: p.initials, color: accent, size: 56),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          p.name,
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                            color: MoncarColors.ink,
                          ),
                        ),
                        Text(
                          p.phone,
                          style: TextStyle(color: MoncarColors.inkMut),
                        ),
                      ],
                    ),
                  ),
                  SeatBadge(p.seat, color: accent),
                ],
              ),
              const Divider(height: 26),
              DetailRow(
                label: 'Montée',
                value: t.stopById(p.boardStopId).name,
                icon: Icons.north_east_rounded,
              ),
              DetailRow(
                label: 'Descente',
                value: t.stopById(p.dropStopId).name,
                icon: Icons.south_east_rounded,
              ),
              DetailRow(
                label: 'Bagage',
                value: p.hasBaggage ? 'Oui' : 'Non',
                icon: Icons.luggage_rounded,
              ),
              DetailRow(
                label: 'Colis',
                value: p.hasParcel ? 'Oui' : 'Non',
                icon: Icons.inventory_2_rounded,
              ),
            ],
          ),
        ),
        const SectionTitle('Statuts'),
        _StatusStep(
          title: 'Billet',
          value: p.ticketState == TicketState.annule ? 'Annulé' : 'Valide',
          ok: p.ticketState == TicketState.valide,
          icon: Icons.confirmation_number_rounded,
        ),
        _StatusStep(
          title: 'Contrôle du billet',
          value: p.isControlled
              ? '${fmtTime(p.controlledAt)} · ${p.controlledBy ?? ''}'
              : 'Non contrôlé',
          ok: p.isControlled,
          icon: Icons.qr_code_scanner_rounded,
        ),
        _StatusStep(
          title: 'Présence à bord',
          value: p.boardedAt != null
              ? 'Confirmée à ${fmtTime(p.boardedAt)}'
              : 'À confirmer',
          ok: p.boardedAt != null,
          icon: Icons.how_to_reg_rounded,
        ),
        _StatusStep(
          title: 'Débarquement',
          value: p.isDisembarked
              ? 'À ${fmtTime(p.disembarkedAt)}'
              : 'En attente',
          ok: p.isDisembarked,
          icon: Icons.logout_rounded,
          last: true,
        ),
        if (isConv && p.isOnBoard && !atStop) ...[
          const SizedBox(height: 12),
          const InfoBanner(
            message:
                'Le débarquement se confirme à l’arrêt, une fois le car à quai.',
          ),
        ],
        if (isConv &&
            !p.isControlled &&
            p.ticketState == TicketState.valide) ...[
          const SizedBox(height: 12),
          InfoBanner(
            color: MoncarColors.warn,
            icon: Icons.warning_amber_rounded,
            message:
                'Billet non contrôlé : faites-le scanner par le contrôleur avant le départ.',
          ),
        ],
      ],
    );
  }
}

class _StatusStep extends StatelessWidget {
  const _StatusStep({
    required this.title,
    required this.value,
    required this.ok,
    required this.icon,
    this.last = false,
  });

  final String title;
  final String value;
  final bool ok;
  final IconData icon;
  final bool last;

  @override
  Widget build(BuildContext context) {
    final c = ok ? MoncarColors.success : MoncarColors.inkFaint;
    return Padding(
      padding: EdgeInsets.only(bottom: last ? 0 : 8),
      child: MoncarCard(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: c.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: c, size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      color: MoncarColors.ink,
                    ),
                  ),
                  Text(
                    value,
                    style: TextStyle(
                      fontSize: 12.5,
                      color: MoncarColors.inkMut,
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              ok
                  ? Icons.check_circle_rounded
                  : Icons.radio_button_unchecked_rounded,
              color: c,
            ),
          ],
        ),
      ),
    );
  }
}
