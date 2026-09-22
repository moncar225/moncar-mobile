import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';

import 'package:core_geo/core_geo.dart';

void main() {
  testWidgets('MoncarMap se construit avec un centre et un zoom', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 400,
            height: 400,
            child: MoncarMap(center: const LatLng(5.3599517, -4.0083458)),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(MoncarMap), findsOneWidget);
  });
}
