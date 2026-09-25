import 'package:core_ui/core_ui.dart';
import 'package:flutter/material.dart';

import '../domain/models.dart';

/// Teinte métier de chaque profil, posée sur la palette MON CAR
/// (navy #002060 + orange #FF6600). Variantes éclaircies en mode sombre.
extension ProRoleStyle on ProRole {
  Color get accent {
    final dark = MoncarColors.isDark;
    return switch (this) {
      ProRole.controleur =>
        dark ? const Color(0xFF5B8DEF) : const Color(0xFF1547A0),
      ProRole.convoyeur =>
        dark ? const Color(0xFF2DD4BF) : const Color(0xFF0F766E),
      ProRole.chauffeur =>
        dark ? const Color(0xFFFF8C3A) : const Color(0xFFE35A00),
      ProRole.agentBusiness =>
        dark ? const Color(0xFFA78BFA) : const Color(0xFF6D28D9),
    };
  }

  /// Dégradé des cartes « héros » (texte blanc garanti).
  List<Color> get gradient => switch (this) {
    ProRole.controleur => const [Color(0xFF002060), Color(0xFF1547A0)],
    ProRole.convoyeur => const [Color(0xFF064E47), Color(0xFF0F766E)],
    ProRole.chauffeur => const [Color(0xFF0B1B3F), Color(0xFF1E3A6E)],
    ProRole.agentBusiness => const [Color(0xFF3B1782), Color(0xFF6D28D9)],
  };

  Color get soft => accent.withValues(alpha: MoncarColors.isDark ? 0.22 : 0.10);
}
