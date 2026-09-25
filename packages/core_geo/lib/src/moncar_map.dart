import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

/// Carte MON CAR réutilisable (basée sur flutter_map).
///
/// Wrapper volontairement mince : le suivi temps réel, les marqueurs de gares
/// et le tracé d'itinéraire seront construits dans les features au-dessus de
/// ce widget, lorsque les endpoints correspondants seront disponibles.
class MoncarMap extends StatelessWidget {
  const MoncarMap({
    super.key,
    required this.center,
    this.zoom = 13,
    this.markers = const [],
    this.interactive = true,
  });

  final LatLng center;
  final double zoom;
  final List<Marker> markers;

  /// Désactive les gestes (aperçu figé dans une carte de détails par ex.).
  final bool interactive;

  @override
  Widget build(BuildContext context) {
    return FlutterMap(
      options: MapOptions(
        initialCenter: center,
        initialZoom: zoom,
        interactionOptions: InteractionOptions(
          flags: interactive ? InteractiveFlag.all : InteractiveFlag.none,
        ),
      ),
      children: [
        TileLayer(
          urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
          userAgentPackageName: 'com.moncar.app',
        ),
        if (markers.isNotEmpty) MarkerLayer(markers: markers),
      ],
    );
  }
}
