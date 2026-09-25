import 'dart:ui';

import 'package:core_api/core_api.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'app/app.dart';
import 'app/monitoring.dart';
import 'features/shared/application/providers.dart';
import 'firebase_options.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Projet Firebase « mon-car-2026 » (mon-car-a5a97), configuré par
  // `flutterfire configure` — voir lib/firebase_options.dart.
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  // Crashlytics : erreurs Flutter fatales d'un côté, erreurs asynchrones
  // hors zone Flutter (futures non attrapées) de l'autre — remontées
  // avec leur stack trace.
  await FirebaseCrashlytics.instance.setCustomKey(
    'env',
    AppEnvironment.current.name,
  );
  FlutterError.onError = FirebaseCrashlytics.instance.recordFlutterFatalError;
  PlatformDispatcher.instance.onError = (error, stack) {
    FirebaseCrashlytics.instance.recordError(error, stack, fatal: true);
    return true;
  };

  await runMonitored(() async {
    final prefs = await SharedPreferences.getInstance();
    runApp(
      ProviderScope(
        overrides: [sharedPrefsProvider.overrideWithValue(prefs)],
        child: const MoncarClientApp(),
      ),
    );
  });
}
