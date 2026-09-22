import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:core_ui/core_ui.dart';

Widget _host(Widget child) => MaterialApp(home: Scaffold(body: child));

void main() {
  group('MoncarButton', () {
    testWidgets('déclenche onPressed au tap', (tester) async {
      var pressed = false;
      await tester.pumpWidget(_host(
        MoncarButton(label: 'Réserver', onPressed: () => pressed = true),
      ));

      await tester.tap(find.text('Réserver'));
      expect(pressed, isTrue);
    });

    testWidgets('état loading : pas de tap possible, spinner affiché', (tester) async {
      var pressed = false;
      await tester.pumpWidget(_host(
        MoncarButton(
          label: 'Réserver',
          isLoading: true,
          onPressed: () => pressed = true,
        ),
      ));

      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      await tester.tap(find.byType(MoncarButton), warnIfMissed: false);
      expect(pressed, isFalse);
    });
  });

  group('états', () {
    testWidgets('MoncarEmptyState affiche titre, message et action', (tester) async {
      await tester.pumpWidget(_host(
        MoncarEmptyState(
          title: 'Aucun voyage',
          message: 'Aucun voyage ne correspond à votre recherche.',
          actionLabel: 'Réinitialiser',
          onAction: () {},
        ),
      ));

      expect(find.text('Aucun voyage'), findsOneWidget);
      expect(find.text('Réinitialiser'), findsOneWidget);
    });

    testWidgets('MoncarErrorState affiche le message, le bouton réessayer '
        'et la référence incident si fournie', (tester) async {
      await tester.pumpWidget(_host(
        MoncarErrorState(
          message: 'Une erreur est survenue côté serveur.',
          onRetry: () {},
          incidentId: 'INC-123',
        ),
      ));

      expect(find.text('Réessayer'), findsOneWidget);
      expect(find.textContaining('INC-123'), findsOneWidget);
    });
  });

  test('MoncarSpacing suit une échelle de 4', () {
    expect(MoncarSpacing.xs, 4);
    expect(MoncarSpacing.sm, 8);
    expect(MoncarSpacing.md, 16);
  });
}
