import 'package:core_ui/core_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/application/app_providers.dart';
import 'router.dart';

/// Racine de l'app MON CAR PRO (terrain des compagnies de transport).
class MoncarProApp extends ConsumerStatefulWidget {
  const MoncarProApp({super.key});

  @override
  ConsumerState<MoncarProApp> createState() => _MoncarProAppState();
}

class _MoncarProAppState extends ConsumerState<MoncarProApp>
    with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  /// Mode « Système » : suit le thème du téléphone (conduite de nuit).
  @override
  void didChangePlatformBrightness() => setState(() {});

  @override
  Widget build(BuildContext context) {
    final router = ref.watch(appRouterProvider);
    final choice = ref.watch(settingsProvider.select((s) => s.theme));
    final dark = switch (choice) {
      ThemeChoice.clair => false,
      ThemeChoice.sombre => true,
      ThemeChoice.systeme =>
        WidgetsBinding.instance.platformDispatcher.platformBrightness ==
            Brightness.dark,
    };
    if (MoncarColors.usePalette(
      dark ? MoncarPalette.dark : MoncarPalette.light,
    )) {
      WidgetsBinding.instance.addPostFrameCallback((_) => rebuildAllWidgets());
    }
    SystemChrome.setSystemUIOverlayStyle(
      dark ? SystemUiOverlayStyle.light : SystemUiOverlayStyle.dark,
    );
    return MaterialApp.router(
      title: 'MON CAR PRO',
      debugShowCheckedModeBanner: false,
      theme: MoncarTheme.light(),
      darkTheme: MoncarTheme.dark(),
      themeMode: dark ? ThemeMode.dark : ThemeMode.light,
      locale: const Locale('fr'),
      supportedLocales: const [Locale('fr'), Locale('en')],
      localizationsDelegates: GlobalMaterialLocalizations.delegates,
      routerConfig: router,
    );
  }
}
