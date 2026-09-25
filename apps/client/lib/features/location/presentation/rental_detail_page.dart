import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../shared/foundation.dart';
import '../widgets/location_widgets.dart';

/// Suivi d'une location, de la demande à la clôture (§36 à §50).
/// L'écran met en avant l'action attendue selon le statut.
class RentalDetailPage extends ConsumerWidget {
  const RentalDetailPage({super.key, required this.rentalId});

  final String rentalId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.watch(mockStoreChangesProvider);
    final store = ref.read(mockStoreProvider);
    final r = store.findRental(rentalId);
    if (r == null) {
      return Scaffold(
        appBar: const TopBar(title: 'Location', showBack: true),
        body: MoncarEmptyState(
          icon: Icons.directions_car_outlined,
          title: 'Location introuvable',
          message: "Cette location n'existe pas ou plus.",
          actionLabel: 'Mes locations',
          onAction: () => context.go('/location/mine'),
        ),
      );
    }
    final v = store.findRentalVehicle(r.vehicleId);

    return Scaffold(
      backgroundColor: MoncarColors.background,
      appBar: TopBar(
        title: 'Ma location',
        subtitle: r.reference,
        showBack: true,
        showBell: false,
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
        children: [
          MoncarCard(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    if (v != null)
                      VehiclePhoto(
                        vehicle: v,
                        size: 56,
                        iconSize: 26,
                        radius: 12,
                      ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            r.vehicleSummary,
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                              color: MoncarColors.ink,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Row(
                            children: [
                              Flexible(
                                child: Text(
                                  r.providerName,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: MoncarColors.inkMut,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 6),
                              ProviderKindBadge(r.providerKind),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    RentalStatusBadge(r.status),
                    if (r.hasOpenIncident) ...[
                      const SizedBox(width: 6),
                      const MoncarBadge(
                        label: 'Dossier en cours',
                        tone: MoncarBadgeTone.danger,
                        size: MoncarBadgeSize.sm,
                        icon: Icons.gavel_outlined,
                      ),
                    ],
                  ],
                ),
                if (r.status != RentalStatus.annulee &&
                    r.status != RentalStatus.refusee) ...[
                  const SizedBox(height: 12),
                  RentalProgress(status: r.status),
                ],
              ],
            ),
          ),
          const SizedBox(height: 12),
          _StatusPanel(rental: r),
          if (r.pendingCharge != null) ...[
            const SizedBox(height: 12),
            _PendingChargeCard(rental: r),
          ],
          if (r.status == RentalStatus.active) ...[
            const SizedBox(height: 12),
            _ActiveActions(rental: r),
          ],
          if (r.returnCondition != null && r.startCondition != null) ...[
            const SizedBox(height: 16),
            const MoncarSectionHeader(title: 'État au départ / au retour'),
            _ConditionComparison(
              start: r.startCondition!,
              end: r.returnCondition!,
            ),
          ],
          if (r.extensions.isNotEmpty) ...[
            const SizedBox(height: 16),
            const MoncarSectionHeader(title: 'Prolongations'),
            for (final e in r.extensions)
              _SimpleRow(
                icon: Icons.more_time,
                title:
                    '${e.extraLabel} · jusqu\'au ${formatRentalIso(e.newEnd)}',
                subtitle: '${formatXOF(e.amountXOF)} · ${e.status.label}',
              ),
          ],
          if (r.incidents.isNotEmpty) ...[
            const SizedBox(height: 16),
            const MoncarSectionHeader(title: "Dossiers d'incident"),
            for (final i in r.incidents)
              _SimpleRow(
                icon: Icons.report_gmailerrorred_outlined,
                iconColor: MoncarColors.danger,
                title: '${i.nature.label} · ${i.status.label}',
                subtitle: '${formatRentalIso(i.at)}\n${i.description}',
              ),
            Padding(
              padding: const EdgeInsets.fromLTRB(4, 4, 4, 0),
              child: Text(
                "La responsabilité n'est jamais imputée automatiquement : "
                'elle est déterminée après examen du dossier.',
                style: TextStyle(fontSize: 11, color: MoncarColors.inkFaint),
              ),
            ),
          ],
          const SizedBox(height: 16),
          const MoncarSectionHeader(title: 'Détails de la location'),
          MoncarCard(
            padding: const EdgeInsets.all(14),
            child: InfoGrid(
              items: [
                (Icons.tag, 'Référence', r.reference),
                (
                  Icons.place_outlined,
                  'Prise en charge',
                  r.criteria.pickupLabel,
                ),
                (
                  Icons.swap_horiz,
                  'Déplacement',
                  '${r.criteria.area.label} · ${r.criteria.destination}',
                ),
                (Icons.event_note_outlined, 'Motif', r.criteria.purpose.label),
                (Icons.group_outlined, 'Personnes', '${r.criteria.persons}'),
                (
                  Icons.person_pin_outlined,
                  'Chauffeur',
                  r.withDriver
                      ? (r.driverName ??
                            'Avec chauffeur (communiqué à la remise)')
                      : 'Sans chauffeur',
                ),
                (
                  Icons.calendar_today_outlined,
                  'Début prévu',
                  formatRentalIso(r.plannedStart),
                ),
                if (r.handoverAt != null)
                  (
                    Icons.play_circle_outline,
                    'Début réel',
                    formatRentalIso(r.handoverAt),
                  ),
                (
                  Icons.event_available_outlined,
                  'Fin prévue',
                  formatRentalIso(r.plannedEnd),
                ),
                if (r.returnedAt != null)
                  (
                    Icons.stop_circle_outlined,
                    'Restitution',
                    formatRentalIso(r.returnedAt),
                  ),
                if (r.optionLabels.isNotEmpty)
                  (
                    Icons.add_circle_outline,
                    'Options',
                    r.optionLabels.join(', '),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          const MoncarSectionHeader(title: 'Facture'),
          RentalInvoiceCard(quote: r.quote),
          for (final c in r.extraCharges)
            _SimpleRow(
              icon: Icons.receipt_outlined,
              title: 'Facture complémentaire · ${c.label}',
              subtitle: '${formatXOF(c.amountXOF)} · réglée',
            ),
          if (r.paymentId != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(4, 8, 4, 0),
              child: Text(
                'Reçu de paiement : ${r.paymentId} · Total réglé ${formatXOF(r.paidTotalXOF)}',
                style: TextStyle(fontSize: 11.5, color: MoncarColors.inkMut),
              ),
            ),
          const SizedBox(height: 16),
          const MoncarSectionHeader(title: 'Historique'),
          MoncarCard(
            padding: const EdgeInsets.all(14),
            child: Column(
              children: [
                for (var i = r.timeline.length - 1; i >= 0; i--)
                  _TimelineRow(
                    event: r.timeline[i],
                    first: i == r.timeline.length - 1,
                    last: i == 0,
                  ),
              ],
            ),
          ),
          if (kDebugMode) ...[
            const SizedBox(height: 16),
            _ProviderSimulator(rental: r),
          ],
        ],
      ),
    );
  }
}

// ============================ Panneau de statut ============================

class _StatusPanel extends ConsumerWidget {
  const _StatusPanel({required this.rental});

  final Rental rental;

  Future<void> _cancel(BuildContext context, WidgetRef ref) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('Annuler la location ?'),
        content: Text(
          rental.status == RentalStatus.payee
              ? 'Le remboursement sera traité selon les conditions du fournisseur.'
              : 'Votre demande sera retirée. Aucun paiement ne sera effectué.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(c, false),
            child: const Text('Non'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(c, true),
            child: const Text('Oui, annuler'),
          ),
        ],
      ),
    );
    if (ok != true || !context.mounted) return;
    final r = ref.read(mockStoreProvider).cancelRental(rental.id);
    showMoncarToast(
      context,
      r.ok ? 'Location annulée' : (r.error ?? 'Annulation impossible.'),
      error: !r.ok,
      success: r.ok,
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final r = rental;
    Widget cancelButton() => TextButton(
      onPressed: () => _cancel(context, ref),
      style: TextButton.styleFrom(foregroundColor: MoncarColors.danger),
      child: Text(
        r.status == RentalStatus.demandee
            ? 'Annuler la demande'
            : 'Annuler la location',
      ),
    );

    return switch (r.status) {
      RentalStatus.demandee => _Panel(
        icon: Icons.hourglass_top_rounded,
        tone: MoncarColors.warn,
        title: 'EN ATTENTE DE CONFIRMATION',
        message:
            '${r.providerName} vérifie la disponibilité du véhicule. '
            'Vous serez notifié dès sa réponse. Aucun paiement pour le moment.',
        children: [cancelButton()],
      ),
      RentalStatus.refusee => _Panel(
        icon: Icons.cancel_outlined,
        tone: MoncarColors.danger,
        title: "Votre demande n'a pas été confirmée.",
        message:
            '${r.refusalReason ?? ''}\nAucun paiement de la location n\'a été effectué.'
                .trim(),
        children: [
          MoncarButton(
            label: 'Chercher un autre véhicule',
            icon: Icons.search,
            variant: MoncarButtonVariant.primary,
            size: MoncarButtonSize.lg,
            expand: true,
            onPressed: () => context.go('/location/results'),
          ),
        ],
      ),
      RentalStatus.confirmee => _Panel(
        icon: Icons.verified_outlined,
        tone: MoncarColors.success,
        title: 'Votre demande a été confirmée.',
        message: 'Vous pouvez procéder au paiement.',
        children: [
          MoncarButton(
            label: 'Payer ${formatXOF(r.quote.totalXOF)}',
            icon: Icons.lock_outline,
            variant: MoncarButtonVariant.primary,
            size: MoncarButtonSize.lg,
            expand: true,
            onPressed: () => context.push('/location/rental/${r.id}/pay'),
          ),
          cancelButton(),
        ],
      ),
      RentalStatus.payee => _Panel(
        icon: Icons.lock_clock_outlined,
        tone: MoncarColors.brand,
        title: 'Paiement confirmé — votre réservation est confirmée.',
        message:
            'Le montant reste sécurisé par MON CAR jusqu\'à la validation de la '
            'remise du véhicule. ${r.providerName} prépare le véhicule.',
        children: [
          const SizedBox(height: 4),
          InfoGrid(
            items: [
              (Icons.place_outlined, 'Lieu de remise', r.criteria.pickupLabel),
              (
                Icons.calendar_today_outlined,
                'Date et heure prévues',
                formatRentalIso(r.plannedStart),
              ),
              (Icons.directions_car_outlined, 'Véhicule', r.vehicleSummary),
              (Icons.storefront_outlined, 'Fournisseur', r.providerName),
              if (r.withDriver)
                (
                  Icons.person_pin_outlined,
                  'Chauffeur',
                  'Communiqué à la remise',
                ),
            ],
          ),
          cancelButton(),
        ],
      ),
      RentalStatus.remise => _Panel(
        icon: Icons.key_outlined,
        tone: MoncarColors.accent,
        title: 'Le véhicule vous a été remis',
        message:
            'Vérifiez le véhicule et enregistrez son état : cette étape crée la '
            'preuve de son état au début de la location.',
        children: [
          InfoGrid(
            items: [
              (Icons.schedule, 'Heure prévue', formatRentalIso(r.plannedStart)),
              (
                Icons.key_outlined,
                'Heure réelle',
                formatRentalIso(r.handoverAt),
              ),
              (
                Icons.timelapse,
                'Écart',
                r.handoverDelayMin == null
                    ? '—'
                    : formatDelay(r.handoverDelayMin!),
              ),
            ],
          ),
          const SizedBox(height: 8),
          MoncarButton(
            label: "Faire l'état des lieux",
            icon: Icons.fact_check_outlined,
            variant: MoncarButtonVariant.primary,
            size: MoncarButtonSize.lg,
            expand: true,
            onPressed: () => context.push('/location/rental/${r.id}/etat'),
          ),
        ],
      ),
      RentalStatus.active => _ActivePanel(rental: r),
      RentalStatus.restituee => _Panel(
        icon: Icons.assignment_return_outlined,
        tone: MoncarColors.brand,
        title: 'Véhicule restitué',
        message:
            'Restitué le ${formatRentalIso(r.returnedAt)}. ${r.providerName} '
            'compare l\'état au départ et au retour.',
      ),
      RentalStatus.terminee => _Panel(
        icon: Icons.task_alt,
        tone: MoncarColors.success,
        title: 'Location terminée',
        message:
            'Merci d\'avoir loué avec MON CAR. Total réglé : ${formatXOF(r.paidTotalXOF)}.',
        children: [_RatingBlock(rental: r)],
      ),
      RentalStatus.annulee => _Panel(
        icon: Icons.block,
        tone: MoncarColors.inkMut,
        title: 'Location annulée',
        message: r.timeline.isEmpty ? '' : r.timeline.last.label,
      ),
    };
  }
}

class _Panel extends StatelessWidget {
  const _Panel({
    required this.icon,
    required this.tone,
    required this.title,
    required this.message,
    this.children = const [],
  });

  final IconData icon;
  final Color tone;
  final String title;
  final String message;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: MoncarColors.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: tone.withValues(alpha: 0.35), width: 1.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: tone.withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, size: 22, color: tone),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                        color: MoncarColors.ink,
                      ),
                    ),
                    if (message.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        message,
                        style: TextStyle(
                          fontSize: 12.5,
                          height: 1.45,
                          color: MoncarColors.inkMut,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
          if (children.isNotEmpty) ...[const SizedBox(height: 12), ...children],
        ],
      ),
    );
  }
}

/// LOCATION ACTIVE (§44) + rappel d'échéance (§47).
class _ActivePanel extends StatelessWidget {
  const _ActivePanel({required this.rental});

  final Rental rental;

  @override
  Widget build(BuildContext context) {
    final r = rental;
    final end = DateTime.parse(r.plannedEnd);
    final left = end.difference(DateTime.now());
    final soon = left.inHours < 3;
    final start = DateTime.tryParse(r.handoverAt ?? '');
    final elapsed = start == null ? null : DateTime.now().difference(start);
    return _Panel(
      icon: Icons.directions_car,
      tone: MoncarColors.success,
      title: 'LOCATION ACTIVE',
      message: left.isNegative
          ? 'Échéance dépassée : des heures supplémentaires peuvent s\'appliquer.'
          : 'Fin prévue le ${formatRentalIso(r.plannedEnd)}.',
      children: [
        if (soon && !left.isNegative)
          Container(
            margin: const EdgeInsets.only(bottom: 10),
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: MoncarColors.warnSoft,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                Icon(Icons.alarm, size: 16, color: MoncarColors.warn),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Échéance proche : prolongez ou préparez la restitution.',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: MoncarColors.ink,
                    ),
                  ),
                ),
              ],
            ),
          ),
        InfoGrid(
          items: [
            (
              Icons.play_circle_outline,
              'Début réel',
              formatRentalIso(r.handoverAt),
            ),
            (
              Icons.event_available_outlined,
              'Fin prévue',
              formatRentalIso(r.plannedEnd),
            ),
            if (elapsed != null)
              (
                Icons.timelapse,
                'Durée écoulée',
                '${elapsed.inHours} h ${(elapsed.inMinutes % 60).toString().padLeft(2, '0')}',
              ),
            (Icons.flag_outlined, 'Destination', r.criteria.destination),
            if (r.withDriver)
              (Icons.person_pin_outlined, 'Chauffeur', r.driverName ?? '—'),
          ],
        ),
      ],
    );
  }
}

class _ActiveActions extends ConsumerWidget {
  const _ActiveActions({required this.rental});

  final Rental rental;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final pendingExt = rental.extensions.any(
      (e) => e.status == RentalExtensionStatus.demandee,
    );
    return Row(
      children: [
        Expanded(
          child: MoncarButton(
            label: pendingExt ? 'Prolongation en attente' : 'Prolonger',
            icon: Icons.more_time,
            variant: MoncarButtonVariant.brand,
            size: MoncarButtonSize.md,
            expand: true,
            onPressed: pendingExt || rental.pendingCharge != null
                ? null
                : () => showExtensionSheet(context, ref, rental),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: MoncarButton(
            label: 'Incident',
            icon: Icons.report_gmailerrorred_outlined,
            variant: MoncarButtonVariant.outline,
            size: MoncarButtonSize.md,
            expand: true,
            onPressed: () => showIncidentSheet(context, ref, rental),
          ),
        ),
      ],
    );
  }
}

class _PendingChargeCard extends StatelessWidget {
  const _PendingChargeCard({required this.rental});

  final Rental rental;

  @override
  Widget build(BuildContext context) {
    final c = rental.pendingCharge!;
    return MoncarCard(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(Icons.receipt_long_outlined, color: MoncarColors.accent),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Facture complémentaire · ${c.label}',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: MoncarColors.ink,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          for (final l in c.lines)
            RecapRow(label: l.label, value: formatXOF(l.amountXOF)),
          const SizedBox(height: 8),
          MoncarButton(
            label: 'Payer ${formatXOF(c.amountXOF)}',
            icon: Icons.lock_outline,
            variant: MoncarButtonVariant.primary,
            size: MoncarButtonSize.lg,
            expand: true,
            onPressed: () => context.push('/location/rental/${rental.id}/pay'),
          ),
        ],
      ),
    );
  }
}

class _ConditionComparison extends StatelessWidget {
  const _ConditionComparison({required this.start, required this.end});

  final VehicleCondition start;
  final VehicleCondition end;

  @override
  Widget build(BuildContext context) {
    TextStyle h = TextStyle(
      fontSize: 11,
      fontWeight: FontWeight.w700,
      color: MoncarColors.inkMut,
    );
    TextStyle cell = TextStyle(fontSize: 12.5, color: MoncarColors.ink);
    TableRow row(String label, Widget a, Widget b) => TableRow(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Text(
            label,
            style: TextStyle(fontSize: 12, color: MoncarColors.inkMut),
          ),
        ),
        Padding(padding: const EdgeInsets.symmetric(vertical: 8), child: a),
        Padding(padding: const EdgeInsets.symmetric(vertical: 8), child: b),
      ],
    );
    return MoncarCard(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Table(
            columnWidths: const {
              0: FlexColumnWidth(1.1),
              1: FlexColumnWidth(1.4),
              2: FlexColumnWidth(1.4),
            },
            children: [
              TableRow(
                children: [
                  const SizedBox(),
                  Text('DÉPART', style: h),
                  Text('RETOUR', style: h),
                ],
              ),
              row(
                'Kilométrage',
                Text('${start.mileageKm} km', style: cell),
                Text('${end.mileageKm} km', style: cell),
              ),
              row(
                'Carburant',
                FuelGauge(eighths: start.fuelEighths, compact: true),
                FuelGauge(eighths: end.fuelEighths, compact: true),
              ),
              row(
                'Photos',
                Text('${start.photos.length}', style: cell),
                Text('${end.photos.length}', style: cell),
              ),
              row(
                'Dommages',
                Text(
                  start.damages.isEmpty ? 'Aucun' : start.damages,
                  style: cell,
                ),
                Text(end.damages.isEmpty ? 'Aucun' : end.damages, style: cell),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            'Distance parcourue : ${end.mileageKm - start.mileageKm} km',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: MoncarColors.inkMut,
            ),
          ),
        ],
      ),
    );
  }
}

class _SimpleRow extends StatelessWidget {
  const _SimpleRow({
    required this.icon,
    required this.title,
    required this.subtitle,
    this.iconColor,
  });

  final IconData icon;
  final Color? iconColor;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: MoncarCard(
        padding: const EdgeInsets.all(12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, size: 18, color: iconColor ?? MoncarColors.brand),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: MoncarColors.ink,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: TextStyle(fontSize: 12, color: MoncarColors.inkMut),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TimelineRow extends StatelessWidget {
  const _TimelineRow({
    required this.event,
    required this.first,
    required this.last,
  });

  final RentalEvent event;
  final bool first;
  final bool last;

  @override
  Widget build(BuildContext context) {
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            width: 20,
            child: Column(
              children: [
                Container(
                  width: 10,
                  height: 10,
                  margin: const EdgeInsets.only(top: 4),
                  decoration: BoxDecoration(
                    color: first ? MoncarColors.accent : MoncarColors.brand,
                    shape: BoxShape.circle,
                  ),
                ),
                if (!last)
                  Expanded(
                    child: Container(width: 2, color: MoncarColors.hairline),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Padding(
              padding: EdgeInsets.only(bottom: last ? 0 : 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    event.label,
                    style: TextStyle(
                      fontSize: 12.5,
                      fontWeight: first ? FontWeight.w700 : FontWeight.w500,
                      color: MoncarColors.ink,
                    ),
                  ),
                  Text(
                    formatRentalIso(event.at),
                    style: TextStyle(
                      fontSize: 11,
                      color: MoncarColors.inkFaint,
                    ),
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

// ============================ Évaluation (§50) ============================

class _RatingBlock extends ConsumerStatefulWidget {
  const _RatingBlock({required this.rental});

  final Rental rental;

  @override
  ConsumerState<_RatingBlock> createState() => _RatingBlockState();
}

class _RatingBlockState extends ConsumerState<_RatingBlock> {
  int _stars = 0;
  final _comment = TextEditingController();

  @override
  void dispose() {
    _comment.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final rated = widget.rental.rating;
    if (rated != null) {
      return Row(
        children: [
          Text(
            'Votre note : ',
            style: TextStyle(fontSize: 12.5, color: MoncarColors.inkMut),
          ),
          for (var i = 0; i < 5; i++)
            Icon(
              i < rated ? Icons.star_rounded : Icons.star_outline_rounded,
              size: 18,
              color: MoncarColors.accent,
            ),
        ],
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Évaluez votre location',
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            color: MoncarColors.ink,
          ),
        ),
        Row(
          children: [
            for (var i = 1; i <= 5; i++)
              IconButton(
                tooltip: '$i étoile${i > 1 ? 's' : ''}',
                onPressed: () => setState(() => _stars = i),
                icon: Icon(
                  i <= _stars ? Icons.star_rounded : Icons.star_outline_rounded,
                  color: MoncarColors.accent,
                  size: 30,
                ),
              ),
          ],
        ),
        MoncarTextField(
          controller: _comment,
          hint: 'Votre avis sur le véhicule et le fournisseur (facultatif)',
          maxLines: 3,
        ),
        const SizedBox(height: 10),
        MoncarButton(
          label: 'Envoyer mon évaluation',
          variant: MoncarButtonVariant.brand,
          size: MoncarButtonSize.md,
          expand: true,
          onPressed: _stars == 0
              ? null
              : () {
                  ref
                      .read(mockStoreProvider)
                      .rateRental(
                        widget.rental.id,
                        _stars,
                        _comment.text.trim(),
                      );
                  showMoncarToast(
                    context,
                    'Merci pour votre avis !',
                    success: true,
                  );
                },
        ),
      ],
    );
  }
}

// ============================ Prolongation (§45) ============================

Future<void> showExtensionSheet(
  BuildContext context,
  WidgetRef ref,
  Rental rental,
) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: MoncarColors.surface,
    builder: (_) => _ExtensionSheet(rental: rental),
  );
}

class _ExtensionSheet extends ConsumerStatefulWidget {
  const _ExtensionSheet({required this.rental});

  final Rental rental;

  @override
  ConsumerState<_ExtensionSheet> createState() => _ExtensionSheetState();
}

class _ExtensionSheetState extends ConsumerState<_ExtensionSheet> {
  int _days = 1;
  bool _sending = false;

  @override
  Widget build(BuildContext context) {
    final store = ref.read(mockStoreProvider);
    final preview = store.previewExtension(widget.rental.id, _days);
    final v = store.findRentalVehicle(widget.rental.vehicleId);
    return Padding(
      padding: EdgeInsets.fromLTRB(
        20,
        16,
        20,
        16 + MediaQuery.viewInsetsOf(context).bottom,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Prolonger ma location',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w800,
              color: MoncarColors.ink,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Fin actuelle : ${formatRentalIso(widget.rental.plannedEnd)}',
            style: TextStyle(fontSize: 12.5, color: MoncarColors.inkMut),
          ),
          const SizedBox(height: 16),
          const OverlineText('Durée supplémentaire'),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final d in const [1, 2, 3, 7])
                MoncarChip(
                  label: d == 7 ? '+1 semaine' : '+$d jour${d > 1 ? 's' : ''}',
                  active: _days == d,
                  onTap: () => setState(() => _days = d),
                ),
            ],
          ),
          const SizedBox(height: 16),
          MoncarCard(
            padding: const EdgeInsets.all(14),
            child: InfoGrid(
              items: [
                (
                  Icons.event_available_outlined,
                  'Nouvelle fin',
                  formatRentalIso(preview.newEnd),
                ),
                (
                  Icons.payments_outlined,
                  'Supplément',
                  formatXOF(preview.amountXOF),
                ),
                (
                  preview.available ? Icons.check_circle_outline : Icons.block,
                  'Disponibilité',
                  preview.available ? 'Véhicule disponible' : 'Indisponible',
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          Text(
            (v?.requiresExtensionApproval ?? true)
                ? 'Le fournisseur doit accepter la prolongation. Une facture '
                      'complémentaire vous sera ensuite proposée.'
                : 'Prolongation immédiate : réglez la facture complémentaire pour valider la nouvelle échéance.',
            style: TextStyle(fontSize: 11.5, color: MoncarColors.inkFaint),
          ),
          if (preview.error != null) ...[
            const SizedBox(height: 8),
            MoncarInlineError(message: preview.error!),
          ],
          const SizedBox(height: 16),
          MoncarButton(
            label: 'Demander la prolongation',
            variant: MoncarButtonVariant.primary,
            size: MoncarButtonSize.lg,
            expand: true,
            isLoading: _sending,
            onPressed: !preview.available || _sending
                ? null
                : () async {
                    setState(() => _sending = true);
                    await Future<void>.delayed(
                      const Duration(milliseconds: 400),
                    );
                    final r = store.requestExtension(
                      widget.rental.id,
                      extraDays: _days,
                    );
                    if (!context.mounted) return;
                    Navigator.pop(context);
                    showMoncarToast(
                      context,
                      r.ok
                          ? (r.extension!.status ==
                                    RentalExtensionStatus.demandee
                                ? 'Demande de prolongation envoyée'
                                : 'Prolongation disponible : réglez la facture')
                          : (r.error ?? 'Prolongation impossible.'),
                      success: r.ok,
                      error: !r.ok,
                    );
                  },
          ),
        ],
      ),
    );
  }
}

// ============================ Incident (§49) ============================

Future<void> showIncidentSheet(
  BuildContext context,
  WidgetRef ref,
  Rental rental,
) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: MoncarColors.surface,
    builder: (_) => _IncidentSheet(rental: rental),
  );
}

class _IncidentSheet extends ConsumerStatefulWidget {
  const _IncidentSheet({required this.rental});

  final Rental rental;

  @override
  ConsumerState<_IncidentSheet> createState() => _IncidentSheetState();
}

class _IncidentSheetState extends ConsumerState<_IncidentSheet> {
  RentalIncidentNature _nature = RentalIncidentNature.panne;
  final _desc = TextEditingController();
  bool _submitted = false;

  @override
  void dispose() {
    _desc.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final tooShort = _desc.text.trim().length < 10;
    return Padding(
      padding: EdgeInsets.fromLTRB(
        20,
        16,
        20,
        16 + MediaQuery.viewInsetsOf(context).bottom,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Signaler un incident',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w800,
              color: MoncarColors.ink,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Un dossier est créé avec la date, l\'heure et le lieu. La '
            'responsabilité sera déterminée après examen.',
            style: TextStyle(fontSize: 12, color: MoncarColors.inkMut),
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final n in RentalIncidentNature.values)
                if (n != RentalIncidentNature.anomalie)
                  MoncarChip(
                    label: n.label,
                    active: _nature == n,
                    onTap: () => setState(() => _nature = n),
                  ),
            ],
          ),
          const SizedBox(height: 12),
          MoncarTextField(
            controller: _desc,
            label: 'Que s\'est-il passé ?',
            hint: 'Décrivez le problème (lieu, circonstances…)',
            maxLines: 4,
            error: _submitted && tooShort
                ? 'Décrivez le problème (10 caractères minimum).'
                : null,
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: 16),
          MoncarButton(
            label: 'Créer le dossier',
            variant: MoncarButtonVariant.danger,
            size: MoncarButtonSize.lg,
            expand: true,
            onPressed: () {
              setState(() => _submitted = true);
              if (tooShort) return;
              ref
                  .read(mockStoreProvider)
                  .reportRentalIncident(
                    widget.rental.id,
                    nature: _nature,
                    description: _desc.text.trim(),
                  );
              Navigator.pop(context);
              showMoncarToast(
                context,
                "Dossier d'incident créé. Le support MON CAR vous recontacte.",
                success: true,
              );
            },
          ),
        ],
      ),
    );
  }
}

// ======================= Simulation fournisseur (debug) =======================

/// ⚠️ MOCK (builds debug uniquement) : les réponses du fournisseur
/// viendront de l'app PRO / espace BUSINESS. Ce panneau permet de
/// dérouler tout le cycle de vie sur l'app client en attendant.
class _ProviderSimulator extends ConsumerWidget {
  const _ProviderSimulator({required this.rental});

  final Rental rental;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final store = ref.read(mockStoreProvider);
    final r = rental;
    final pendingExt = r.extensions
        .where((e) => e.status == RentalExtensionStatus.demandee)
        .firstOrNull;
    final actions = <(String, VoidCallback)>[
      if (r.status == RentalStatus.demandee) ...[
        (
          'Confirmer la demande',
          () => store.providerRespond(r.id, accept: true),
        ),
        (
          'Refuser la demande',
          () => store.providerRespond(r.id, accept: false),
        ),
      ],
      if (r.status == RentalStatus.payee)
        ('Remettre le véhicule', () => store.providerHandover(r.id)),
      if (pendingExt != null) ...[
        (
          'Accepter la prolongation',
          () =>
              store.providerRespondExtension(r.id, pendingExt.id, accept: true),
        ),
        (
          'Refuser la prolongation',
          () => store.providerRespondExtension(
            r.id,
            pendingExt.id,
            accept: false,
          ),
        ),
      ],
      if (r.status == RentalStatus.active) ...[
        ('Récupérer le véhicule', () => store.providerRecordReturn(r.id)),
        (
          'Récupérer avec 2 h de retard',
          () => store.providerRecordReturn(r.id, lateHours: 2),
        ),
      ],
      if (r.status == RentalStatus.restituee)
        (
          'Clôturer le contrôle',
          () {
            final res = store.providerCloseRental(r.id);
            if (!res.ok) showMoncarToast(context, res.error!, error: true);
          },
        ),
    ];
    if (actions.isEmpty) return const SizedBox.shrink();
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: MoncarColors.hairline, width: 1.5),
        color: MoncarColors.muted,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'SIMULATION FOURNISSEUR · DÉMO',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.4,
              color: MoncarColors.inkMut,
            ),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final (label, action) in actions)
                OutlinedButton(onPressed: action, child: Text(label)),
            ],
          ),
        ],
      ),
    );
  }
}
