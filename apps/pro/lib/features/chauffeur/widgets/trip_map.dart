import 'package:core_ui/core_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../../../core/application/gps_controller.dart';
import '../../../core/application/trip_controller.dart';
import '../../../core/domain/models.dart';

/// Carte du voyage : tracé de la ligne, gares, position du car.
/// Fond OpenStreetMap (MapLibre/MapTiler prévus en production, ⚠ T-5).
class TripMap extends StatefulWidget {
  const TripMap({
    super.key,
    required this.trip,
    required this.gps,
    required this.accent,
    this.focusSegment = false,
    this.follow = false,
  });

  final TripState trip;
  final GpsState gps;
  final Color accent;

  /// Cadre initial sur le tronçon en cours plutôt que toute la ligne.
  final bool focusSegment;

  /// Recentre la carte sur le car à chaque nouvelle position.
  final bool follow;

  @override
  State<TripMap> createState() => TripMapState();
}

class TripMapState extends State<TripMap> {
  final _map = MapController();
  bool _ready = false;

  List<LatLng> get _route => [
    for (final s in widget.trip.voyage.stops) LatLng(s.lat, s.lng),
  ];

  CameraFit _fit() {
    final v = widget.trip.voyage;
    final pts = widget.focusSegment && v.nextStop != null
        ? [
            LatLng(v.currentStop.lat, v.currentStop.lng),
            LatLng(v.nextStop!.lat, v.nextStop!.lng),
            LatLng(widget.gps.lat, widget.gps.lng),
          ]
        : _route;
    return CameraFit.bounds(
      bounds: LatLngBounds.fromPoints(pts),
      padding: const EdgeInsets.fromLTRB(40, 60, 40, 40),
      maxZoom: 13,
    );
  }

  /// Recadre sur le tronçon / la ligne.
  void recenter() {
    if (_ready) _map.fitCamera(_fit());
  }

  @override
  void didUpdateWidget(TripMap oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.follow &&
        _ready &&
        (oldWidget.gps.lat != widget.gps.lat ||
            oldWidget.gps.lng != widget.gps.lng)) {
      _map.move(LatLng(widget.gps.lat, widget.gps.lng), _map.camera.zoom);
    }
  }

  @override
  Widget build(BuildContext context) {
    final v = widget.trip.voyage;
    final done = [
      for (final s in v.stops.where((s) => s.order <= v.currentStopIndex))
        LatLng(s.lat, s.lng),
      if (widget.trip.phase == DriverPhase.enRoute)
        LatLng(widget.gps.lat, widget.gps.lng),
    ];
    final dark = MoncarColors.isDark;
    return FlutterMap(
      mapController: _map,
      options: MapOptions(
        initialCameraFit: _fit(),
        onMapReady: () => _ready = true,
        backgroundColor: dark
            ? const Color(0xFF1B2233)
            : const Color(0xFFE8ECF2),
      ),
      children: [
        TileLayer(
          urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
          userAgentPackageName: 'com.moncar.pro',
          tileBuilder: dark ? _darkTiles : null,
        ),
        PolylineLayer(
          polylines: [
            Polyline(
              points: _route,
              strokeWidth: 6,
              color: widget.accent.withValues(alpha: 0.35),
              borderStrokeWidth: 2,
              borderColor: Colors.white.withValues(alpha: 0.8),
            ),
            if (done.length > 1)
              Polyline(points: done, strokeWidth: 6, color: widget.accent),
          ],
        ),
        MarkerLayer(
          markers: [
            for (final s in v.stops)
              Marker(
                point: LatLng(s.lat, s.lng),
                width: 120,
                height: 46,
                alignment: Alignment.topCenter,
                child: _StopMarker(
                  stop: s,
                  passed: s.order <= v.currentStopIndex,
                  highlight: s.id == v.nextStop?.id || s.id == v.destination.id,
                  accent: widget.accent,
                ),
              ),
            Marker(
              point: LatLng(widget.gps.lat, widget.gps.lng),
              width: 52,
              height: 52,
              child: _VehicleMarker(color: widget.accent),
            ),
          ],
        ),
        const Align(
          alignment: Alignment.bottomRight,
          child: Padding(
            padding: EdgeInsets.all(4),
            child: Text(
              '© OpenStreetMap',
              style: TextStyle(fontSize: 9, color: Colors.black54),
            ),
          ),
        ),
      ],
    );
  }

  static Widget _darkTiles(
    BuildContext context,
    Widget tile,
    TileImage image,
  ) => ColorFiltered(
    colorFilter: const ColorFilter.matrix([
      -0.9, 0, 0, 0, 230, //
      0, -0.9, 0, 0, 235,
      0, 0, -0.9, 0, 245,
      0, 0, 0, 1, 0,
    ]),
    child: tile,
  );
}

class _StopMarker extends StatelessWidget {
  const _StopMarker({
    required this.stop,
    required this.passed,
    required this.highlight,
    required this.accent,
  });

  final Stop stop;
  final bool passed;
  final bool highlight;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    final c = passed
        ? MoncarColors.success
        : (highlight ? accent : const Color(0xFF64748B));
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(6),
            boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 4)],
          ),
          child: Text(
            stop.shortName,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 10.5,
              fontWeight: highlight ? FontWeight.w900 : FontWeight.w700,
              color: const Color(0xFF16213E),
            ),
          ),
        ),
        const SizedBox(height: 2),
        Container(
          width: 16,
          height: 16,
          decoration: BoxDecoration(
            color: c,
            shape: BoxShape.circle,
            border: Border.all(color: Colors.white, width: 3),
            boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 4)],
          ),
        ),
      ],
    );
  }
}

class _VehicleMarker extends StatelessWidget {
  const _VehicleMarker({required this.color});

  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: color.withValues(alpha: 0.18),
      ),
      alignment: Alignment.center,
      child: Container(
        width: 34,
        height: 34,
        decoration: BoxDecoration(
          color: color,
          shape: BoxShape.circle,
          border: Border.all(color: Colors.white, width: 3),
          boxShadow: const [BoxShadow(color: Colors.black38, blurRadius: 8)],
        ),
        child: const Icon(
          Icons.directions_bus_rounded,
          color: Colors.white,
          size: 18,
        ),
      ),
    );
  }
}
