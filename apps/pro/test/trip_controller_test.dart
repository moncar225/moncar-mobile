import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:moncar_pro/core/application/app_providers.dart';
import 'package:moncar_pro/core/application/sync_controller.dart';
import 'package:moncar_pro/core/application/trip_controller.dart';
import 'package:moncar_pro/core/data/pro_api.dart';
import 'package:moncar_pro/core/domain/models.dart';

ProviderContainer _container() {
  final c = ProviderContainer(
    overrides: [
      proApiProvider.overrideWithValue(MockProApi(latency: Duration.zero)),
    ],
  );
  addTearDown(c.dispose);
  return c;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Vérification locale des billets (hors ligne)', () {
    test('couvre les 6 résultats du cahier des charges', () {
      final c = _container();
      c.read(networkProvider.notifier).setForcedOffline(true);
      final trip = c.read(tripProvider.notifier);

      expect(trip.verify('MCP:BIL-0427-014').outcome, ScanOutcome.valide);
      expect(trip.verify('BIL-0427-002').outcome, ScanOutcome.dejaScanne);
      expect(trip.verify('BIL-0427-018').outcome, ScanOutcome.annule);
      expect(trip.verify('BIL-0430-118').outcome, ScanOutcome.mauvaisVoyage);
      // Passager qui monte à Anyama, scanné à Abidjan.
      expect(trip.verify('BIL-0427-021').outcome, ScanOutcome.mauvaiseGare);
      expect(trip.verify('XYZ').outcome, ScanOutcome.invalide);
    });

    test('un billet validé puis rescanné est « déjà contrôlé »', () {
      final c = _container();
      c.read(networkProvider.notifier).setForcedOffline(true);
      final trip = c.read(tripProvider.notifier);

      final r = trip.verify('BIL-0427-014');
      trip.confirmBoarding(r.passenger!.id);
      final again = trip.verify('BIL-0427-014');

      expect(again.outcome, ScanOutcome.dejaScanne);
      expect(again.previousAt, isNotNull);
    });
  });

  group('File de synchronisation', () {
    test(
      'les actions hors ligne restent en attente puis partent sans doublon',
      () async {
        final c = _container();
        c.read(networkProvider.notifier).setForcedOffline(true);
        final trip = c.read(tripProvider.notifier);
        final p = c
            .read(tripProvider)
            .passengers
            .firstWhere((x) => !x.isOnBoard);

        trip.confirmPresence(p.id);
        trip.confirmPresence(p.id); // double appui : ignoré
        expect(
          c.read(syncProvider).ops.where((o) => o.kind == 'PRESENCE').length,
          1,
        );
        expect(c.read(syncProvider).pendingCount, greaterThan(0));

        c.read(networkProvider.notifier).setForcedOffline(false);
        await c.read(syncProvider.notifier).flush();
        // Les échecs réseau simulés restent en file : on rejoue.
        for (var i = 0; i < 5 && c.read(syncProvider).pendingCount > 0; i++) {
          await c.read(syncProvider.notifier).flush();
        }
        expect(c.read(syncProvider).pendingCount, 0);
      },
    );
  });

  group('Workflow chauffeur', () {
    test('départ → arrêts → destination → clôture', () {
      final c = _container();
      final trip = c.read(tripProvider.notifier);
      expect(c.read(tripProvider).phase, DriverPhase.avantDepart);

      trip.startTrip();
      expect(c.read(tripProvider).voyage.status, VoyageStatus.enCours);

      while (c.read(tripProvider).phase != DriverPhase.arriveDestination) {
        trip.arriveAtStop();
        if (c.read(tripProvider).phase == DriverPhase.aLArret) {
          trip.departFromStop();
        }
      }
      expect(c.read(tripProvider).voyage.status, VoyageStatus.arrive);

      trip.closeTrip(km: 142780, withIncident: false);
      expect(c.read(tripProvider).phase, DriverPhase.cloture);
      expect(c.read(tripProvider).voyage.status, VoyageStatus.cloture);
    });

    test('le débarquement libère le passager du manifeste à bord', () {
      final c = _container();
      final trip = c.read(tripProvider.notifier);
      final p = c.read(tripProvider).passengers.firstWhere((x) => x.isOnBoard);
      final before = c.read(tripProvider).onBoard;

      trip.confirmDisembark(p.id);

      expect(c.read(tripProvider).onBoard, before - 1);
    });
  });
}
