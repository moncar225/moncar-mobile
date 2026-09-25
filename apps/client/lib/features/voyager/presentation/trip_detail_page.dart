import 'package:flutter/material.dart';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../shared/foundation.dart';
import '../widgets/voyager_widgets.dart';

/// Détail d'un trajet : itinéraire, choix des arrêts de montée et de
/// descente, véhicule, conditions puis accès au plan de sièges.
class TripDetailPage extends ConsumerStatefulWidget {
  const TripDetailPage({super.key, required this.tripId});

  final String tripId;

  @override
  ConsumerState<TripDetailPage> createState() => _TripDetailPageState();
}

class _TripDetailPageState extends ConsumerState<TripDetailPage> {
  String? _boarding;
  String? _alighting;

  bool get _isReturn =>
      GoRouterState.of(context).uri.queryParameters['leg'] == 'retour';

  void _chooseSeats(Trip trip) {
    final boarding = _boarding ?? trip.stops.first.id;
    final alighting = _alighting ?? trip.stops.last.id;
    final isReturn = _isReturn;
    ref
        .read(bookingDraftProvider.notifier)
        .update(
          (d) => BookingDraft(
            trip: trip,
            boardingStopId: boarding,
            alightingStopId: alighting,
            selectedSeats: const [],
            passengerCount: d.passengerCount,
            tripType: d.tripType,
            returnDate: d.returnDate,
            // Choix de l'aller : on repart d'un aller-retour vierge.
            outboundLeg: isReturn ? d.outboundLeg : null,
          ),
        );
    context.push(
      '/voyager/seats/${trip.id}?boarding=$boarding&alighting=$alighting'
      '${isReturn ? '&leg=retour' : ''}',
    );
  }

  @override
  Widget build(BuildContext context) {
    final trip = ref.read(mockStoreProvider).findTrip(widget.tripId);
    if (trip == null) {
      return Scaffold(
        appBar: const TopBar(title: 'Détail du voyage', showBack: true),
        body: MoncarErrorState(
          message: 'Trajet introuvable',
          onRetry: () => setState(() {}),
        ),
      );
    }
    final boardingId = _boarding ?? trip.stops.first.id;
    final alightingId = _alighting ?? trip.stops.last.id;
    final boardStop = trip.stops.where((s) => s.id == boardingId).firstOrNull;
    final alightStop = trip.stops.where((s) => s.id == alightingId).firstOrNull;

    return Scaffold(
      backgroundColor: MoncarColors.background,
      appBar: const TopBar(
        title: 'Détail du voyage',
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
          MoncarCard(
            padding: EdgeInsets.zero,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _RouteHero(trip: trip),
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(
                        children: [
                          CompanyLogo(
                            name: trip.companyName,
                            color: trip.companyColor,
                            size: 40,
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  trip.companyName,
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                    color: MoncarColors.ink,
                                  ),
                                ),
                                MoncarRating(
                                  value: trip.rating,
                                  count: trip.reviewCount,
                                ),
                              ],
                            ),
                          ),
                          for (final t in trip.tags)
                            Padding(
                              padding: const EdgeInsets.only(left: 4),
                              child: MoncarBadge(
                                label: t,
                                tone: t == 'Promo'
                                    ? MoncarBadgeTone.accent
                                    : MoncarBadgeTone.brand,
                                size: MoncarBadgeSize.sm,
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: _TimeBox(
                              label: 'Départ',
                              time: trip.departureTime,
                              place: boardStop?.label ?? trip.originCityName,
                              color: MoncarColors.brandSoft,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _TimeBox(
                              label: 'Arrivée',
                              time: trip.arrivalTime,
                              place:
                                  alightStop?.label ?? trip.destinationCityName,
                              color: MoncarColors.accentSoft,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Icon(
                            Icons.schedule,
                            size: 12,
                            color: MoncarColors.inkMut,
                          ),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              '${formatDateFull(trip.date)} · ${formatDuration(trip.durationMin)}',
                              style: TextStyle(
                                fontSize: 11,
                                color: MoncarColors.inkMut,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          const SectionTitle('Vos arrêts'),
          MoncarCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _StopSelect(
                  label: 'Arrêt de montée',
                  value: boardingId,
                  stops: trip.stops.sublist(0, trip.stops.length - 1),
                  onChanged: (v) => setState(() => _boarding = v),
                ),
                const SizedBox(height: 12),
                _StopSelect(
                  label: 'Arrêt de descente',
                  value: alightingId,
                  stops: trip.stops.sublist(1),
                  onChanged: (v) => setState(() => _alighting = v),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          const SectionTitle('Itinéraire détaillé'),
          MoncarCard(
            child: Column(
              children: [
                for (var i = 0; i < trip.stops.length; i++)
                  _StopTimelineRow(
                    stop: trip.stops[i],
                    isLast: i == trip.stops.length - 1,
                    isBoard: trip.stops[i].id == boardingId,
                    isAlight: trip.stops[i].id == alightingId,
                  ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          const SectionTitle('Véhicule & confort'),
          MoncarCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Container(
                      width: 48,
                      height: 48,
                      decoration: brandGradientDecoration(
                        radius: BorderRadius.circular(12),
                      ),
                      child: const Icon(
                        Icons.directions_bus,
                        size: 24,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            trip.vehicleModel,
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: MoncarColors.ink,
                            ),
                          ),
                          Text(
                            '${trip.totalSeats} places · ${vehicleTypeLabel(trip.vehicleType)}',
                            style: TextStyle(
                              fontSize: 11,
                              color: MoncarColors.inkMut,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                GridView.count(
                  crossAxisCount: 4,
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  mainAxisSpacing: 8,
                  crossAxisSpacing: 8,
                  childAspectRatio: 1,
                  children: [
                    for (final a in trip.amenities)
                      Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: MoncarColors.brandSoft.withValues(alpha: 0.4),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              amenityIcon(a),
                              size: 16,
                              color: MoncarColors.brand,
                            ),
                            const SizedBox(height: 4),
                            Text(
                              a,
                              textAlign: TextAlign.center,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 9,
                                height: 1.2,
                                color: MoncarColors.inkMut,
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          const SectionTitle('Conditions'),
          MoncarCard(
            child: Column(
              children: [
                _Condition(
                  icon: Icons.shield_outlined,
                  title:
                      'Annulation ${cancellationLabel(trip.cancellationPolicy)}',
                  body: switch (trip.cancellationPolicy) {
                    CancellationPolicy.flexible =>
                      "Remboursement intégral jusqu'à 24h avant le départ.",
                    CancellationPolicy.modere =>
                      "Remboursement à 50% jusqu'à 12h avant le départ.",
                    CancellationPolicy.strict =>
                      'Aucun remboursement. Place réservée ferme.',
                  },
                ),
                const _Condition(
                  icon: Icons.group_outlined,
                  title: 'Bagages',
                  body:
                      '1 bagage main + 1 valise 20kg inclus. Excédent: 500 FCFA/kg.',
                ),
                const _Condition(
                  icon: Icons.info_outline,
                  title: 'Présentation',
                  body:
                      'Présentez-vous en gare 30 min avant le départ. Billet QR obligatoire.',
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          MoncarCard(
            color: MoncarColors.brandSoft.withValues(alpha: 0.4),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const OverlineText('Prix par passager'),
                        Text(
                          formatXOF(trip.priceXOF),
                          style: TextStyle(
                            fontSize: 24,
                            height: 1.1,
                            fontWeight: FontWeight.w800,
                            color: MoncarColors.accent,
                          ),
                        ),
                      ],
                    ),
                    const Spacer(),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        const OverlineText('Disponibilité'),
                        Text(
                          '${trip.seatsAvailable} places',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: MoncarColors.success,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                MoncarButton(
                  label: 'Choisir mon siège',
                  icon: Icons.arrow_forward,
                  variant: MoncarButtonVariant.primary,
                  size: MoncarButtonSize.xl,
                  expand: true,
                  onPressed: () => _chooseSeats(trip),
                ),
                const SizedBox(height: 8),
                Text(
                  'Vous serez redirigé vers le plan de sièges',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 10, color: MoncarColors.inkFaint),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _RouteHero extends StatelessWidget {
  const _RouteHero({required this.trip});

  final Trip trip;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 176,
      decoration: brandGradientDecoration(),
      child: Stack(
        children: [
          Positioned.fill(child: CustomPaint(painter: _RoutePainter())),
          Positioned(
            top: 12,
            left: 12,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                OverlineText(
                  'Itinéraire',
                  color: Colors.white.withValues(alpha: 0.7),
                ),
                Text(
                  '${trip.originCityName} → ${trip.destinationCityName}',
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
              ],
            ),
          ),
          Positioned(
            bottom: 12,
            right: 12,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  formatDistance(trip.distanceKm.toDouble()),
                  style: TextStyle(
                    fontSize: 10,
                    color: Colors.white.withValues(alpha: 0.7),
                  ),
                ),
                Text(
                  formatDuration(trip.durationMin),
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Itinéraire stylisé (courbe pointillée, origine, destination, bus).
class _RoutePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    double x(double v) => v / 400 * size.width;
    double y(double v) => v / 180 * size.height;

    final path = Path()
      ..moveTo(x(40), y(140))
      ..quadraticBezierTo(x(120), y(60), x(200), y(100))
      ..quadraticBezierTo(x(280), y(140), x(360), y(50));
    final dashPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.4)
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke;
    for (final metric in path.computeMetrics()) {
      var d = 0.0;
      while (d < metric.length) {
        canvas.drawPath(metric.extractPath(d, d + 6), dashPaint);
        d += 12;
      }
    }
    void dot(double cx, double cy, Color outer, Color inner) {
      canvas.drawCircle(Offset(x(cx), y(cy)), 8, Paint()..color = outer);
      canvas.drawCircle(Offset(x(cx), y(cy)), 4, Paint()..color = inner);
    }

    dot(40, 140, Colors.white, MoncarColors.brand);
    dot(360, 50, MoncarColors.accent, Colors.white);
    final bus = Offset(x(200), y(100));
    canvas.drawCircle(
      bus,
      12,
      Paint()..color = MoncarColors.accent.withValues(alpha: 0.3),
    );
    canvas.drawCircle(bus, 7, Paint()..color = MoncarColors.accent);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _TimeBox extends StatelessWidget {
  const _TimeBox({
    required this.label,
    required this.time,
    required this.place,
    required this.color,
  });

  final String label;
  final String time;
  final String place;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          OverlineText(label),
          Text(
            time,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: MoncarColors.ink,
            ),
          ),
          Text(
            place,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(fontSize: 11, color: MoncarColors.inkMut),
          ),
        ],
      ),
    );
  }
}

class _StopSelect extends StatelessWidget {
  const _StopSelect({
    required this.label,
    required this.value,
    required this.stops,
    required this.onChanged,
  });

  final String label;
  final String value;
  final List<Stop> stops;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    final selected = stops.any((s) => s.id == value) ? value : stops.first.id;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        OverlineText(label),
        const SizedBox(height: 6),
        DropdownButtonFormField<String>(
          initialValue: selected,
          isExpanded: true,
          onChanged: (v) {
            if (v != null) onChanged(v);
          },
          decoration: InputDecoration(
            isDense: true,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 12,
              vertical: 12,
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: MoncarColors.hairline),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: MoncarColors.hairline),
            ),
          ),
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: MoncarColors.ink,
          ),
          items: [
            for (final s in stops)
              DropdownMenuItem(
                value: s.id,
                child: Text(
                  '${s.label} — ${s.cityName}',
                  overflow: TextOverflow.ellipsis,
                ),
              ),
          ],
        ),
      ],
    );
  }
}

class _StopTimelineRow extends StatelessWidget {
  const _StopTimelineRow({
    required this.stop,
    required this.isLast,
    required this.isBoard,
    required this.isAlight,
  });

  final Stop stop;
  final bool isLast;
  final bool isBoard;
  final bool isAlight;

  @override
  Widget build(BuildContext context) {
    final color = isBoard
        ? MoncarColors.brand
        : isAlight
        ? MoncarColors.accent
        : null;
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Column(
            children: [
              Container(
                width: 16,
                height: 16,
                decoration: BoxDecoration(
                  color: color ?? Colors.white,
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: color ?? MoncarColors.hairline,
                    width: 2,
                  ),
                ),
                alignment: Alignment.center,
                child: color != null
                    ? Container(
                        width: 6,
                        height: 6,
                        decoration: BoxDecoration(
                          color: MoncarColors.surface,
                          shape: BoxShape.circle,
                        ),
                      )
                    : null,
              ),
              if (!isLast)
                Expanded(
                  child: Container(
                    width: 2,
                    constraints: const BoxConstraints(minHeight: 28),
                    color: MoncarColors.hairline,
                  ),
                ),
            ],
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    stop.label,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: MoncarColors.ink,
                    ),
                  ),
                  Text(
                    stop.cityName,
                    style: TextStyle(fontSize: 11, color: MoncarColors.inkMut),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    stop.minutesFromOrigin == 0
                        ? 'Origine'
                        : '+${formatDuration(stop.minutesFromOrigin)}',
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

class _Condition extends StatelessWidget {
  const _Condition({
    required this.icon,
    required this.title,
    required this.body,
  });

  final IconData icon;
  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 2),
            child: Icon(icon, size: 16, color: MoncarColors.brand),
          ),
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
                Text(
                  body,
                  style: TextStyle(fontSize: 11, color: MoncarColors.inkMut),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
