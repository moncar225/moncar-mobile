import 'package:flutter/material.dart';

import 'package:core_ui/core_ui.dart';

/// Onglets principaux de l'app client (portage du `BottomNav` web).
enum MoncarTab { home, voyager, colis, location, profile }

/// Barre de navigation inférieure MON CAR.
/// La barre elle-même est sans état : le shell (go_router) fournit
/// l'onglet actif et le callback de sélection.
class MoncarBottomNav extends StatelessWidget {
  const MoncarBottomNav({
    super.key,
    required this.currentTab,
    required this.onTabSelected,
  });

  final MoncarTab currentTab;
  final ValueChanged<MoncarTab> onTabSelected;

  @override
  Widget build(BuildContext context) {
    final entries = <(MoncarTab, String, IconData)>[
      (MoncarTab.home, 'Accueil', Icons.home_outlined),
      (MoncarTab.voyager, 'Voyager', Icons.directions_bus_outlined),
      (MoncarTab.colis, 'Colis', Icons.inventory_2_outlined),
      (MoncarTab.location, 'Location', Icons.directions_car_outlined),
      (MoncarTab.profile, 'Profil', Icons.person_outline),
    ];

    return Container(
      decoration: BoxDecoration(
        color: MoncarColors.surface.withValues(alpha: 0.97),
        border: Border(top: BorderSide(color: MoncarColors.hairline)),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF002060).withValues(alpha: 0.18),
            blurRadius: 24,
            offset: const Offset(0, -6),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: 64,
          child: Row(
            children: [
              for (final (tab, label, icon) in entries)
                Expanded(
                  child: _TabButton(
                    entry: (tab, label, icon),
                    currentTab: currentTab,
                    onTabSelected: onTabSelected,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TabButton extends StatelessWidget {
  const _TabButton({
    required this.entry,
    required this.currentTab,
    required this.onTabSelected,
  });

  final (MoncarTab, String, IconData) entry;
  final MoncarTab currentTab;
  final ValueChanged<MoncarTab> onTabSelected;

  @override
  Widget build(BuildContext context) {
    final (tab, label, icon) = entry;
    final active = tab == currentTab;
    final color = active ? MoncarColors.accent : MoncarColors.inkFaint;
    return InkWell(
      onTap: () => onTabSelected(tab),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          if (active)
            Container(
              width: 32,
              height: 2,
              margin: const EdgeInsets.only(bottom: 2),
              decoration: BoxDecoration(
                color: MoncarColors.accent,
                borderRadius: BorderRadius.all(Radius.circular(999)),
              ),
            ),
          Icon(icon, size: 22, color: color, weight: active ? 2.5 : 2),
          Text(
            label,
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}
