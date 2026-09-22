import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:core_ui/core_ui.dart';

import 'router.dart';

/// Racine de l'app MON CAR Pro (compagnies, agences, business, admins).
class MoncarProApp extends ConsumerWidget {
  const MoncarProApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(appRouterProvider);
    return MaterialApp.router(
      title: 'MON CAR — Pro',
      theme: MoncarTheme.light(),
      routerConfig: router,
    );
  }
}
