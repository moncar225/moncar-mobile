import 'package:flutter/material.dart';

import 'package:core_ui/core_ui.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../domain/models.dart';

/// Carte de suivi temps réel (portage du `LiveMap` web, Leaflet → flutter_map).
///
/// Tuiles Esri World Street Map (gratuites, sans clé, rendu premium
/// compatible navy/orange), arrêts, polyligne orange (parcouru) +
/// grise pointillée (restant), marqueur bus orange pulsant.
class LiveMap extends StatefulWidget {
  const LiveMap({
    super.key,
    required this.stops,
    required this.busPosition,
    required this.progressPct,
    required this.state,
    required this.currentStopIndex,
    this.height = 280,
    this.onRetry,
  });

  final List<Stop> stops;
  final BusPosition? busPosition;
  final int progressPct;
  final TrackingState state;
  final int currentStopIndex;
  final double height;
  final VoidCallback? onRetry;

  @override
  State<LiveMap> createState() => _LiveMapState();
}

class _LiveMapState extends State<LiveMap> with SingleTickerProviderStateMixin {
  late final AnimationController _pulse = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1800),
  )..repeat(reverse: true);

  static const _tileUrl =
      'https://server.arcgisonline.com/ArcGIS/rest/services/World_Street_Map/MapServer/tile/{z}/{y}/{x}';
  static const _tileAttribution = 'Tiles © Esri';

  static const _colorTraveled = Color(0xFFFF6600);
  static const _colorRemaining = Color(0xFF5B6B8C);

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  List<LatLng> get _stopPoints =>
      widget.stops.map((s) => LatLng(s.latitude, s.longitude)).toList();

  @override
  Widget build(BuildContext context) {
    final stops = widget.stops;
    final bus = widget.busPosition;
    final busPoint = bus != null ? LatLng(bus.latitude, bus.longitude) : null;

    final traveled = <LatLng>[
      for (var i = 0; i <= widget.currentStopIndex && i < stops.length; i++)
        _stopPoints[i],
      if (busPoint != null &&
          _stopPoints.isNotEmpty &&
          busPoint !=
              _stopPoints[widget.currentStopIndex.clamp(
                0,
                _stopPoints.length - 1,
              )])
        busPoint,
    ];
    final remaining = <LatLng>[
      if (busPoint != null && widget.currentStopIndex < stops.length - 1)
        busPoint,
      for (var i = widget.currentStopIndex + 1; i < stops.length; i++)
        _stopPoints[i],
    ];

    return SizedBox(
      height: widget.height,
      child: Stack(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(20),
            child: FlutterMap(
              options: MapOptions(
                initialCameraFit: CameraFit.coordinates(
                  coordinates: _stopPoints,
                  padding: const EdgeInsets.all(40),
                ),
                interactionOptions: const InteractionOptions(
                  flags: InteractiveFlag.drag | InteractiveFlag.pinchZoom,
                ),
              ),
              children: [
                TileLayer(
                  urlTemplate: _tileUrl,
                  userAgentPackageName: 'ci.moncar.app',
                ),
                if (remaining.length >= 2)
                  PolylineLayer(
                    polylines: [
                      Polyline(
                        points: remaining,
                        color: _colorRemaining,
                        strokeWidth: 4,
                        pattern: StrokePattern.dashed(segments: const [8, 6]),
                      ),
                    ],
                  ),
                if (traveled.length >= 2)
                  PolylineLayer(
                    polylines: [
                      Polyline(
                        points: traveled,
                        color: _colorTraveled,
                        strokeWidth: 5,
                      ),
                    ],
                  ),
                MarkerLayer(
                  markers: [
                    for (var i = 0; i < stops.length; i++)
                      Marker(
                        point: _stopPoints[i],
                        width: i == widget.currentStopIndex ? 36 : 24,
                        height: i == widget.currentStopIndex ? 36 : 24,
                        child: _StopDot(
                          isCurrent: i == widget.currentStopIndex,
                          isPast: i < widget.currentStopIndex,
                        ),
                      ),
                    if (busPoint != null)
                      Marker(
                        point: busPoint,
                        width: 44,
                        height: 44,
                        child: _BusMarker(pulse: _pulse),
                      ),
                  ],
                ),
                const SimpleAttributionWidget(
                  source: Text(_tileAttribution, style: TextStyle(fontSize: 9)),
                ),
              ],
            ),
          ),
          if (widget.state == TrackingState.horsLigne)
            Positioned.fill(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(20),
                child: Container(
                  color: const Color(0xFF002060).withValues(alpha: 0.88),
                  child: Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.wifi_off,
                          size: 36,
                          color: Colors.white,
                        ),
                        const SizedBox(height: 12),
                        const Text(
                          'Signal GPS indisponible',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(height: 4),
                        ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 260),
                          child: Text(
                            "Le bus n'envoie pas de position. Rafraîchissement automatique en cours.",
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.white.withValues(alpha: 0.8),
                            ),
                          ),
                        ),
                        if (widget.onRetry != null) ...[
                          const SizedBox(height: 16),
                          FilledButton.tonal(
                            style: FilledButton.styleFrom(
                              backgroundColor: MoncarColors.surface,
                              foregroundColor: MoncarColors.brand,
                            ),
                            onPressed: widget.onRetry,
                            child: const Text(
                              'Réessayer',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _StopDot extends StatelessWidget {
  const _StopDot({required this.isCurrent, required this.isPast});

  final bool isCurrent;
  final bool isPast;

  @override
  Widget build(BuildContext context) {
    final color = isCurrent
        ? const Color(0xFFFF6600)
        : isPast
        ? const Color(0xFF1FA25C)
        : Colors.white;
    return Center(
      child: Container(
        width: isCurrent ? 16 : 11,
        height: isCurrent ? 16 : 11,
        decoration: BoxDecoration(
          color: color,
          shape: BoxShape.circle,
          border: Border.all(color: const Color(0xFF002060), width: 2),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.2),
              blurRadius: 4,
            ),
          ],
        ),
      ),
    );
  }
}

class _BusMarker extends StatelessWidget {
  const _BusMarker({required this.pulse});

  final AnimationController pulse;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: pulse,
      builder: (context, _) {
        final t = Curves.easeOut.transform(pulse.value);
        return Stack(
          alignment: Alignment.center,
          children: [
            Container(
              width: 24 + 20 * t,
              height: 24 + 20 * t,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: const Color(
                  0xFFFF6600,
                ).withValues(alpha: 0.35 * (1 - t)),
              ),
            ),
            Container(
              width: 28,
              height: 28,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: const Color(0xFFFF6600),
                border: Border.all(color: Colors.white, width: 2.5),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF002060).withValues(alpha: 0.35),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: const Icon(
                Icons.directions_bus,
                size: 16,
                color: Colors.white,
              ),
            ),
          ],
        );
      },
    );
  }
}
