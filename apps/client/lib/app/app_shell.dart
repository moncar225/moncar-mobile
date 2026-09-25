import 'package:flutter/material.dart';

import 'package:core_ui/core_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../features/shared/application/providers.dart';
import '../features/shared/widgets/bottom_nav.dart';

/// Onglet associé à une route (pour la barre de navigation).
MoncarTab tabForLocation(String location) {
  if (location.startsWith('/voyager')) return MoncarTab.voyager;
  if (location.startsWith('/colis')) return MoncarTab.colis;
  if (location.startsWith('/location')) return MoncarTab.location;
  if (location.startsWith('/profile')) return MoncarTab.profile;
  return MoncarTab.home;
}

/// Routes des 5 onglets principaux (seules à afficher la bottom nav).
const Set<String> primaryTabLocations = {
  '/home',
  '/voyager',
  '/colis',
  '/location',
  '/profile',
};

/// Coquille de l'app client : contenu + barre de navigation inférieure
/// sur les 5 onglets principaux (portage du `AppShell` web).
class AppShell extends ConsumerWidget {
  const AppShell({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final uri = GoRouter.of(context).routerDelegate.currentConfiguration.uri;
    final location = uri.path;
    // `/voyager?origin=…` = résultats de recherche : pas de bottom nav
    // (équivalent de `voyager/results` du prototype web).
    final showNav =
        primaryTabLocations.contains(location) && uri.queryParameters.isEmpty;
    final online = ref.watch(onlineProvider);

    return Scaffold(
      backgroundColor: MoncarColors.background,
      body: Column(
        children: [
          if (!online) const MoncarOfflineBanner(),
          Expanded(child: child),
          if (showNav)
            MoncarBottomNav(
              currentTab: tabForLocation(location),
              onTabSelected: (tab) {
                final path = switch (tab) {
                  MoncarTab.home => '/home',
                  MoncarTab.voyager => '/voyager',
                  MoncarTab.colis => '/colis',
                  MoncarTab.location => '/location',
                  MoncarTab.profile => '/profile',
                };
                if (location != path) context.go(path);
              },
            ),
        ],
      ),
    );
  }
}
