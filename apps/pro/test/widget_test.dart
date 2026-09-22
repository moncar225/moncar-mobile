import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:moncar_pro/app/app.dart';

void main() {
  testWidgets('L\u2019app PRO affiche son écran d\u2019accueil', (tester) async {
    await tester.pumpWidget(const ProviderScope(child: MoncarProApp()));
    await tester.pumpAndSettle();

    expect(find.text('MON CAR — Pro'), findsOneWidget);
  });
}
