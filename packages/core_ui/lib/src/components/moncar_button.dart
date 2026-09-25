import 'package:flutter/material.dart';

import '../theme/moncar_colors.dart';

/// Variantes du bouton MON CAR (alignées sur le design system web).
enum MoncarButtonVariant {
  primary,
  brand,
  outline,
  ghost,
  soft,
  danger,
  success,
}

/// Tailles du bouton MON CAR.
enum MoncarButtonSize {
  sm(36, EdgeInsets.symmetric(horizontal: 12), 13),
  md(44, EdgeInsets.symmetric(horizontal: 16), 14),
  lg(48, EdgeInsets.symmetric(horizontal: 20), 15),
  xl(56, EdgeInsets.symmetric(horizontal: 24), 16);

  const MoncarButtonSize(this.height, this.padding, this.fontSize);
  final double height;
  final EdgeInsets padding;
  final double fontSize;
}

/// Bouton MON CAR (Design System).
///
/// API alignée sur le design system web (`MCButton`) :
/// [variant] et [size]. Les anciens booléens [secondary] / [danger]
/// restent acceptés pour compatibilité (apps existantes).
class MoncarButton extends StatelessWidget {
  const MoncarButton({
    super.key,
    required this.label,
    this.onPressed,
    this.secondary = false,
    this.danger = false,
    this.isLoading = false,
    this.icon,
    this.variant,
    this.size,
    this.expand = false,
  }) : assert(
         !(secondary && danger),
         'Un bouton ne peut pas être à la fois secondaire et danger.',
       );

  final String label;
  final VoidCallback? onPressed;
  final bool secondary;
  final bool danger;
  final bool isLoading;
  final IconData? icon;
  final MoncarButtonVariant? variant;
  final MoncarButtonSize? size;

  /// Étire le bouton sur toute la largeur disponible (utilisé avec `xl`).
  final bool expand;

  MoncarButtonVariant get _variant {
    if (variant != null) return variant!;
    if (secondary) return MoncarButtonVariant.outline;
    if (danger) return MoncarButtonVariant.danger;
    return MoncarButtonVariant.primary;
  }

  @override
  Widget build(BuildContext context) {
    final enabled = onPressed != null && !isLoading;
    final sizeStyle = size ?? MoncarButtonSize.md;

    final (bg, fg, side) = switch (_variant) {
      MoncarButtonVariant.primary => (MoncarColors.accent, Colors.white, null),
      MoncarButtonVariant.brand => (MoncarColors.brand, Colors.white, null),
      MoncarButtonVariant.outline => (
        MoncarColors.surface,
        MoncarColors.brand,
        BorderSide(
          color: enabled ? MoncarColors.brand : Theme.of(context).disabledColor,
          width: 2,
        ),
      ),
      MoncarButtonVariant.ghost => (
        Colors.transparent,
        MoncarColors.brand,
        null,
      ),
      MoncarButtonVariant.soft => (
        MoncarColors.brandSoft,
        MoncarColors.brand,
        null,
      ),
      MoncarButtonVariant.danger => (MoncarColors.danger, Colors.white, null),
      MoncarButtonVariant.success => (MoncarColors.success, Colors.white, null),
    };

    final child = isLoading
        ? SizedBox(
            width: 18,
            height: 18,
            child: CircularProgressIndicator(strokeWidth: 2, color: fg),
          )
        : (icon != null
              ? Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(icon, size: 18, color: fg),
                    const SizedBox(width: 8),
                    // Libellé réductible : évite tout débordement sur écran étroit
                    // ou avec une grande taille de police d'accessibilité.
                    Flexible(
                      child: Text(
                        label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                )
              : Text(label, maxLines: 1, overflow: TextOverflow.ellipsis));

    final button = switch (_variant) {
      MoncarButtonVariant.outline => OutlinedButton(
        onPressed: enabled ? onPressed : null,
        style:
            OutlinedButton.styleFrom(
              foregroundColor: fg,
              backgroundColor: bg,
              side: side,
              minimumSize: Size(expand ? double.infinity : 0, sizeStyle.height),
              padding: sizeStyle.padding,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
              textStyle: TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: sizeStyle.fontSize,
              ),
            ).merge(
              OutlinedButton.styleFrom(
                disabledForegroundColor: Theme.of(context).disabledColor,
              ),
            ),
        child: child,
      ),
      _ => FilledButton(
        onPressed: enabled ? onPressed : null,
        style: FilledButton.styleFrom(
          backgroundColor: bg,
          disabledBackgroundColor: bg.withValues(alpha: 0.5),
          foregroundColor: fg,
          minimumSize: Size(expand ? double.infinity : 0, sizeStyle.height),
          padding: sizeStyle.padding,
          elevation: _variant == MoncarButtonVariant.primary ? 4 : 0,
          shadowColor: MoncarColors.accent.withValues(alpha: 0.45),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          textStyle: TextStyle(
            fontWeight: FontWeight.w600,
            fontSize: sizeStyle.fontSize,
          ),
        ),
        child: child,
      ),
    };

    if (!expand) return button;
    return SizedBox(width: double.infinity, child: button);
  }
}
