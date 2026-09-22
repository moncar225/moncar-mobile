import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../features/home/presentation/home_page.dart';

/// Router de l'app MON CAR Client (go_router).
///
/// Squelette Sprint 1 : une seule route. Les routes protégées (auth) et le
/// deep linking (billets, suivi colis) seront ajoutés avec les features.
final appRouterProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    initialLocation: '/',
    routes: [
      GoRoute(
        path: '/',
        name: 'home',
        builder: (context, state) => const HomePage(),
      ),
    ],
  );
});
