import 'package:flutter_test/flutter_test.dart';
import 'package:moncar_pro/core/application/gps_controller.dart';
import 'package:moncar_pro/core/application/gps_policy.dart';
import 'package:moncar_pro/core/domain/models.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  group('Politique GPS adaptative (T-5)', () {
    const politique = PolitiqueGps.defaut;

    test('rapprochée à l’approche d’un arrêt, espacée sur la route', () {
      expect(
        politique.modePour(distanceProchainArretKm: 1.5, vitesseKmh: 80),
        ModeGps.rapproche,
      );
      expect(
        politique.modePour(distanceProchainArretKm: 40, vitesseKmh: 85),
        ModeGps.route,
      );
    });

    test('rapprochée en circulation urbaine lente', () {
      expect(
        politique.modePour(distanceProchainArretKm: 25, vitesseKmh: 20),
        ModeGps.rapproche,
      );
    });

    test('intervalles et distances plus serrés en mode rapproché', () {
      expect(
        politique.intervalle(ModeGps.rapproche) <
            politique.intervalle(ModeGps.route),
        isTrue,
      );
      expect(
        politique.distanceMin(ModeGps.rapproche) <
            politique.distanceMin(ModeGps.route),
        isTrue,
      );
    });

    test('le GPS ne tourne que pendant le voyage actif', () {
      expect(voyageActif(DriverPhase.enRoute), isTrue);
      expect(voyageActif(DriverPhase.aLArret), isTrue);
      expect(voyageActif(DriverPhase.avantDepart), isFalse);
      expect(voyageActif(DriverPhase.cloture), isFalse);
    });
  });

  group('Tampon local des positions', () {
    PointGps point(int i) => PointGps(
      lat: 5 + i / 100,
      lng: -4,
      horodatage: DateTime(2026, 9, 26, 8, i),
    );

    test('survit à un redémarrage et se vide par lots complets', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final tampon = TamponPositions(prefs);
      for (var i = 0; i < 12; i++) {
        tampon.ajouter(point(i));
      }
      // « Redémarrage » : nouvelle instance sur les mêmes préférences.
      final apres = TamponPositions(prefs);
      expect(apres.lire(), hasLength(12));
      final lot = apres.extraireLot(10);
      expect(lot, hasLength(10));
      expect(lot!.first.horodatage, DateTime(2026, 9, 26, 8, 0));
      expect(apres.lire(), hasLength(2));
      expect(apres.extraireLot(10), isNull);
    });
  });
}
