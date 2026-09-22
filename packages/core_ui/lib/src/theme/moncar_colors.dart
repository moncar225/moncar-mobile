import 'package:flutter/material.dart';

/// Palette MON CAR (Design System).
///
/// ⚠️ À valider avec la charte graphique officielle MON CAR dès qu'elle est
/// disponible : les valeurs ci-dessous constituent un point de départ neutre
/// et cohérent, pas la marque définitive.
abstract final class MoncarColors {
  /// Couleur principale de la marque (boutons, éléments actifs).
  static const Color primary = Color(0xFF0A4DA3);

  /// Variante foncée pour les appuis/enfants sur primaire.
  static const Color primaryDark = Color(0xFF083A7A);

  /// Couleur d'accent (promotions, fidélité).
  static const Color accent = Color(0xFFF5A524);

  /// Surfaces.
  static const Color background = Color(0xFFF6F7F9);
  static const Color surface = Colors.white;

  /// Texte.
  static const Color textPrimary = Color(0xFF17202B);
  static const Color textSecondary = Color(0xFF5B6675);

  /// Sémantiques.
  static const Color success = Color(0xFF1D8A50);
  static const Color warning = Color(0xFFB97A0A);
  static const Color danger = Color(0xFFC03A2B);
  static const Color info = Color(0xFF2B6CB0);

  /// Bordures et séparateurs.
  static const Color border = Color(0xFFE1E5EA);
}
