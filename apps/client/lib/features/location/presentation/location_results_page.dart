import 'package:flutter/material.dart';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../shared/foundation.dart';
import '../widgets/location_widgets.dart';

enum _Sort { price, rating }

/// Résultats de la recherche de location (§33-34) : seuls les véhicules
/// compatibles avec la capacité, la zone, le chauffeur et les dates.
class LocationResultsPage extends ConsumerStatefulWidget {
  const LocationResultsPage({super.key});

  @override
  ConsumerState<LocationResultsPage> createState() =>
      _LocationResultsPageState();
}

class _LocationResultsPageState extends ConsumerState<LocationResultsPage> {
  _Sort _sort = _Sort.price;
  RentalProviderKind? _kind;
  List<RentalVehicle>? _results;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _results = null);
    // ⚠️ MOCK : GET /rentals/vehicles (latence simulée).
    await Future<void>.delayed(const Duration(milliseconds: 400));
    if (!mounted) return;
    final criteria = ref.read(rentalSearchProvider).toCriteria();
    setState(
      () =>
          _results = ref.read(mockStoreProvider).searchRentalVehicles(criteria),
    );
  }

  @override
  Widget build(BuildContext context) {
    final search = ref.watch(rentalSearchProvider);
    final criteria = search.toCriteria();
    final store = ref.read(mockStoreProvider);
    final all = _results;
    final list = [
      for (final v in all ?? const <RentalVehicle>[])
        if (_kind == null || v.providerKind == _kind) v,
    ];
    final quotes = {for (final v in list) v.id: store.quoteRental(v, criteria)};
    list.sort(
      (a, b) => _sort == _Sort.price
          ? quotes[a.id]!.totalXOF.compareTo(quotes[b.id]!.totalXOF)
          : b.rating.compareTo(a.rating),
    );

    return Scaffold(
      backgroundColor: MoncarColors.background,
      appBar: TopBar(
        title: 'Véhicules disponibles',
        subtitle:
            '${search.pickupCity} · ${search.area.label.toLowerCase()} · ${search.persons} pers.',
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
                    label: 'Prix',
                    active: _sort == _Sort.price,
                    onTap: () => setState(() => _sort = _Sort.price),
                  ),
                  const SizedBox(width: 8),
                  MoncarChip(
                    label: 'Note',
                    active: _sort == _Sort.rating,
                    onTap: () => setState(() => _sort = _Sort.rating),
                  ),
                  const SizedBox(width: 16),
                  MoncarChip(
                    label: 'Tous',
                    active: _kind == null,
                    onTap: () => setState(() => _kind = null),
                  ),
                  for (final k in RentalProviderKind.values) ...[
                    const SizedBox(width: 8),
                    MoncarChip(
                      label: k.label[0] + k.label.substring(1).toLowerCase(),
                      active: _kind == k,
                      onTap: () => setState(() => _kind = k),
                    ),
                  ],
                ],
              ),
            ),
          ),
          Divider(height: 1, color: MoncarColors.hairline),
          Expanded(
            child: all == null
                ? const Padding(
                    padding: EdgeInsets.all(16),
                    child: MoncarListSkeleton(count: 3),
                  )
                : list.isEmpty
                ? MoncarEmptyState(
                    icon: Icons.directions_car_outlined,
                    title: 'Aucun véhicule compatible',
                    message:
                        'Aucun véhicule ne correspond à la capacité, la zone, '
                        'le chauffeur ou la période demandés. Modifiez vos critères.',
                    actionLabel: 'Modifier la recherche',
                    onAction: () => context.mcBack(),
                  )
                : RefreshIndicator(
                    onRefresh: _load,
                    child: ListView.separated(
                      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
                      itemCount: list.length + 1,
                      separatorBuilder: (_, _) => const SizedBox(height: 12),
                      itemBuilder: (context, i) {
                        if (i == 0) {
                          final n = list.length;
                          return Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 4),
                            child: Text(
                              '$n véhicule${n > 1 ? 's' : ''} · '
                              '${formatRentalDateTime(search.start)} → '
                              '${formatRentalDateTime(search.end)}',
                              style: TextStyle(
                                fontSize: 12,
                                color: MoncarColors.inkMut,
                              ),
                            ),
                          );
                        }
                        final v = list[i - 1];
                        return _ResultCard(
                          vehicle: v,
                          quote: quotes[v.id]!,
                          withDriver: criteria.withDriver,
                          onTap: () => context.push('/location/veh/${v.id}'),
                        );
                      },
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}

/// Résultat (§34) : photo, marque, modèle, année, catégorie, places,
/// climatisation, boîte, chauffeur, localisation, prix, disponibilité,
/// note, fournisseur, conditions.
class _ResultCard extends StatelessWidget {
  const _ResultCard({
    required this.vehicle,
    required this.quote,
    required this.withDriver,
    required this.onTap,
  });

  final RentalVehicle vehicle;
  final RentalQuote quote;
  final bool withDriver;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final v = vehicle;
    TextStyle meta = TextStyle(fontSize: 11.5, color: MoncarColors.inkMut);
    Widget spec(IconData icon, String text) => Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 13, color: MoncarColors.inkMut),
        const SizedBox(width: 3),
        Text(text, style: meta),
      ],
    );
    return MoncarCard(
      padding: EdgeInsets.zero,
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                VehiclePhoto(vehicle: v, size: 96, iconSize: 40),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          ProviderKindBadge(v.providerKind),
                          const Spacer(),
                          Icon(
                            Icons.star_rounded,
                            size: 14,
                            color: MoncarColors.accent,
                          ),
                          Text(
                            ' ${v.rating.toStringAsFixed(1)}',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: MoncarColors.ink,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(
                        '${v.brand} ${v.model}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: MoncarColors.ink,
                        ),
                      ),
                      Text(
                        '${v.year} · ${vehicleLabel(v.type)} · ${v.partner}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: meta,
                      ),
                      const SizedBox(height: 6),
                      Wrap(
                        spacing: 10,
                        runSpacing: 4,
                        children: [
                          spec(Icons.event_seat_outlined, '${v.seats} places'),
                          if (v.hasAirConditioning) spec(Icons.ac_unit, 'Clim'),
                          spec(
                            Icons.settings_outlined,
                            v.transmissionIsAutomatic ? 'Auto' : 'Manuelle',
                          ),
                          spec(Icons.place_outlined, '${v.area}, ${v.city}'),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
            decoration: BoxDecoration(
              border: Border(top: BorderSide(color: MoncarColors.hairline)),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(
                            withDriver ? Icons.person_pin : Icons.key_outlined,
                            size: 13,
                            color: MoncarColors.success,
                          ),
                          const SizedBox(width: 4),
                          Flexible(
                            child: Text(
                              '${withDriver ? 'Avec chauffeur' : 'Sans chauffeur'} · Disponible',
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 11.5,
                                fontWeight: FontWeight.w600,
                                color: MoncarColors.success,
                              ),
                            ),
                          ),
                        ],
                      ),
                      if (v.conditions.isNotEmpty)
                        Text(
                          v.conditions.first,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 11,
                            color: MoncarColors.inkFaint,
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      formatXOF(quote.totalXOF),
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: MoncarColors.accent,
                      ),
                    ),
                    Text(
                      'total estimé · ${quote.billableLabel}',
                      style: TextStyle(
                        fontSize: 10.5,
                        color: MoncarColors.inkFaint,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
