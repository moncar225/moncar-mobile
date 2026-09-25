import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:moncar_pro/app/app.dart';
import 'package:moncar_pro/app/router.dart';
import 'package:moncar_pro/core/application/app_providers.dart';
import 'package:moncar_pro/core/data/pro_api.dart';
import 'package:moncar_pro/core/domain/models.dart';

Widget _app() => ProviderScope(
  overrides: [
    proApiProvider.overrideWithValue(MockProApi(latency: Duration.zero)),
  ],
  child: const MoncarProApp(),
);

Future<void> _openLogin(WidgetTester tester) async {
  await tester.binding.setSurfaceSize(const Size(420, 900));
  addTearDown(() => tester.binding.setSurfaceSize(null));
  await tester.pumpWidget(_app());
  await tester.pumpAndSettle();
  expect(find.text('Contrôlez en une seconde'), findsOneWidget);
  await tester.tap(find.text('Passer'));
  await tester.pumpAndSettle();
  expect(find.text('Connexion'), findsOneWidget);
}

Future<void> _tapVisible(WidgetTester tester, Finder f) async {
  await tester.ensureVisible(f);
  await tester.pumpAndSettle();
  await tester.tap(f);
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('Connexion : le poste du compte s’applique directement', (
    tester,
  ) async {
    await _openLogin(tester);

    await tester.enterText(find.byType(TextField).at(0), '07 00 00 00 02');
    await tester.enterText(
      find.byType(TextField).at(1),
      MockProApi.demoPassword,
    );
    await tester.pump();
    await tester.tap(find.text('Se connecter'));
    await tester.pumpAndSettle();

    expect(find.text('Bonjour, Aminata'), findsOneWidget);
    expect(find.text('Confirmer les présences'), findsOneWidget);
  });

  testWidgets('Connexion : mauvais mot de passe → message clair', (
    tester,
  ) async {
    await _openLogin(tester);

    await tester.enterText(find.byType(TextField).at(0), '07 00 00 00 02');
    await tester.enterText(find.byType(TextField).at(1), 'faux-mdp');
    await tester.pump();
    await tester.tap(find.text('Se connecter'));
    await tester.pumpAndSettle();

    expect(find.text('Numéro ou mot de passe incorrect.'), findsOneWidget);
  });

  testWidgets('Inscription : choix du poste → identité → rattachement → '
      'sécurité → confirmation → code SMS → accueil du poste', (tester) async {
    await _openLogin(tester);
    await _tapVisible(tester, find.text('Créer mon compte agent'));
    expect(find.text('Choisissez votre poste'), findsOneWidget);

    // 1. Poste
    await _tapVisible(tester, find.text('Chauffeur'));
    await tester.tap(find.text('Continuer'));
    await tester.pumpAndSettle();

    // 2. Identité
    await tester.enterText(find.byType(TextField).at(0), 'Ali');
    await tester.enterText(find.byType(TextField).at(1), 'Ouattara');
    await tester.pump();
    await tester.tap(find.text('Continuer'));
    await tester.pumpAndSettle();

    // 3. Rattachement
    await _tapVisible(tester, find.text('Lagune Express (démo)'));
    await _tapVisible(tester, find.text('Gare d’Abobo'));
    await tester.tap(find.text('Continuer'));
    await tester.pumpAndSettle();

    // 4. Sécurité
    await tester.enterText(find.byType(TextField).at(0), '05 55 44 33 22');
    await tester.enterText(find.byType(TextField).at(1), 'Chauffeur2026');
    await tester.enterText(find.byType(TextField).at(2), 'Chauffeur2026');
    await tester.pump();
    await tester.tap(find.text('Continuer'));
    await tester.pumpAndSettle();

    // 5. Confirmation
    expect(find.text('Ali Ouattara'), findsOneWidget);
    await _tapVisible(tester, find.byType(CheckboxListTile));
    await tester.tap(find.text('Créer mon compte'));
    await tester.pumpAndSettle();

    // Code SMS
    expect(find.text('Vérifiez votre numéro'), findsOneWidget);
    await tester.enterText(find.byType(TextField).first, MockProApi.demoOtp);
    await tester.pumpAndSettle();

    expect(find.text('Bonjour, Ali'), findsOneWidget);
    expect(find.text('Glisser pour démarrer'), findsOneWidget);
    // Laisse la notification de bienvenue se refermer.
    await tester.pump(const Duration(seconds: 4));
    await tester.pumpAndSettle();
  });

  test('Garde d’interface par profil', () {
    expect(routeAllowed('/ctrl/historique', ProRole.controleur), isTrue);
    expect(routeAllowed('/ctrl/historique', ProRole.chauffeur), isFalse);
    expect(routeAllowed('/manifeste/p1', ProRole.convoyeur), isTrue);
    expect(routeAllowed('/manifeste', ProRole.chauffeur), isFalse);
    expect(routeAllowed('/biz/missions', ProRole.agentBusiness), isTrue);
    expect(routeAllowed('/voyage', ProRole.agentBusiness), isFalse);
    expect(routeAllowed('/incidents', ProRole.chauffeur), isTrue);
  });

  group('Comptes (MOCK)', () {
    final api = MockProApi(latency: Duration.zero);

    test('numéro inconnu → invitation à créer un compte', () async {
      await expectLater(
        api.login(phone: '0102030405', password: 'x'),
        throwsA(
          isA<ProApiException>().having((e) => e.statusCode, 'code', 404),
        ),
      );
    });

    test('inscription sur un numéro existant → refus', () async {
      await expectLater(
        api.register(
          const SignupRequest(
            role: ProRole.convoyeur,
            firstName: 'A',
            lastName: 'B',
            phone: '0700000001',
            email: '',
            company: 'X',
            station: 'Y',
            matricule: '',
            password: 'Abcdefg1',
          ),
        ),
        throwsA(
          isA<ProApiException>().having((e) => e.statusCode, 'code', 409),
        ),
      );
    });

    test('mot de passe temporaire → changement obligatoire', () async {
      final u = await api.login(phone: '0700000003', password: 'Temp1234');
      expect(u.mustChangePassword, isTrue);
      expect(u.roles, [ProRole.chauffeur]);
    });
  });
}
