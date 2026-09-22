import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:core_ui/core_ui.dart';

import 'router.dart';

/// Racine de l'app MON CAR Client.
class MoncarClientApp extends ConsumerWidget {
  const MoncarClientApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(appRouterProvider);
    return MaterialApp.router(
      title: 'MON CAR',
      theme: MoncarTheme.light(),
      routerConfig: router,
    );
  }
}
