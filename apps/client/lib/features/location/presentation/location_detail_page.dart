import 'package:flutter/material.dart';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../shared/foundation.dart';
import '../data/vehicle_reviews.dart';
import '../widgets/location_widgets.dart';

IconData _featureIcon(String label) => switch (label) {
  'Climatisation' => Icons.ac_unit,
  'Bluetooth' => Icons.bluetooth,
  'GPS' => Icons.navigation_outlined,
  'Caméra recul' => Icons.videocam_outlined,
  'Wi-Fi' || 'WiFi' || 'TV' => Icons.wifi,
  '4x4' || 'Prise USB' => Icons.bolt,
  'Bar' => Icons.wine_bar_outlined,
  'Sono' => Icons.speaker_outlined,
  'Toilettes' => Icons.wc_outlined,
  'Soute à bagages' || 'Volume 12m³' || 'Hayon' => Icons.work_outline,
  'Cuir' ||
  'Sièges cuir' ||
  'Sièges confort' ||
  'Sièges inclinables' => Icons.weekend_outlined,
  'Service VIP' => Icons.verified_user_outlined,
  _ => Icons.check_circle_outline,
};

/// Fiche du véhicule (§35) : galerie, caractéristiques, fournisseur,
/// avis et tarification applicable à la demande (options comprises).
class LocationDetailPage extends ConsumerStatefulWidget {
  const LocationDetailPage({super.key, required this.vehicleId});

  final String vehicleId;

  @override
  ConsumerState<LocationDetailPage> createState() => _LocationDetailPageState();
}

class _LocationDetailPageState extends ConsumerState<LocationDetailPage> {
  final Set<String> _options = {};
  int _photo = 0;

  @override
  Widget build(BuildContext context) {
    final store = ref.read(mockStoreProvider);
    final v = store.findRentalVehicle(widget.vehicleId);
    if (v == null) {
      return Scaffold(
        appBar: const TopBar(title: 'Fiche du véhicule', showBack: true),
        body: MoncarEmptyState(
          icon: Icons.directions_car_outlined,
          title: 'Véhicule introuvable',
          message: "Ce véhicule n'existe plus ou a été retiré de la flotte.",
          actionLabel: 'Retour',
          onAction: () => context.mcBack(),
        ),
      );
    }
    final search = ref.watch(rentalSearchProvider);
    final criteria = search.toCriteria();
    final quote = store.quoteRental(v, criteria, optionIds: _options.toList());
    final reviews = vehicleReviews(v);
    final compatible =
        (criteria.withDriver ? v.canBeWithDriver : v.canBeWithoutDriver) &&
        v.available;

    return Scaffold(
      backgroundColor: MoncarColors.background,
      appBar: TopBar(
        title: '${v.brand} ${v.model}',
        subtitle: v.partner,
        showBack: true,
        showBell: false,
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
        children: [
          // Galerie photos.
          SizedBox(
            height: 190,
            child: PageView.builder(
              itemCount: 4,
              onPageChanged: (i) => setState(() => _photo = i),
              itemBuilder: (_, i) => Padding(
                padding: const EdgeInsets.symmetric(horizontal: 2),
                child: VehiclePhoto(
                  vehicle: v,
                  size: double.infinity,
                  height: 190,
                  iconSize: 72,
                  radius: 20,
                  angle: i,
                  showUnavailable: true,
                ),
              ),
            ),
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              for (var i = 0; i < 4; i++)
                AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  width: i == _photo ? 18 : 6,
                  height: 6,
                  margin: const EdgeInsets.symmetric(horizontal: 3),
                  decoration: BoxDecoration(
                    color: i == _photo
                        ? MoncarColors.brand
                        : MoncarColors.hairline,
                    borderRadius: BorderRadius.circular(999),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              ProviderKindBadge(v.providerKind),
              const SizedBox(width: 6),
              MoncarBadge(
                label: vehicleLabel(v.type),
                tone: MoncarBadgeTone.neutral,
                size: MoncarBadgeSize.sm,
              ),
              const Spacer(),
              MoncarRating(value: v.rating, count: v.reviewCount),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            '${v.brand} ${v.model}',
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w800,
              color: MoncarColors.ink,
            ),
          ),
          Text(
            driverOfferLabel(v),
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: MoncarColors.success,
            ),
          ),
          const SizedBox(height: 16),
          const MoncarSectionHeader(title: 'Caractéristiques'),
          MoncarCard(
            padding: const EdgeInsets.all(14),
            child: InfoGrid(
              items: [
                (
                  Icons.directions_car_outlined,
                  'Marque / modèle',
                  '${v.brand} ${v.model}',
                ),
                (Icons.calendar_today_outlined, 'Année', '${v.year}'),
                (Icons.palette_outlined, 'Couleur', v.color),
                (Icons.event_seat_outlined, 'Places', '${v.seats}'),
                (
                  Icons.settings_outlined,
                  'Boîte',
                  v.transmissionIsAutomatic ? 'Automatique' : 'Manuelle',
                ),
                (
                  Icons.ac_unit,
                  'Climatisation',
                  v.hasAirConditioning ? 'Oui' : 'Non',
                ),
                (Icons.local_gas_station_outlined, 'Carburant', v.fuel),
                (
                  Icons.event_available_outlined,
                  'Disponibilité',
                  v.available ? 'Disponible sur vos dates' : 'Indisponible',
                ),
              ],
            ),
          ),
          if (v.features.isNotEmpty) ...[
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final f in v.features)
                  MoncarChip(label: f, icon: _featureIcon(f)),
              ],
            ),
          ],
          if (v.conditions.isNotEmpty) ...[
            const SizedBox(height: 16),
            const MoncarSectionHeader(title: 'Conditions'),
            MoncarCard(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  for (final c in v.conditions)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 3),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(
                            Icons.check,
                            size: 14,
                            color: MoncarColors.success,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              c,
                              style: TextStyle(
                                fontSize: 12.5,
                                color: MoncarColors.inkMut,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 16),
          const MoncarSectionHeader(title: 'Fournisseur'),
          MoncarCard(
            padding: const EdgeInsets.all(14),
            child: Row(
              children: [
                MoncarAvatar(
                  initials: v.partner
                      .split(' ')
                      .where((w) => w.isNotEmpty)
                      .take(2)
                      .map((w) => w[0])
                      .join()
                      .toUpperCase(),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        v.partner,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: MoncarColors.ink,
                        ),
                      ),
                      Text(
                        '${v.providerKind.label[0]}${v.providerKind.label.substring(1).toLowerCase()} · ${v.area}, ${v.city}',
                        style: TextStyle(
                          fontSize: 12,
                          color: MoncarColors.inkMut,
                        ),
                      ),
                    ],
                  ),
                ),
                TextButton(
                  onPressed: () =>
                      context.push('/location/veh/${v.id}/reviews'),
                  child: Text('${reviews.length} avis'),
                ),
              ],
            ),
          ),
          if (reviews.isNotEmpty) ...[
            const SizedBox(height: 8),
            ReviewCard(review: reviews.first),
          ],
          if (v.options.isNotEmpty) ...[
            const SizedBox(height: 16),
            const MoncarSectionHeader(title: 'Options'),
            MoncarCard(
              padding: EdgeInsets.zero,
              // Material propre : effets tactiles visibles sur la carte.
              child: Material(
                type: MaterialType.transparency,
                child: Column(
                  children: [
                    for (final o in v.options)
                      CheckboxListTile(
                        value: _options.contains(o.id),
                        onChanged: (on) => setState(
                          () => on == true
                              ? _options.add(o.id)
                              : _options.remove(o.id),
                        ),
                        title: Text(
                          o.label,
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: MoncarColors.ink,
                          ),
                        ),
                        subtitle: Text(
                          '${formatXOF(o.pricePerDayXOF)} / jour',
                          style: TextStyle(
                            fontSize: 12,
                            color: MoncarColors.inkMut,
                          ),
                        ),
                        activeColor: MoncarColors.accent,
                      ),
                  ],
                ),
              ),
            ),
          ],
          const SizedBox(height: 16),
          const MoncarSectionHeader(title: 'Tarif pour votre demande'),
          MoncarCard(
            padding: const EdgeInsets.all(14),
            child: InfoGrid(
              items: [
                (
                  Icons.swap_horiz,
                  'Déplacement',
                  criteria.area == RentalArea.exterieur
                      ? 'Extérieur → ${criteria.destination}'
                      : 'Intérieur (${criteria.pickupCity})',
                ),
                (Icons.schedule, 'Durée', quote.billableLabel),
                (
                  Icons.person_pin_outlined,
                  'Chauffeur',
                  criteria.withDriver ? 'Avec chauffeur' : 'Sans chauffeur',
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          RentalInvoiceCard(quote: quote),
          const SizedBox(height: 8),
          Text(
            "Estimation calculée par nos serveurs. Vous ne payez qu'après la confirmation du fournisseur.",
            style: TextStyle(fontSize: 11, color: MoncarColors.inkFaint),
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
                Expanded(
                  child: Text(
                    'Total estimé · ${quote.billableLabel}',
                    style: TextStyle(fontSize: 12, color: MoncarColors.inkMut),
                  ),
                ),
                Text(
                  formatXOF(quote.totalXOF),
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: MoncarColors.ink,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            MoncarButton(
              label: 'Demander une réservation',
              icon: Icons.send_outlined,
              variant: MoncarButtonVariant.primary,
              size: MoncarButtonSize.lg,
              expand: true,
              onPressed: !compatible
                  ? null
                  : () => context.push(
                      '/location/request/${v.id}'
                      '${_options.isEmpty ? '' : '?options=${_options.join(',')}'}',
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
