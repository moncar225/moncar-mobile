import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:moncar_client/app/app.dart';

void main() {
  testWidgets('L\u2019app client affiche l\u2019accueil avec les trois services', (tester) async {
    await tester.pumpWidget(const ProviderScope(child: MoncarClientApp()));
    await tester.pumpAndSettle();

    expect(find.text('MON CAR'), findsOneWidget);
    expect(find.text('Voyager'), findsOneWidget);
    expect(find.text('Envoyer un colis'), findsOneWidget);
    expect(find.text('Louer un véhicule'), findsOneWidget);
  });
}
