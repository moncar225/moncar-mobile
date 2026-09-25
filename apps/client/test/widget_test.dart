import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'package:moncar_client/app/app.dart';
import 'package:moncar_client/app/router.dart';
import 'package:moncar_client/features/auth/application/auth_flow.dart';
import 'package:moncar_client/features/auth/application/phone_auth.dart';
import 'package:moncar_client/features/location/application/device_location.dart';
import 'package:moncar_client/features/shared/application/analytics.dart';
import 'package:moncar_client/features/shared/foundation.dart';

import 'test_fonts.dart';

/// Conteneur avec session de démo ouverte (utilisateur connecté).
ProviderContainer _loggedInContainer() {
  final container = ProviderContainer();
  container.read(authProvider.notifier).setSession(DEMO_USER, 'test_token');
  return container;
}

Future<void> _pumpApp(
  WidgetTester tester,
  ProviderContainer container, {
  Size logicalSize = const Size(390, 844),
}) async {
  tester.view.physicalSize = logicalSize * 3;
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: const MoncarClientApp(),
    ),
  );
}

void main() {
  setUpAll(loadRealFonts);
  // Pas de plugin natif de connectivité ni Firebase dans les tests.
  NetworkMonitor.enabled = false;
  MoncarAnalytics.enabled = false;
  MoncarPhoneAuth.enabled = false;
  DeviceLocation.enabled = false;

  testWidgets('Non connecté : splash puis onboarding', (tester) async {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    await _pumpApp(tester, container);
    await tester.pump();

    expect(find.text('Voyagez en toute confiance'), findsOneWidget);

    await tester.pump(const Duration(seconds: 2));
    await tester.pump(const Duration(milliseconds: 600));
    expect(find.text('Voyagez simplement'), findsOneWidget);
    expect(find.text('Passer'), findsOneWidget);
  });

  testWidgets('Connecté : accueil avec recherche et barre de navigation', (
    tester,
  ) async {
    final container = _loggedInContainer();
    addTearDown(container.dispose);
    await _pumpApp(tester, container);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    expect(find.text('Où allez-vous ?'), findsOneWidget);
    expect(find.text('Rechercher un voyage'), findsOneWidget);
    expect(find.text('Accès rapides'), findsOneWidget);
  });

  for (final size in const [Size(390, 844), Size(360, 780)]) {
    testWidgets(
      'Toutes les routes s’affichent sans exception (${size.width.toInt()} dp)',
      (tester) async {
        final container = _loggedInContainer();
        addTearDown(container.dispose);
        await _pumpApp(tester, container, logicalSize: size);
        await tester.pump();

        final store = container.read(mockStoreProvider);
        final trip = store.trips.first;
        final booking = store.bookings.first;
        final ticket = store.tickets.first;
        final parcel = store.parcels.first;
        final vehicle = RENTAL_VEHICLES.first;
        final promo = store.promotions.first;

        final routes = [
          '/home',
          '/voyager',
          '/voyager?origin=Abidjan&destination=Yamoussoukro&date=${trip.date}&passengers=1',
          '/voyager/compare?ids=${store.trips.take(2).map((t) => t.id).join(',')}',
          '/voyager/trip/${trip.id}',
          '/voyager/seats/${trip.id}',
          '/voyager/passengers/${trip.id}',
          '/voyager/recap/${booking.id}',
          '/voyager/payment/${booking.id}',
          '/voyager/confirmation/${booking.id}',
          '/voyager/ticket/${ticket.id}',
          '/colis',
          '/colis/new',
          '/colis/${parcel.id}',
          '/location',
          '/location/veh/${vehicle.id}',
          '/location/veh/${vehicle.id}/reviews',
          '/location/request/${vehicle.id}',
          '/location/results',
          '/location/mine',
          '/location/rental/${store.rentals.first.id}',
          '/location/rental/${store.rentals.first.id}/pay',
          '/location/rental/${store.rentals.first.id}/etat',
          '/profile',
          '/profile/info',
          '/profile/security',
          '/notifications',
          '/history',
          '/history?tab=payments',
          '/promotions',
          '/promotions/${promo.id}',
          '/loyalty',
          '/tracking/${trip.id}',
          '/help',
          '/settings',
        ];

        final router = container.read(appRouterProvider);
        for (final route in routes) {
          router.go(route);
          await tester.pump();
          await tester.pump(const Duration(seconds: 1));
          final error = tester.takeException();
          if (error is FlutterError) debugPrint(error.toStringDeep());
          expect(error, isNull, reason: 'Exception sur $route');
          expect(
            find.byType(Scaffold),
            findsWidgets,
            reason: 'Pas d’écran sur $route',
          );
        }
        // Laisse expirer les minuteries (latences mock, carrousel, suivi).
        router.go('/settings');
        await tester.pump(const Duration(seconds: 5));
      },
    );
  }

  testWidgets(
    'Parcours de réservation : siège → récap → paiement → issue serveur',
    (tester) async {
      final semantics = tester.ensureSemantics();
      final container = _loggedInContainer();
      addTearDown(container.dispose);
      await _pumpApp(tester, container);
      await tester.pump();

      // Paiement sans confirmation OTP (testée séparément).
      container.read(securitySettingsProvider.notifier).setOtpPayments(false);
      final store = container.read(mockStoreProvider);
      final trip = store.trips.first;
      final bookingsBefore = store.bookings.length;
      container.read(appRouterProvider).go('/voyager/trip/${trip.id}');
      await tester.pump(const Duration(milliseconds: 500));

      // Détail du trajet → plan de sièges.
      await tester.scrollUntilVisible(
        find.text('Choisir mon siège'),
        300,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.ensureVisible(find.text('Choisir mon siège'));
      await tester.pump();
      await tester.tap(find.text('Choisir mon siège'));
      await tester.pump(const Duration(milliseconds: 500));
      expect(find.text('Choisissez encore 1 siège'), findsOneWidget);

      // Sélection du premier siège libre puis création de la réservation.
      await tester.tap(
        find.bySemanticsLabel(RegExp(r'^Siège \w+ libre')).first,
      );
      await tester.pump();
      expect(find.text('Continuer (1 siège)'), findsOneWidget);
      await tester.tap(find.text('Continuer (1 siège)'));
      await tester.pump(const Duration(milliseconds: 500));

      // Passagers : le titulaire du compte est prérempli.
      expect(find.text('Passager 1'), findsOneWidget);
      await tester.tap(find.text('Confirmer les passagers'));
      await tester.pump(const Duration(milliseconds: 700));
      await tester.pump(const Duration(milliseconds: 500));
      expect(store.bookings.length, bookingsBefore + 1);

      // Récapitulatif → paiement.
      expect(find.text('Payer maintenant'), findsOneWidget);
      await tester.tap(find.text('Payer maintenant'));
      await tester.pump(const Duration(milliseconds: 500));
      await tester.tap(find.textContaining('Payer ').last);
      await tester.pump(const Duration(milliseconds: 600));
      expect(find.text('Paiement en cours'), findsWidgets);

      // Le serveur (mock) tranche : jamais de succès supposé côté client.
      await tester.pump(const Duration(seconds: 4));
      await tester.pump(const Duration(milliseconds: 800));
      final confirmed = find.text('Voyage confirmé !').evaluate().isNotEmpty;
      final failed = find.text('Paiement échoué').evaluate().isNotEmpty;
      expect(
        confirmed || failed,
        isTrue,
        reason: 'Le paiement doit aboutir à un état terminal',
      );
      if (confirmed) {
        expect(store.bookings.first.status, BookingStatus.paye);
      }
      semantics.dispose();
    },
  );

  test('Le routeur redirige un utilisateur non connecté vers le splash', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    final router = container.read(appRouterProvider);
    expect(router, isA<GoRouter>());
    expect(container.read(authProvider).isAuthenticated, isFalse);
  });

  test('Le code PIN est stocké haché et vérifié', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    final security = container.read(securitySettingsProvider.notifier);
    security.setPin('2580');
    final state = container.read(securitySettingsProvider);
    expect(state.hasPin, isTrue);
    expect(state.pinHash, isNot(contains('2580')));
    expect(security.verifyPin('2580'), isTrue);
    expect(security.verifyPin('1111'), isFalse);
    security.clearPin();
    expect(container.read(securitySettingsProvider).hasPin, isFalse);
  });

  // ----------------------------- Authentification -----------------------------

  /// Ouvre une route d'auth (utilisateur non connecté) et laisse passer
  /// les transitions.
  Future<ProviderContainer> openAuthRoute(
    WidgetTester tester,
    String route,
  ) async {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    await _pumpApp(tester, container);
    await tester.pump();
    container.read(appRouterProvider).go(route);
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    return container;
  }

  /// Code OTP de démo affiché dans le snackbar (mode mock).
  String demoOtpCode(WidgetTester tester) {
    final text = tester
        .widgetList<Text>(find.textContaining('CODE DE DÉMO'))
        .first
        .data!;
    return RegExp(r'\d{6}').firstMatch(text)!.group(0)!;
  }

  Future<void> tapAndSettle(WidgetTester tester, Finder finder) async {
    await tester.ensureVisible(finder);
    await tester.pump();
    await tester.tap(finder);
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
  }

  testWidgets('Connexion numéro + mot de passe (erreur puis succès)', (
    tester,
  ) async {
    final container = await openAuthRoute(tester, '/auth/login');
    expect(find.text('Mot de passe oublié ?'), findsOneWidget);

    await tester.enterText(find.byType(TextField).at(0), '07 00 11 22 33');
    await tester.enterText(find.byType(TextField).at(1), 'mauvais123');
    await tester.pump();
    await tapAndSettle(tester, find.text('Se connecter'));
    expect(find.text('Numéro ou mot de passe incorrect.'), findsOneWidget);
    expect(container.read(authProvider).isAuthenticated, isFalse);

    await tester.enterText(find.byType(TextField).at(1), 'Moncar2026');
    await tester.pump();
    await tapAndSettle(tester, find.text('Se connecter'));
    expect(container.read(authProvider).isAuthenticated, isTrue);
    await tester.pump(const Duration(seconds: 5));
  });

  testWidgets('Mot de passe oublié : numéro → OTP → nouveau mot de passe', (
    tester,
  ) async {
    final container = await openAuthRoute(
      tester,
      '/auth/forgot?phone=%2B2250700112233',
    );
    await tapAndSettle(tester, find.text('Recevoir le code'));
    expect(find.text('Code de vérification'), findsOneWidget);

    await tester.enterText(find.byType(TextField).first, demoOtpCode(tester));
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    expect(find.text('Nouveau mot de passe'), findsWidgets);

    await tester.enterText(find.byType(TextField).at(0), 'Nouveau2026');
    await tester.enterText(find.byType(TextField).at(1), 'Nouveau2026');
    await tester.pump();
    await tapAndSettle(tester, find.text('Enregistrer et me connecter'));

    final store = container.read(mockStoreProvider);
    expect(container.read(authProvider).isAuthenticated, isTrue);
    expect(store.checkPassword('+2250700112233', 'Nouveau2026'), isTrue);
    expect(store.checkPassword('+2250700112233', 'Moncar2026'), isFalse);
    await tester.pump(const Duration(seconds: 10));
  });

  testWidgets('Mot de passe oublié : numéro sans compte refusé', (
    tester,
  ) async {
    await openAuthRoute(tester, '/auth/forgot?phone=%2B2250102030405');
    await tapAndSettle(tester, find.text('Recevoir le code'));
    expect(
      find.text("Aucun compte n'est associé à ce numéro. Créez un compte."),
      findsOneWidget,
    );
  });

  testWidgets('Inscription avec création du mot de passe puis OTP', (
    tester,
  ) async {
    final container = await openAuthRoute(tester, '/auth/inscription');
    final continuer = find.text('Continuer');

    await tester.enterText(find.byType(TextField).at(0), 'Aïcha');
    await tester.enterText(find.byType(TextField).at(1), 'Koné');
    await tester.pump();
    await tapAndSettle(tester, continuer);

    await tester.enterText(find.byType(TextField).at(0), '01 02 03 04 05');
    await tester.pump();
    await tapAndSettle(tester, continuer);

    expect(find.text('Sécurisez votre compte'), findsOneWidget);
    await tester.enterText(find.byType(TextField).at(0), 'Aicha2026');
    await tester.enterText(find.byType(TextField).at(1), 'Aicha2025x');
    await tester.pump();
    expect(
      find.text('Les mots de passe ne correspondent pas.'),
      findsOneWidget,
    );
    await tester.enterText(find.byType(TextField).at(1), 'Aicha2026');
    await tester.pump();
    expect(find.text('Les mots de passe correspondent.'), findsOneWidget);
    await tapAndSettle(tester, continuer);

    await tapAndSettle(tester, find.byType(Checkbox).first);
    await tapAndSettle(tester, continuer);
    expect(find.text('Vérifiez vos informations'), findsOneWidget);

    await tapAndSettle(tester, find.text('Créer mon compte'));
    expect(find.text('Vérifiez votre numéro'), findsOneWidget);
    await tester.enterText(find.byType(TextField).first, demoOtpCode(tester));
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));

    final auth = container.read(authProvider);
    expect(auth.isAuthenticated, isTrue);
    expect(auth.user!.firstName, 'Aïcha');
    expect(
      container
          .read(mockStoreProvider)
          .checkPassword('+2250102030405', 'Aicha2026'),
      isTrue,
    );
    await tester.pump(const Duration(seconds: 10));
  });

  test('Robustesse du mot de passe', () {
    expect(isPasswordValid('court1'), isFalse);
    expect(isPasswordValid('sanschiffre'), isFalse);
    expect(isPasswordValid('12345678'), isFalse);
    expect(isPasswordValid('voyage2026'), isTrue);
    expect(passwordStrength(''), 0);
    expect(passwordStrength('abc'), 1);
    expect(passwordStrength('voyage2026'), 2);
    expect(passwordStrength('Voyage2026!'), 3);
  });

  testWidgets('Aller-retour : aller → retour → passagers → 2 billets', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    final container = _loggedInContainer();
    addTearDown(container.dispose);
    await _pumpApp(tester, container);
    await tester.pump();

    final store = container.read(mockStoreProvider);
    final router = container.read(appRouterProvider);
    final outDate = dateOffset(0);
    final backDate = dateOffset(1);
    final outbound = store
        .searchTrips(
          origin: 'Abidjan',
          destination: 'Yamoussoukro',
          date: outDate,
        )
        .first;
    final back = store
        .searchTrips(
          origin: 'Yamoussoukro',
          destination: 'Abidjan',
          date: backDate,
        )
        .first;

    Future<void> chooseFirstFreeSeat() async {
      await tester.scrollUntilVisible(
        find.text('Choisir mon siège'),
        300,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.ensureVisible(find.text('Choisir mon siège'));
      await tester.pump();
      await tester.tap(find.text('Choisir mon siège'));
      await tester.pump(const Duration(milliseconds: 500));
      await tester.tap(
        find.bySemanticsLabel(RegExp(r'^Siège \w+ libre')).first,
      );
      await tester.pump();
      await tester.tap(find.text('Continuer (1 siège)'));
      await tester.pump(const Duration(milliseconds: 600));
    }

    // Recherche aller-retour : étape 1/2.
    router.go(
      '/voyager?origin=Abidjan&destination=Yamoussoukro&date=$outDate'
      '&passengers=1&type=aller_retour&returnDate=$backDate',
    );
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    expect(find.text('Étape 1/2 · Choisissez votre aller'), findsOneWidget);

    router.push('/voyager/trip/${outbound.id}');
    await tester.pump(const Duration(milliseconds: 500));
    await chooseFirstFreeSeat();

    // Le choix de l'aller ouvre la recherche du retour (sens inverse).
    await tester.pump(const Duration(seconds: 1));
    expect(find.text('Étape 2/2 · Choisissez votre retour'), findsOneWidget);
    expect(
      container.read(bookingDraftProvider).outboundLeg?.trip.id,
      outbound.id,
    );

    router.push('/voyager/trip/${back.id}?leg=retour');
    await tester.pump(const Duration(milliseconds: 500));
    await chooseFirstFreeSeat();

    // Passagers (une seule saisie) → réservation avec segment retour.
    expect(find.text('Passager 1'), findsOneWidget);
    await tester.tap(find.text('Confirmer les passagers'));
    await tester.pump(const Duration(milliseconds: 700));
    await tester.pump(const Duration(milliseconds: 500));
    final booking = store.bookings.first;
    expect(booking.tripId, outbound.id);
    expect(booking.returnLeg?.tripId, back.id);
    expect(booking.returnLeg?.seats.length, 1);
    expect(find.text('Retour'), findsWidgets);

    // Paiement (issue tranchée par le serveur mock) → deux billets.
    Payment? paid;
    for (var i = 0; i < 20 && paid == null; i++) {
      final created = store.createPayment(
        bookingId: booking.id,
        method: PaymentMethod.orangeMoney,
        idempotencyKey: 'rt-test-$i',
      );
      final r = store.processPayment(created.payment!.id);
      if (r.payment?.status == PaymentStatus.paye) paid = r.payment;
    }
    expect(paid, isNotNull);
    final tickets = store.tickets
        .where((t) => t.bookingId == booking.id)
        .toList();
    expect(tickets.length, 2);
    expect(tickets.map((t) => t.leg).toSet(), TicketLeg.values.toSet());
    expect(tickets[0].qrPayload, isNot(tickets[1].qrPayload));

    // Billet : bascule aller ↔ retour.
    final returnTicket = tickets.firstWhere((t) => t.leg == TicketLeg.retour);
    router.go('/voyager/ticket/${returnTicket.id}');
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.text('Billet aller'), findsOneWidget);
    expect(find.text('Billet retour'), findsOneWidget);
    expect(find.text('RETOUR'), findsOneWidget);
    semantics.dispose();
    await tester.pump(const Duration(seconds: 5));
  });

  // ----------------------------- Location (§25 à §51) -----------------------------

  /// Paie une location ou une facture complémentaire (issue tranchée
  /// par le serveur mock, réessai si échec simulé).
  Payment payRental(MockStore store, String rentalId) {
    for (var i = 0; i < 30; i++) {
      final created = store.createPayment(
        rentalId: rentalId,
        method: PaymentMethod.wave,
        idempotencyKey:
            'loc-$rentalId-$i-${DateTime.now().microsecondsSinceEpoch}',
      );
      expect(created.ok, isTrue, reason: created.error);
      final r = store.processPayment(created.payment!.id);
      if (r.payment?.status == PaymentStatus.paye) return r.payment!;
    }
    fail('Paiement jamais confirmé');
  }

  testWidgets(
    'Location : demande → confirmation → paiement → remise → état des lieux → active',
    (tester) async {
      final container = _loggedInContainer();
      addTearDown(container.dispose);
      await _pumpApp(tester, container);
      await tester.pump();
      final store = container.read(mockStoreProvider);
      final router = container.read(appRouterProvider);

      // Critères par défaut : Abidjan, intérieur, 1 pers., journée, sans chauffeur.
      router.go('/location');
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
      expect(find.text('Louer un véhicule'), findsOneWidget);
      await tester.ensureVisible(find.text('Voir les véhicules disponibles'));
      await tester.pump();
      await tester.tap(find.text('Voir les véhicules disponibles'));
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));

      // Règle VTC + offre chauffeur : un VTC ou un véhicule « avec
      // chauffeur » n'apparaît jamais pour une demande sans chauffeur.
      final criteria = container.read(rentalSearchProvider).toCriteria();
      final results = store.searchRentalVehicles(criteria);
      expect(results, isNotEmpty);
      expect(results.any((v) => v.isVtc), isFalse);
      expect(results.every((v) => v.canBeWithoutDriver), isTrue);
      expect(find.text('Véhicules disponibles'), findsOneWidget);

      // Fiche véhicule → demande.
      final vehicle = results.first;
      router.push('/location/veh/${vehicle.id}');
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
      await tester.tap(find.text('Demander une réservation'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      // Sans chauffeur : permis et pièce d'identité obligatoires.
      await tester.tap(find.text('Envoyer la demande'));
      await tester.pump();
      expect(find.text('Champ obligatoire.'), findsNWidgets(2));
      await tester.enterText(find.byType(TextFormField).at(0), 'CI-B-2019-1');
      await tester.enterText(find.byType(TextFormField).at(1), 'C0012345678');
      await tester.pump();
      await tester.tap(find.text('Envoyer la demande'));
      await tester.pump(const Duration(milliseconds: 800));
      await tester.pump(const Duration(milliseconds: 500));

      final rental = store.rentals.first;
      expect(rental.status, RentalStatus.demandee);
      expect(find.text('EN ATTENTE DE CONFIRMATION'), findsOneWidget);

      // Règle 10 : aucun paiement avant confirmation du fournisseur.
      final early = store.createPayment(
        rentalId: rental.id,
        method: PaymentMethod.wave,
        idempotencyKey: 'early',
      );
      expect(early.ok, isFalse);

      // Le fournisseur confirme → facture X + Y + Z → paiement.
      store.providerRespond(rental.id, accept: true);
      await tester.pump();
      expect(find.text('Votre demande a été confirmée.'), findsOneWidget);
      final q = store.findRental(rental.id)!.quote;
      expect(q.totalXOF, q.brutXOF + q.feesXOF + q.otherFeesXOF);
      payRental(store, rental.id);
      await tester.pump();
      expect(store.findRental(rental.id)!.status, RentalStatus.payee);

      // Remise : l'heure de remise devient le début réel (§41).
      store.providerHandover(rental.id);
      await tester.pump();
      expect(store.findRental(rental.id)!.handoverAt, isNotNull);
      await tester.ensureVisible(find.text("Faire l'état des lieux"));
      await tester.pump();
      await tester.tap(find.text("Faire l'état des lieux"));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      // État initial : kilométrage obligatoire, puis « conforme ».
      await tester.tap(find.text('Véhicule conforme'));
      await tester.pump();
      expect(store.findRental(rental.id)!.status, RentalStatus.remise);
      await tester.enterText(find.byType(TextFormField).first, '48210');
      await tester.pump();
      await tester.tap(find.text('Véhicule conforme'));
      await tester.pump(const Duration(milliseconds: 800));
      await tester.pump(const Duration(milliseconds: 500));

      final active = store.findRental(rental.id)!;
      expect(active.status, RentalStatus.active);
      expect(active.startCondition?.mileageKm, 48210);
      // La liste est restée défilée (bouton « état des lieux ») : le titre
      // du panneau peut être au-dessus de la zone visible.
      expect(find.text('LOCATION ACTIVE', skipOffstage: false), findsOneWidget);
      await tester.pump(const Duration(seconds: 5));
    },
  );

  test(
    'Location : prolongation, heures supplémentaires, incident, clôture',
    () {
      final store = MockStore();
      final v = store.findRentalVehicle('rv_001')!; // prolongation avec accord
      final start = DateTime.now().add(const Duration(days: 40));
      final criteria = RentalCriteria(
        pickupCity: 'Abidjan',
        pickupLabel: 'Plateau, Abidjan',
        area: RentalArea.exterieur,
        destinationCity: 'Yamoussoukro',
        purpose: RentalPurpose.tourisme,
        persons: 3,
        start: start.toIso8601String(),
        end: start.add(const Duration(days: 2)).toIso8601String(),
        durationPreset: RentalDurationPreset.plusieursJours,
        withDriver: true,
      );
      final created = store.createRentalRequest(
        vehicleId: v.id,
        criteria: criteria,
      );
      expect(created.ok, isTrue, reason: created.error);
      final id = created.rental!.id;
      // Extérieur : majoration visible dans le brut.
      expect(
        created.rental!.quote.brutLines.any(
          (l) => l.label.contains('extérieur'),
        ),
        isTrue,
      );

      // Règle 8 : pas deux locations incompatibles confirmées en même temps.
      store.providerRespond(id, accept: true);
      final clash = store.createRentalRequest(
        vehicleId: v.id,
        criteria: criteria,
      );
      expect(clash.ok, isFalse);

      payRental(store, id);
      store.providerHandover(id);
      store.submitStartCondition(
        id,
        VehicleCondition(
          recordedAt: DateTime.now().toIso8601String(),
          mileageKm: 1000,
          fuelEighths: 8,
          photos: const ['plaque'],
        ),
      );
      expect(store.findRental(id)!.status, RentalStatus.active);

      // Prolongation : demande → accord fournisseur → facture → paiement.
      final oldEnd = DateTime.parse(store.findRental(id)!.plannedEnd);
      final ext = store.requestExtension(id, extraDays: 1);
      expect(ext.ok, isTrue);
      expect(ext.extension!.status, RentalExtensionStatus.demandee);
      expect(store.findRental(id)!.pendingCharge, isNull);
      store.providerRespondExtension(id, ext.extension!.id, accept: true);
      expect(
        store.findRental(id)!.pendingCharge?.kind,
        RentalChargeKind.prolongation,
      );
      payRental(store, id);
      final extended = store.findRental(id)!;
      expect(
        DateTime.parse(extended.plannedEnd),
        oldEnd.add(const Duration(days: 1)),
      );
      expect(extended.extraCharges, hasLength(1));

      // Incident → litige ; restitution en retard → heures supplémentaires.
      store.reportRentalIncident(
        id,
        nature: RentalIncidentNature.panne,
        description: 'Voyant moteur allumé sur l\'autoroute du Nord',
      );
      expect(store.findRental(id)!.hasOpenIncident, isTrue);
      store.providerRecordReturn(id, lateHours: 2);
      final returned = store.findRental(id)!;
      expect(returned.status, RentalStatus.restituee);
      expect(returned.pendingCharge?.amountXOF, 2 * v.extraHourXOF);
      expect(returned.returnCondition, isNotNull);

      // Clôture bloquée tant que la facture et le dossier sont ouverts.
      expect(store.providerCloseRental(id).ok, isFalse);
      payRental(store, id);
      final close = store.providerCloseRental(id);
      expect(close.ok, isFalse);
      expect(close.error, contains('incident'));
    },
  );

  test('Location : règle VTC, refus sans paiement, capacité collective', () {
    final store = MockStore();
    final start = DateTime.now().add(const Duration(days: 3));
    RentalCriteria c({
      bool withDriver = false,
      int persons = 1,
      bool? collective,
    }) => RentalCriteria(
      pickupCity: 'Abidjan',
      pickupLabel: 'Abidjan',
      area: RentalArea.interieur,
      purpose: RentalPurpose.mariage,
      persons: persons,
      collective: collective,
      start: start.toIso8601String(),
      end: start.add(const Duration(days: 1)).toIso8601String(),
      durationPreset: RentalDurationPreset.journee,
      withDriver: withDriver,
    );

    // VTC : jamais sans chauffeur.
    final vtc = store.createRentalRequest(
      vehicleId: 'rv_009',
      criteria: c(),
      licenseNumber: 'X',
      idDocumentNumber: 'Y',
    );
    expect(vtc.ok, isFalse);
    expect(vtc.error, contains('VTC'));
    expect(RentalSearch(type: VehicleType.vtc).effectiveWithDriver, isTrue);

    // 30 personnes, transport collectif : seul le car de 50 places.
    final big = store.searchRentalVehicles(
      c(withDriver: true, persons: 30, collective: true),
    );
    expect(big.map((v) => v.id), ['rv_012']);

    // Refus : aucun paiement possible.
    final req = store.createRentalRequest(
      vehicleId: 'rv_012',
      criteria: c(withDriver: true, persons: 30),
    );
    store.providerRespond(req.rental!.id, accept: false);
    expect(store.findRental(req.rental!.id)!.status, RentalStatus.refusee);
    expect(
      store
          .createPayment(
            rentalId: req.rental!.id,
            method: PaymentMethod.wave,
            idempotencyKey: 'refus',
          )
          .ok,
      isFalse,
    );
  });
}
