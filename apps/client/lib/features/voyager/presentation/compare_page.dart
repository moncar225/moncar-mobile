import 'package:flutter/material.dart';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../shared/foundation.dart';
import '../widgets/voyager_widgets.dart';

/// Comparaison côte à côte de 2 ou 3 trajets (`?ids=t1,t2,t3`).
class ComparePage extends ConsumerWidget {
  const ComparePage({super.key});

  static const double _labelWidth = 80;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ids = (GoRouterState.of(context).uri.queryParameters['ids'] ?? '')
        .split(',')
        .where((s) => s.isNotEmpty);
    final store = ref.read(mockStoreProvider);
    final trips = [
      for (final id in ids) store.findTrip(id),
    ].whereType<Trip>().toList();

    if (trips.isEmpty) {
      return Scaffold(
        appBar: const TopBar(
          title: 'Comparaison',
          showBack: true,
          showBell: false,
        ),
        body: MoncarEmptyState(
          title: 'Aucun trajet à comparer',
          actionLabel: 'Retour',
          onAction: () => context.mcBack(),
        ),
      );
    }

    final cheapest = trips
        .map((t) => t.priceXOF)
        .reduce((a, b) => a < b ? a : b);
    final fastest = trips
        .map((t) => t.durationMin)
        .reduce((a, b) => a < b ? a : b);
    final bestRated = trips
        .map((t) => t.rating)
        .reduce((a, b) => a > b ? a : b);

    final valueStyle = TextStyle(fontSize: 12, color: MoncarColors.ink);
    final timeStyle = TextStyle(
      fontSize: 15,
      fontWeight: FontWeight.w700,
      color: MoncarColors.ink,
    );

    final rows =
        <
          ({
            String label,
            Widget Function(Trip) render,
            bool Function(Trip)? highlight,
          })
        >[
          (
            label: 'Compagnie',
            render: (t) => Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                CompanyLogo(
                  name: t.companyName,
                  color: t.companyColor,
                  size: 24,
                  radius: 4,
                ),
                const SizedBox(width: 6),
                Text(
                  t.companyName,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: MoncarColors.ink,
                  ),
                ),
              ],
            ),
            highlight: null,
          ),
          (
            label: 'Départ',
            render: (t) => Text(t.departureTime, style: timeStyle),
            highlight: null,
          ),
          (
            label: 'Arrivée',
            render: (t) => Text(t.arrivalTime, style: timeStyle),
            highlight: null,
          ),
          (
            label: 'Durée',
            render: (t) =>
                Text(formatDuration(t.durationMin), style: valueStyle),
            highlight: (t) => t.durationMin == fastest,
          ),
          (
            label: 'Prix',
            render: (t) => Text(
              formatXOF(t.priceXOF),
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: MoncarColors.accent,
              ),
            ),
            highlight: (t) => t.priceXOF == cheapest,
          ),
          (
            label: 'Places',
            render: (t) => Text('${t.seatsAvailable} dispo', style: valueStyle),
            highlight: null,
          ),
          (
            label: 'Note',
            render: (t) => MoncarRating(value: t.rating, count: t.reviewCount),
            highlight: (t) => t.rating == bestRated,
          ),
          (
            label: 'Type',
            render: (t) => MoncarBadge(
              label: vehicleTypeLabel(t.vehicleType),
              tone: MoncarBadgeTone.neutral,
              size: MoncarBadgeSize.sm,
            ),
            highlight: null,
          ),
          (
            label: 'Confort',
            render: (t) => Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                for (final a in t.amenities.take(3))
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 1),
                    child: Icon(
                      amenityIcon(a),
                      size: 12,
                      color: MoncarColors.inkMut,
                    ),
                  ),
              ],
            ),
            highlight: null,
          ),
          (
            label: 'Annulation',
            render: (t) => Text(
              cancellationLabel(t.cancellationPolicy),
              style: TextStyle(fontSize: 11, color: MoncarColors.inkMut),
            ),
            highlight: null,
          ),
          (
            label: 'Direct',
            render: (t) => t.direct
                ? Icon(Icons.check, size: 16, color: MoncarColors.success)
                : Icon(Icons.close, size: 16, color: MoncarColors.inkFaint),
            highlight: null,
          ),
        ];

    Widget grid(Widget Function(Trip) cell, {Widget? leading}) => Row(
      children: [
        SizedBox(width: _labelWidth, child: leading),
        for (final t in trips) ...[
          const SizedBox(width: 8),
          Expanded(child: cell(t)),
        ],
      ],
    );

    return Scaffold(
      backgroundColor: MoncarColors.background,
      appBar: TopBar(
        title: 'Comparer',
        subtitle: '${trips.length} trajets',
        showBack: true,
        showBell: false,
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(12, 12, 12, 24),
        children: [
          grid(
            (t) => Column(
              children: [
                CompanyLogo(
                  name: t.companyName,
                  color: t.companyColor,
                  size: 48,
                  radius: 12,
                ),
                const SizedBox(height: 4),
                Text(
                  t.companyName,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    color: MoncarColors.ink,
                  ),
                ),
                Text(
                  '${t.originCityName.substring(0, 3)}→${t.destinationCityName.substring(0, 3)}',
                  style: TextStyle(fontSize: 9, color: MoncarColors.inkFaint),
                ),
                const SizedBox(height: 8),
              ],
            ),
          ),
          Container(
            clipBehavior: Clip.antiAlias,
            decoration: BoxDecoration(
              color: MoncarColors.surface,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: MoncarColors.hairline),
            ),
            child: Column(
              children: [
                for (var i = 0; i < rows.length; i++) ...[
                  if (i > 0) Divider(height: 1, color: MoncarColors.hairline),
                  IntrinsicHeight(
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Container(
                          width: _labelWidth,
                          padding: const EdgeInsets.all(10),
                          alignment: Alignment.centerLeft,
                          decoration: BoxDecoration(
                            color: MoncarColors.brandSoft.withValues(
                              alpha: 0.3,
                            ),
                            border: Border(
                              right: BorderSide(color: MoncarColors.hairline),
                            ),
                          ),
                          child: Text(
                            rows[i].label.toUpperCase(),
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                              color: MoncarColors.inkMut,
                            ),
                          ),
                        ),
                        for (final t in trips)
                          Expanded(
                            child: Container(
                              constraints: const BoxConstraints(minHeight: 44),
                              padding: const EdgeInsets.all(8),
                              alignment: Alignment.center,
                              color: rows[i].highlight?.call(t) ?? false
                                  ? MoncarColors.successSoft.withValues(
                                      alpha: 0.4,
                                    )
                                  : null,
                              child: FittedBox(
                                fit: BoxFit.scaleDown,
                                child: rows[i].render(t),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 16),
          grid(
            (t) => MoncarButton(
              label: 'Choisir',
              variant: MoncarButtonVariant.primary,
              size: MoncarButtonSize.sm,
              expand: true,
              onPressed: () => context.push(
                '/voyager/trip/${t.id}'
                '${GoRouterState.of(context).uri.queryParameters['leg'] == 'retour' ? '?leg=retour' : ''}',
              ),
            ),
          ),
          const SizedBox(height: 16),
          Wrap(
            alignment: WrapAlignment.center,
            spacing: 8,
            runSpacing: 8,
            children: [
              MoncarBadge(
                label: 'Moins cher: ${formatXOF(cheapest)}',
                tone: MoncarBadgeTone.success,
                icon: Icons.check,
              ),
              MoncarBadge(
                label: 'Plus rapide: ${formatDuration(fastest)}',
                tone: MoncarBadgeTone.brand,
                icon: Icons.schedule,
              ),
              MoncarBadge(
                label: 'Mieux noté: ${bestRated.toStringAsFixed(1)}',
                tone: MoncarBadgeTone.accent,
                icon: Icons.star_border,
              ),
            ],
          ),
        ],
      ),
    );
  }
}
