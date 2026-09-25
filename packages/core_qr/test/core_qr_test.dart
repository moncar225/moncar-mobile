import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import 'package:core_qr/core_qr.dart';

void main() {
  testWidgets('MoncarQrScanner affiche son app bar et sa consigne', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: MoncarQrScanner(
          onDetect: (BarcodeCapture capture) {},
          helpText: 'Présentez votre billet',
        ),
      ),
    );
    await tester.pump();

    expect(find.text('Scanner un code QR'), findsOneWidget);
    expect(find.text('Présentez votre billet'), findsOneWidget);
  });
}
