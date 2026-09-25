import 'package:flutter/material.dart';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../shared/foundation.dart';
import '../widgets/location_widgets.dart';

/// Catégories de « Mes locations » (§51). Une location peut figurer dans
/// plusieurs catégories (ex. payée et à venir).
enum RentalCategory {
  enAttente('Demandes en attente'),
  aPayer('Confirmées à payer'),
  payees('Payées'),
  aVenir('À venir'),
  enCours('En cours'),
  terminees('Terminées'),
  annulees('Annulées'),
  litiges('Litiges');

  const RentalCategory(this.label);
  final String label;

  bool matches(Rental r) {
    final paid = r.paymentId != null;
    return switch (this) {
      RentalCategory.enAttente => r.status == RentalStatus.demandee,
      RentalCategory.aPayer => r.status == RentalStatus.confirmee,
      RentalCategory.payees => paid && r.status != RentalStatus.annulee,
      RentalCategory.aVenir => r.status == RentalStatus.payee,
      RentalCategory.enCours =>
        r.status == RentalStatus.remise ||
            r.status == RentalStatus.active ||
            r.status == RentalStatus.restituee,
      RentalCategory.terminees => r.status == RentalStatus.terminee,
      RentalCategory.annulees =>
        r.status == RentalStatus.annulee || r.status == RentalStatus.refusee,
      RentalCategory.litiges => r.hasOpenIncident,
    };
  }
}

class MyRentalsPage extends ConsumerStatefulWidget {
  const MyRentalsPage({super.key});

  @override
  ConsumerState<MyRentalsPage> createState() => _MyRentalsPageState();
}

class _MyRentalsPageState extends ConsumerState<MyRentalsPage> {
  RentalCategory? _category;

  @override
  Widget build(BuildContext context) {
    ref.watch(mockStoreChangesProvider);
    final rentals = ref.read(mockStoreProvider).rentals;
    final list = [
      for (final r in rentals)
        if (_category == null || _category!.matches(r)) r,
    ];

    return Scaffold(
      backgroundColor: MoncarColors.background,
      appBar: const TopBar(
        title: 'Mes locations',
        showBack: true,
        showBell: false,
      ),
      body: Column(
        children: [
          Container(
            color: MoncarColors.surface,
            padding: const EdgeInsets.symmetric(vertical: 10),
            child: SizedBox(
              height: 36,
              child: ListView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                children: [
                  MoncarChip(
                    label: 'Toutes (${rentals.length})',
                    active: _category == null,
                    onTap: () => setState(() => _category = null),
                  ),
                  for (final c in RentalCategory.values) ...[
                    const SizedBox(width: 8),
                    MoncarChip(
                      label: '${c.label} (${rentals.where(c.matches).length})',
                      active: _category == c,
                      onTap: () => setState(() => _category = c),
                    ),
                  ],
                ],
              ),
            ),
          ),
          Divider(height: 1, color: MoncarColors.hairline),
          Expanded(
            child: list.isEmpty
                ? MoncarEmptyState(
                    icon: Icons.directions_car_outlined,
                    title: 'Aucune location',
                    message: _category == null
                        ? 'Vos demandes et locations apparaîtront ici.'
                        : 'Aucune location dans « ${_category!.label} ».',
                    actionLabel: 'Louer un véhicule',
                    onAction: () => context.go('/location'),
                  )
                : ListView.separated(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
                    itemCount: list.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 10),
                    itemBuilder: (_, i) => RentalListCard(rental: list[i]),
                  ),
          ),
        ],
      ),
    );
  }
}

/// Carte d'une location (Mes locations, historique).
class RentalListCard extends ConsumerWidget {
  const RentalListCard({super.key, required this.rental});

  final Rental rental;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final r = rental;
    final v = ref.read(mockStoreProvider).findRentalVehicle(r.vehicleId);
    final action = switch (r.status) {
      RentalStatus.confirmee => 'À payer',
      RentalStatus.remise => 'État des lieux à faire',
      _ when r.pendingCharge != null => 'Facture à régler',
      _ => null,
    };
    return MoncarCard(
      padding: const EdgeInsets.all(12),
      onTap: () => context.push('/location/rental/${r.id}'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              if (v != null)
                VehiclePhoto(vehicle: v, size: 52, iconSize: 24, radius: 12),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            r.vehicleSummary,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                              color: MoncarColors.ink,
                            ),
                          ),
                        ),
                        RentalStatusBadge(r.status),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${r.providerName} · ${r.reference}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 12,
                        color: MoncarColors.inkMut,
                      ),
                    ),
                    Text(
                      '${formatRentalIso(r.plannedStart)} · ${r.quote.billableLabel}',
                      style: TextStyle(
                        fontSize: 12,
                        color: MoncarColors.inkMut,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Icon(Icons.flag_outlined, size: 13, color: MoncarColors.inkFaint),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  '${r.criteria.pickupCity} → ${r.criteria.destination}'
                  '${r.withDriver ? ' · avec chauffeur' : ''}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 11.5, color: MoncarColors.inkMut),
                ),
              ),
              Text(
                formatXOF(r.quote.totalXOF),
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                  color: MoncarColors.ink,
                ),
              ),
            ],
          ),
          if (action != null || r.hasOpenIncident) ...[
            const SizedBox(height: 8),
            Row(
              children: [
                if (action != null)
                  MoncarBadge(
                    label: action,
                    tone: MoncarBadgeTone.accent,
                    size: MoncarBadgeSize.sm,
                    icon: Icons.arrow_forward,
                  ),
                if (r.hasOpenIncident) ...[
                  const SizedBox(width: 6),
                  const MoncarBadge(
                    label: 'Litige',
                    tone: MoncarBadgeTone.danger,
                    size: MoncarBadgeSize.sm,
                    icon: Icons.gavel_outlined,
                  ),
                ],
              ],
            ),
          ],
        ],
      ),
    );
  }
}
