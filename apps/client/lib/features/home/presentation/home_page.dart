import 'package:flutter/material.dart';
import 'package:core_ui/core_ui.dart';

import '../widgets/service_entry_card.dart';

/// Accueil de l'app Client.
///
/// Sprint 1 : squelette avec les trois entrées principales (cahier des
/// charges) — les écrans de recherche/réservation arrivent avec les features.
class HomePage extends StatelessWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('MON CAR')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(MoncarSpacing.md),
          children: [
            Text(
              'Où souhaitez-vous aller aujourd\u2019hui ?',
              style: theme.textTheme.titleLarge,
            ),
            const SizedBox(height: MoncarSpacing.lg),
            ServiceEntryCard(
              icon: Icons.directions_bus_rounded,
              title: 'Voyager',
              subtitle: 'Rechercher, comparer et réserver un voyage',
              // Fonctionnalités à venir — écrans non disponibles en Sprint 1.
              onTap: null,
            ),
            const SizedBox(height: MoncarSpacing.md),
            ServiceEntryCard(
              icon: Icons.local_shipping_outlined,
              title: 'Envoyer un colis',
              subtitle: 'Confier un colis et le suivre jusqu\u2019à la remise',
              onTap: null,
            ),
            const SizedBox(height: MoncarSpacing.md),
            ServiceEntryCard(
              icon: Icons.directions_car_filled_outlined,
              title: 'Louer un véhicule',
              subtitle: 'Réserver un véhicule avec ou sans chauffeur',
              onTap: null,
            ),
          ],
        ),
      ),
    );
  }
}
