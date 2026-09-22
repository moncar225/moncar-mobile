import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../features/home/presentation/home_page.dart';

/// Router de l'app MON CAR Pro (go_router).
///
/// Sprint 1 : une seule route publique. Les espaces protégés par rôle
/// (compagnie, agence de location, propriétaire, chauffeur VTC, admin) seront
/// ajoutés avec les features et la couche auth.
final appRouterProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    initialLocation: '/',
    routes: [
      GoRoute(
        path: '/',
        name: 'home',
        builder: (context, state) => const ProHomePage(),
      ),
    ],
  );
});
