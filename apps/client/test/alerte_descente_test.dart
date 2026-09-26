import 'package:flutter_test/flutter_test.dart';
import 'package:moncar_client/features/shared/domain/models.dart';
import 'package:moncar_client/features/tracking/application/alerte_descente.dart';

Stop _arret(String id, int ordre, double lat) => Stop(
  id: id,
  cityId: 'c-$id',
  cityName: id,
  label: 'Arrêt $id',
  latitude: lat,
  longitude: -4.0,
  orderInLine: ordre,
  minutesFromOrigin: ordre * 60,
);

BusPosition _bus({
  required double lat,
  required int indexCourant,
  String? prochainId,
  int eta = 30,
  TrackingState etat = TrackingState.disponible,
}) => BusPosition(
  tripId: 't1',
  latitude: lat,
  longitude: -4.0,
  heading: 0,
  speedKmh: 75,
  lastUpdate: '2026-09-26T08:00:00Z',
  state: etat,
  currentStopIndex: indexCourant,
  etaToNextStopMin: eta,
  progressPct: 50,
  stops: const [],
  nextStopId: prochainId,
);

void main() {
  // Arrêts espacés d'environ 55 km (0,5° de latitude).
  final arrets = [
    _arret('a', 0, 5.0),
    _arret('b', 1, 5.5),
    _arret('c', 2, 6.0),
  ];

  test('reste « en route » tant que le car est loin de l’arrêt', () {
    final bus = _bus(lat: 5.6, indexCourant: 1, prochainId: 'c');
    expect(
      etapeDescente(bus: bus, arrets: arrets, indexArret: 2),
      EtapeDescente.enRoute,
    );
  });

  test('passe à « proche » à moins d’1 km de l’arrêt', () {
    final bus = _bus(lat: 5.995, indexCourant: 1, prochainId: 'c');
    expect(
      etapeDescente(bus: bus, arrets: arrets, indexArret: 2),
      EtapeDescente.proche,
    );
  });

  test('passe à « proche » à 2 minutes, même sans position fine', () {
    final bus = _bus(lat: 5.9, indexCourant: 1, prochainId: 'c', eta: 2);
    expect(
      etapeDescente(bus: bus, arrets: arrets, indexArret: 2),
      EtapeDescente.proche,
    );
  });

  test('ne déclenche pas si l’arrêt suivant n’est pas celui du passager', () {
    final bus = _bus(lat: 5.499, indexCourant: 0, prochainId: 'b');
    expect(
      etapeDescente(bus: bus, arrets: arrets, indexArret: 2),
      EtapeDescente.enRoute,
    );
  });

  test('« arrivé » dès que l’arrêt est atteint', () {
    final bus = _bus(lat: 6.0, indexCourant: 2);
    expect(
      etapeDescente(bus: bus, arrets: arrets, indexArret: 2),
      EtapeDescente.arrive,
    );
  });

  test('messages identiques au cahier des charges', () {
    expect(messageProche, 'Votre arrêt approche. Préparez-vous à descendre.');
    expect(
      messageArrivee,
      'Vous êtes arrivé à votre arrêt. Veuillez préparer votre descente.',
    );
  });
}
