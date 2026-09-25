import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:core_ui/core_ui.dart';

import '../features/auth/presentation/app_lock_gate.dart';
import '../features/shared/application/providers.dart';
import 'router.dart';

/// Racine de l'app MON CAR Client.
class MoncarClientApp extends ConsumerStatefulWidget {
  const MoncarClientApp({super.key});

  @override
  ConsumerState<MoncarClientApp> createState() => _MoncarClientAppState();
}

class _MoncarClientAppState extends ConsumerState<MoncarClientApp>
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

  /// Mode « Système » : suit le thème du téléphone en direct.
  @override
  void didChangePlatformBrightness() => setState(() {});

  bool _isDark(AppThemeChoice choice) => switch (choice) {
    AppThemeChoice.clair => false,
    AppThemeChoice.sombre => true,
    AppThemeChoice.systeme =>
      WidgetsBinding.instance.platformDispatcher.platformBrightness ==
          Brightness.dark,
  };

  @override
  Widget build(BuildContext context) {
    final router = ref.watch(appRouterProvider);
    final dark = _isDark(ref.watch(appPreferencesProvider).theme);
    // Les couleurs MON CAR sont lues via MoncarColors : on change la
    // palette active puis on redessine tout l'arbre (état conservé).
    if (MoncarColors.usePalette(
      dark ? MoncarPalette.dark : MoncarPalette.light,
    )) {
      WidgetsBinding.instance.addPostFrameCallback((_) => rebuildAllWidgets());
    }
    SystemChrome.setSystemUIOverlayStyle(
      dark ? SystemUiOverlayStyle.light : SystemUiOverlayStyle.dark,
    );
    return MaterialApp.router(
      title: 'MON CAR',
      debugShowCheckedModeBanner: false,
      theme: MoncarTheme.light(),
      darkTheme: MoncarTheme.dark(),
      themeMode: dark ? ThemeMode.dark : ThemeMode.light,
      locale: const Locale('fr'),
      supportedLocales: const [Locale('fr'), Locale('en')],
      localizationsDelegates: GlobalMaterialLocalizations.delegates,
      routerConfig: router,
      builder: (context, child) => AppLockGate(child: child!),
    );
  }
}
