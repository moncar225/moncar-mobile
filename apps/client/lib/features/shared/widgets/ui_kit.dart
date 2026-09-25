// ============================================================
// MON CAR — Petits utilitaires UI partagés par les écrans client
// (équivalents de MCInput/MCLabel/RecapRow, toasts, navigation
// « retour » du routeur à pile du prototype web).
// ============================================================

library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:core_ui/core_ui.dart';
import 'package:go_router/go_router.dart';

/// Couleur depuis une chaîne hexadécimale « #RRGGBB » (données mock).
Color hexColor(String hex) {
  final h = hex.replaceFirst('#', '');
  return Color(int.parse(h.length == 6 ? 'FF$h' : h, radix: 16));
}

extension MoncarNavigation on BuildContext {
  /// Retour arrière : dépile si possible, sinon retour à l'accueil
  /// (équivalent de `back()` du routeur web à pile vide).
  void mcBack() {
    if (canPop()) {
      pop();
    } else {
      go('/home');
    }
  }
}

/// Toast léger (équivalent `sonner` du prototype).
void showMoncarToast(
  BuildContext context,
  String message, {
  bool error = false,
  bool success = false,
}) {
  final messenger = ScaffoldMessenger.maybeOf(context);
  if (messenger == null) return;
  messenger
    ..hideCurrentSnackBar()
    ..showSnackBar(
      SnackBar(
        behavior: SnackBarBehavior.floating,
        backgroundColor: error
            ? MoncarColors.danger
            : success
            ? MoncarColors.success
            : MoncarColors.ink,
        content: Text(message),
        duration: const Duration(seconds: 3),
      ),
    );
}

/// Copie dans le presse-papiers + toast de confirmation.
Future<void> copyWithToast(
  BuildContext context,
  String text, {
  String message = 'Copié',
}) async {
  await Clipboard.setData(ClipboardData(text: text));
  if (context.mounted) showMoncarToast(context, message, success: true);
}

/// Libellé de champ (équivalent `MCLabel`).
class MoncarLabel extends StatelessWidget {
  const MoncarLabel(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: MoncarColors.inkMut,
        ),
      ),
    );
  }
}

/// Champ texte MON CAR (équivalent `MCInput`) avec libellé et erreur.
class MoncarTextField extends StatelessWidget {
  const MoncarTextField({
    super.key,
    this.label,
    this.controller,
    this.hint,
    this.error,
    this.keyboardType,
    this.onChanged,
    this.prefixIcon,
    this.suffix,
    this.maxLines = 1,
    this.maxLength,
    this.inputFormatters,
    this.textCapitalization = TextCapitalization.none,
    this.obscureText = false,
    this.enabled = true,
    this.autofocus = false,
    this.readOnly = false,
    this.onTap,
    this.initialValue,
  });

  final String? label;
  final TextEditingController? controller;
  final String? hint;
  final String? error;
  final TextInputType? keyboardType;
  final ValueChanged<String>? onChanged;
  final IconData? prefixIcon;
  final Widget? suffix;
  final int maxLines;
  final int? maxLength;
  final List<TextInputFormatter>? inputFormatters;
  final TextCapitalization textCapitalization;
  final bool obscureText;
  final bool enabled;
  final bool autofocus;
  final bool readOnly;
  final VoidCallback? onTap;
  final String? initialValue;

  @override
  Widget build(BuildContext context) {
    final border = OutlineInputBorder(
      borderRadius: BorderRadius.circular(14),
      borderSide: BorderSide(color: MoncarColors.hairline),
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (label != null) MoncarLabel(label!),
        TextFormField(
          controller: controller,
          initialValue: controller == null ? initialValue : null,
          keyboardType: keyboardType,
          onChanged: onChanged,
          maxLines: maxLines,
          maxLength: maxLength,
          inputFormatters: inputFormatters,
          textCapitalization: textCapitalization,
          obscureText: obscureText,
          enabled: enabled,
          autofocus: autofocus,
          readOnly: readOnly,
          onTap: onTap,
          style: TextStyle(fontSize: 14, color: MoncarColors.ink),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: TextStyle(color: MoncarColors.inkFaint),
            counterText: '',
            isDense: true,
            filled: true,
            fillColor: MoncarColors.surface,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 14,
              vertical: 13,
            ),
            prefixIcon: prefixIcon == null
                ? null
                : Icon(prefixIcon, size: 18, color: MoncarColors.inkMut),
            suffixIcon: suffix,
            border: border,
            enabledBorder: border.copyWith(
              borderSide: BorderSide(
                color: error != null
                    ? MoncarColors.danger
                    : MoncarColors.hairline,
              ),
            ),
            focusedBorder: border.copyWith(
              borderSide: BorderSide(
                color: error != null ? MoncarColors.danger : MoncarColors.brand,
                width: 1.5,
              ),
            ),
          ),
        ),
        if (error != null) FieldError(error!),
      ],
    );
  }
}

/// Message d'erreur sous un champ.
class FieldError extends StatelessWidget {
  const FieldError(this.message, {super.key});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: Row(
        children: [
          Icon(Icons.error_outline, size: 12, color: MoncarColors.danger),
          const SizedBox(width: 4),
          Expanded(
            child: Text(
              message,
              style: TextStyle(fontSize: 11, color: MoncarColors.danger),
            ),
          ),
        ],
      ),
    );
  }
}

/// Ligne libellé / valeur des récapitulatifs.
class RecapRow extends StatelessWidget {
  const RecapRow({
    super.key,
    required this.label,
    required this.value,
    this.bold = false,
    this.valueColor,
    this.icon,
  });

  final String label;
  final String value;
  final bool bold;
  final Color? valueColor;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 14, color: MoncarColors.inkMut),
            const SizedBox(width: 8),
          ],
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                fontSize: bold ? 14 : 13,
                color: bold ? MoncarColors.ink : MoncarColors.inkMut,
                fontWeight: bold ? FontWeight.w700 : FontWeight.w400,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Flexible(
            child: Text(
              value,
              textAlign: TextAlign.right,
              style: TextStyle(
                fontSize: bold ? 15 : 13,
                fontWeight: bold ? FontWeight.w800 : FontWeight.w600,
                color: valueColor ?? MoncarColors.ink,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Bloc « carré icône » coloré (icônes de service, catégories…).
class IconTile extends StatelessWidget {
  const IconTile({
    super.key,
    required this.icon,
    this.color,
    this.background,
    this.size = 40,
    this.iconSize,
    this.radius = 12,
  });

  final IconData icon;

  /// Couleur de l'icône (marque par défaut).
  final Color? color;
  final Color? background;
  final double size;
  final double? iconSize;
  final double radius;

  @override
  Widget build(BuildContext context) {
    final color = this.color ?? MoncarColors.brand;
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: background ?? color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(radius),
      ),
      alignment: Alignment.center,
      child: Icon(icon, size: iconSize ?? size * 0.5, color: color),
    );
  }
}

/// Barre d'action collée en bas d'écran (CTA principal).
class StickyBottomBar extends StatelessWidget {
  const StickyBottomBar({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: MoncarColors.surface,
        border: Border(top: BorderSide(color: MoncarColors.hairline)),
      ),
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      child: SafeArea(top: false, child: child),
    );
  }
}

/// Fond dégradé de marque (bg-brand-grad).
BoxDecoration brandGradientDecoration({BorderRadius? radius}) => BoxDecoration(
  gradient: LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: MoncarColors.brandGradient,
  ),
  borderRadius: radius,
);

/// Fond dégradé accent (bg-accent-grad).
BoxDecoration accentGradientDecoration({BorderRadius? radius}) => BoxDecoration(
  gradient: LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: MoncarColors.accentGradient,
  ),
  borderRadius: radius,
);

/// Ligne d'étiquette en capitales (titres de section discrets).
class OverlineText extends StatelessWidget {
  const OverlineText(this.text, {super.key, this.color});

  final String text;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final color = this.color ?? MoncarColors.inkMut;
    return Text(
      text.toUpperCase(),
      style: TextStyle(
        fontSize: 11,
        fontWeight: FontWeight.w700,
        letterSpacing: 0.6,
        color: color,
      ),
    );
  }
}
