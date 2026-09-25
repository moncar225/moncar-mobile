import 'package:flutter/material.dart';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../shared/foundation.dart';
import '../data/vehicle_reviews.dart';
import '../widgets/location_widgets.dart';

/// Tous les avis d'un véhicule : note moyenne, répartition par étoiles
/// et liste filtrable.
class VehicleReviewsPage extends ConsumerStatefulWidget {
  const VehicleReviewsPage({super.key, required this.vehicleId});

  final String vehicleId;

  @override
  ConsumerState<VehicleReviewsPage> createState() => _VehicleReviewsPageState();
}

class _VehicleReviewsPageState extends ConsumerState<VehicleReviewsPage> {
  /// Filtre par nombre d'étoiles (`null` = tous).
  int? _stars;

  @override
  Widget build(BuildContext context) {
    final v = ref.read(mockStoreProvider).findRentalVehicle(widget.vehicleId);
    if (v == null) {
      return Scaffold(
        appBar: const TopBar(title: 'Avis clients', showBack: true),
        body: MoncarEmptyState(
          icon: Icons.directions_car_outlined,
          title: 'Véhicule introuvable',
          message: "Ce véhicule n'existe plus ou a été retiré de la flotte.",
          actionLabel: 'Retour',
          onAction: () => context.mcBack(),
        ),
      );
    }
    final all = vehicleReviews(v);
    final shown = _stars == null
        ? all
        : all.where((r) => r.rating == _stars).toList();
    final counts = {
      for (var s = 5; s >= 1; s--) s: all.where((r) => r.rating == s).length,
    };

    return Scaffold(
      backgroundColor: MoncarColors.background,
      appBar: TopBar(
        title: 'Avis clients',
        subtitle: '${v.brand} ${v.model}',
        showBack: true,
        showBell: false,
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
        children: [
          MoncarCard(
            child: Row(
              children: [
                Column(
                  children: [
                    Text(
                      v.rating.toStringAsFixed(1).replaceAll('.', ','),
                      style: TextStyle(
                        fontSize: 36,
                        fontWeight: FontWeight.w800,
                        color: MoncarColors.ink,
                      ),
                    ),
                    Row(
                      children: [
                        for (var i = 1; i <= 5; i++)
                          Icon(
                            i <= v.rating.round()
                                ? Icons.star_rounded
                                : Icons.star_outline_rounded,
                            size: 14,
                            color: MoncarColors.accent,
                          ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${v.reviewCount} avis',
                      style: TextStyle(
                        fontSize: 11,
                        color: MoncarColors.inkMut,
                      ),
                    ),
                  ],
                ),
                const SizedBox(width: 20),
                Expanded(
                  child: Column(
                    children: [
                      for (var s = 5; s >= 1; s--)
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 2),
                          child: Row(
                            children: [
                              SizedBox(
                                width: 14,
                                child: Text(
                                  '$s',
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: MoncarColors.inkMut,
                                  ),
                                ),
                              ),
                              Expanded(
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(999),
                                  child: LinearProgressIndicator(
                                    value: all.isEmpty
                                        ? 0
                                        : counts[s]! / all.length,
                                    minHeight: 6,
                                    backgroundColor: MoncarColors.hairline,
                                    color: MoncarColors.accent,
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
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 36,
            child: ListView(
              scrollDirection: Axis.horizontal,
              children: [
                MoncarChip(
                  label: 'Tous (${all.length})',
                  active: _stars == null,
                  onTap: () => setState(() => _stars = null),
                ),
                for (var s = 5; s >= 2; s--)
                  if (counts[s]! > 0) ...[
                    const SizedBox(width: 8),
                    MoncarChip(
                      label: '$s ★ (${counts[s]})',
                      active: _stars == s,
                      onTap: () => setState(() => _stars = s),
                    ),
                  ],
              ],
            ),
          ),
          const SizedBox(height: 12),
          if (shown.isEmpty)
            const MoncarEmptyState(
              icon: Icons.rate_review_outlined,
              title: 'Aucun avis',
              message: 'Aucun avis ne correspond à ce filtre.',
            )
          else
            for (final r in shown) ...[
              ReviewCard(review: r),
              const SizedBox(height: 10),
            ],
          if (v.reviewCount > all.length)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                'Affichage des ${all.length} avis les plus récents sur ${v.reviewCount}.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 11, color: MoncarColors.inkFaint),
              ),
            ),
        ],
      ),
    );
  }
}
