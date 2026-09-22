import 'package:flutter/material.dart';
import 'package:core_ui/core_ui.dart';

/// Accueil de l'app Pro.
///
/// Sprint 1 : écran d'attente. La connexion par rôle et les tableaux de bord
/// (voyages, colis, locations) seront construits avec les features, une fois
/// les endpoints du backend disponibles.
class ProHomePage extends StatelessWidget {
  const ProHomePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('MON CAR — Pro')),
      body: const MoncarEmptyState(
        icon: Icons.admin_panel_settings_outlined,
        title: 'Espace professionnel',
        message:
            'Les fonctionnalités professionnelles seront disponibles prochainement.',
      ),
    );
  }
}
