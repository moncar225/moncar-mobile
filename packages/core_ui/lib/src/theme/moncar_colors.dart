import 'package:flutter/material.dart';

/// Une palette complète MON CAR (claire ou sombre).
@immutable
class MoncarPalette {
  const MoncarPalette({
    required this.brightness,
    required this.brand,
    required this.brand2,
    required this.brand3,
    required this.brandSoft,
    required this.brandInk,
    required this.accent,
    required this.accent2,
    required this.accentSoft,
    required this.accentInk,
    required this.success,
    required this.successSoft,
    required this.danger,
    required this.dangerSoft,
    required this.warn,
    required this.warnSoft,
    required this.info,
    required this.background,
    required this.surface,
    required this.hairline,
    required this.muted,
    required this.ink,
    required this.inkMut,
    required this.inkFaint,
  });

  final Brightness brightness;
  final Color brand;
  final Color brand2;
  final Color brand3;
  final Color brandSoft;
  final Color brandInk;
  final Color accent;
  final Color accent2;
  final Color accentSoft;
  final Color accentInk;
  final Color success;
  final Color successSoft;
  final Color danger;
  final Color dangerSoft;
  final Color warn;
  final Color warnSoft;
  final Color info;
  final Color background;
  final Color surface;
  final Color hairline;
  final Color muted;
  final Color ink;
  final Color inkMut;
  final Color inkFaint;

  /// Palette claire officielle : Navy #002060 + Orange #FF6600.
  static const light = MoncarPalette(
    brightness: Brightness.light,
    brand: Color(0xFF002060),
    brand2: Color(0xFF0A2D6E),
    brand3: Color(0xFF1547A0),
    brandSoft: Color(0xFFE5EBF6),
    brandInk: Color(0xFF001A4D),
    accent: Color(0xFFFF6600),
    accent2: Color(0xFFFF7A00),
    accentSoft: Color(0xFFFFF0E3),
    accentInk: Color(0xFFCC4D00),
    success: Color(0xFF1FA25C),
    successSoft: Color(0xFFE3F6EC),
    danger: Color(0xFFE0433D),
    dangerSoft: Color(0xFFFDE7E6),
    warn: Color(0xFFE8A33D),
    warnSoft: Color(0xFFFDF3E0),
    info: Color(0xFF2B6CB0),
    background: Color(0xFFFFFFFF),
    surface: Color(0xFFFFFFFF),
    hairline: Color(0xFFEEF0F4),
    muted: Color(0xFFEEF1F7),
    ink: Color(0xFF16213E),
    inkMut: Color(0xFF6B7690),
    inkFaint: Color(0xFF767D8F),
  );

  /// Palette sombre : fonds bleu nuit, textes clairs. Le navy de marque
  /// est éclairci pour rester lisible en texte et en icône sur fond
  /// sombre, tout en gardant un contraste suffisant avec du texte blanc.
  static const dark = MoncarPalette(
    brightness: Brightness.dark,
    brand: Color(0xFF3A6FD8),
    brand2: Color(0xFF0A2D6E),
    brand3: Color(0xFF1547A0),
    brandSoft: Color(0xFF1B2A48),
    brandInk: Color(0xFFB9CCF2),
    accent: Color(0xFFFF7A1F),
    accent2: Color(0xFFFF8C3A),
    accentSoft: Color(0xFF3B2414),
    accentInk: Color(0xFFFFB27A),
    success: Color(0xFF34C477),
    successSoft: Color(0xFF12301F),
    danger: Color(0xFFF26B65),
    dangerSoft: Color(0xFF3A1A1A),
    warn: Color(0xFFF0B455),
    warnSoft: Color(0xFF3A2E14),
    info: Color(0xFF6FA4E0),
    background: Color(0xFF0D1220),
    surface: Color(0xFF161D2E),
    hairline: Color(0xFF28324A),
    muted: Color(0xFF1E2638),
    ink: Color(0xFFE7EBF3),
    inkMut: Color(0xFFA9B2C6),
    inkFaint: Color(0xFF8C95AA),
  );
}

/// Palette MON CAR (Design System) active — harmonisée avec le logo
/// officiel : Navy #002060 + Orange #FF6600 (source : design system web).
///
/// Les couleurs suivent la palette active ([MoncarPalette.light] ou
/// [MoncarPalette.dark]) : changer de palette via [usePalette] puis
/// reconstruire l'arbre (voir `rebuildAllWidgets`).
abstract final class MoncarColors {
  static MoncarPalette _p = MoncarPalette.light;

  /// Palette actuellement appliquée.
  static MoncarPalette get palette => _p;

  static bool get isDark => _p.brightness == Brightness.dark;

  /// Change la palette active. Renvoie `true` si elle a changé.
  static bool usePalette(MoncarPalette p) {
    if (identical(p, _p)) return false;
    _p = p;
    return true;
  }

  // ---- Marque ----
  /// Couleur principale de la marque (boutons « brand », éléments actifs).
  static Color get brand => _p.brand;
  static Color get brand2 => _p.brand2;
  static Color get brand3 => _p.brand3;
  static Color get brandSoft => _p.brandSoft;
  static Color get brandInk => _p.brandInk;

  /// Couleur d'accent (CTA, promotions, fidélité).
  static Color get accent => _p.accent;
  static Color get accent2 => _p.accent2;
  static Color get accentSoft => _p.accentSoft;
  static Color get accentInk => _p.accentInk;

  // ---- Sémantiques ----
  static Color get success => _p.success;
  static Color get successSoft => _p.successSoft;
  static Color get danger => _p.danger;
  static Color get dangerSoft => _p.dangerSoft;
  static Color get warn => _p.warn;
  static Color get warnSoft => _p.warnSoft;
  static Color get info => _p.info;

  // ---- Surfaces et textes ----
  static Color get background => _p.background;

  /// Fond des cartes, feuilles, champs et barres.
  static Color get surface => _p.surface;
  static Color get hairline => _p.hairline;
  static Color get muted => _p.muted;
  static Color get ink => _p.ink;
  static Color get inkMut => _p.inkMut;
  static Color get inkFaint => _p.inkFaint;

  // ---- Dégradés de marque (dégradé linéaire 135°) ----
  /// Toujours navy (en-têtes, billets) : le texte y est blanc.
  static List<Color> get brandGradient => const [
    Color(0xFF002060),
    Color(0xFF0A2D6E),
    Color(0xFF1547A0),
  ];
  static List<Color> get accentGradient => [_p.accent, _p.accent2];

  // ---- Alias historiques (conservés pour compat apps existantes) ----
  static Color get primary => brand;
  static Color get primaryDark => brandInk;
  static Color get textPrimary => ink;
  static Color get textSecondary => inkMut;
  static Color get border => hairline;
  static Color get warning => warn;
}

/// Force la reconstruction de tous les widgets (y compris `const`) après
/// un changement de palette, sans perdre l'état (comme un hot reload).
void rebuildAllWidgets() {
  void visit(Element e) {
    e.markNeedsBuild();
    e.visitChildren(visit);
  }

  WidgetsBinding.instance.rootElement?.visitChildren(visit);
}
