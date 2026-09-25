// ============================================================
// MON CAR PRO — Kit d'écrans terrain (au-dessus de core_ui).
//
// Grandes cibles tactiles (≥ 56 px pour les actions principales),
// contraste élevé lisible au soleil, confirmations sur les actions
// sensibles. Aucun composant ne contient de règle métier.
// ============================================================

library;

import 'package:core_ui/core_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';

// ----------------------------- Retour haptique -----------------------------

enum HapticKind { tap, success, error, heavy }

/// Retour haptique terrain (vibration courte, succès, erreur, action forte).
Future<void> haptic(HapticKind kind) async {
  switch (kind) {
    case HapticKind.tap:
      await HapticFeedback.selectionClick();
    case HapticKind.success:
      await HapticFeedback.mediumImpact();
    case HapticKind.error:
      await HapticFeedback.heavyImpact();
      await Future<void>.delayed(const Duration(milliseconds: 120));
      await HapticFeedback.heavyImpact();
    case HapticKind.heavy:
      await HapticFeedback.heavyImpact();
  }
}

// ----------------------------- Logo -----------------------------

class ProLogo extends StatelessWidget {
  const ProLogo({super.key, this.size = 32, this.ring = false});

  final double size;
  final bool ring;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      padding: EdgeInsets.all(size * 0.04),
      decoration: BoxDecoration(
        color: Colors.white,
        shape: BoxShape.circle,
        border: ring
            ? Border.all(
                color: MoncarColors.accent.withValues(alpha: 0.35),
                width: 3,
              )
            : null,
        boxShadow: ring
            ? [
                BoxShadow(
                  color: const Color(0xFF002060).withValues(alpha: 0.25),
                  blurRadius: 24,
                  offset: const Offset(0, 10),
                ),
              ]
            : null,
      ),
      child: ClipOval(
        child: Image.asset('assets/moncar-logo.png', fit: BoxFit.contain),
      ),
    );
  }
}

class ProWordmark extends StatelessWidget {
  const ProWordmark({super.key, this.fontSize = 16, this.onDark = false});

  final double fontSize;
  final bool onDark;

  @override
  Widget build(BuildContext context) {
    return Text.rich(
      TextSpan(
        children: [
          TextSpan(
            text: 'MON CAR ',
            style: TextStyle(color: onDark ? Colors.white : MoncarColors.ink),
          ),
          TextSpan(
            text: 'PRO',
            style: TextStyle(color: MoncarColors.accent),
          ),
        ],
      ),
      style: TextStyle(
        fontSize: fontSize,
        fontWeight: FontWeight.w800,
        letterSpacing: 0.4,
      ),
    );
  }
}

// ----------------------------- Page -----------------------------

/// Page secondaire (poussée au-dessus du shell) : en-tête + contenu défilant.
class ProPage extends StatelessWidget {
  const ProPage({
    super.key,
    required this.title,
    required this.children,
    this.subtitle,
    this.actions = const [],
    this.bottom,
    this.onBack,
    this.padding = const EdgeInsets.fromLTRB(16, 4, 16, 24),
  });

  final String title;
  final String? subtitle;
  final List<Widget> children;
  final List<Widget> actions;

  /// Barre d'action collée en bas (bouton principal).
  final Widget? bottom;
  final VoidCallback? onBack;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: MoncarColors.background,
      body: SafeArea(
        bottom: bottom == null,
        child: Column(
          children: [
            ProHeader(
              title: title,
              subtitle: subtitle,
              actions: actions,
              onBack: onBack,
            ),
            Expanded(
              child: ListView(padding: padding, children: children),
            ),
          ],
        ),
      ),
      bottomNavigationBar: bottom == null
          ? null
          : StickyActionBar(child: bottom!),
    );
  }
}

class ProHeader extends StatelessWidget {
  const ProHeader({
    super.key,
    required this.title,
    this.subtitle,
    this.actions = const [],
    this.onBack,
  });

  final String title;
  final String? subtitle;
  final List<Widget> actions;
  final VoidCallback? onBack;

  @override
  Widget build(BuildContext context) {
    final canPop = onBack != null || GoRouter.of(context).canPop();
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 8, 12, 8),
      child: Row(
        children: [
          if (canPop)
            CircleIconButton(
              icon: Icons.arrow_back_rounded,
              tooltip: 'Retour',
              onTap: onBack ?? () => context.pop(),
            )
          else
            const SizedBox(width: 8),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 19,
                    fontWeight: FontWeight.w800,
                    color: MoncarColors.ink,
                  ),
                ),
                if (subtitle != null)
                  Text(
                    subtitle!,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 12.5,
                      color: MoncarColors.inkMut,
                    ),
                  ),
              ],
            ),
          ),
          ...actions,
        ],
      ),
    );
  }
}

class CircleIconButton extends StatelessWidget {
  const CircleIconButton({
    super.key,
    required this.icon,
    required this.onTap,
    this.tooltip,
    this.badge,
    this.color,
    this.background,
  });

  final IconData icon;
  final VoidCallback onTap;
  final String? tooltip;
  final int? badge;
  final Color? color;
  final Color? background;

  @override
  Widget build(BuildContext context) {
    final btn = Material(
      color: background ?? MoncarColors.muted,
      shape: const CircleBorder(),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: SizedBox(
          width: 42,
          height: 42,
          child: Icon(icon, size: 21, color: color ?? MoncarColors.ink),
        ),
      ),
    );
    final withBadge = (badge ?? 0) > 0
        ? Stack(
            clipBehavior: Clip.none,
            children: [
              btn,
              Positioned(
                right: -2,
                top: -2,
                child: Container(
                  constraints: const BoxConstraints(minWidth: 18),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 5,
                    vertical: 1,
                  ),
                  decoration: BoxDecoration(
                    color: MoncarColors.danger,
                    borderRadius: BorderRadius.circular(999),
                    border: Border.all(
                      color: MoncarColors.background,
                      width: 2,
                    ),
                  ),
                  child: Text(
                    badge! > 9 ? '9+' : '$badge',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ),
            ],
          )
        : btn;
    return tooltip == null
        ? withBadge
        : Tooltip(message: tooltip!, child: withBadge);
  }
}

/// Barre d'action collée en bas (au-dessus de la zone sûre).
class StickyActionBar extends StatelessWidget {
  const StickyActionBar({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: MoncarColors.surface,
        border: Border(top: BorderSide(color: MoncarColors.hairline)),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
          child: child,
        ),
      ),
    );
  }
}

// ----------------------------- Cartes -----------------------------

/// Carte « héros » en dégradé (voyage du jour, prochain arrêt…).
class HeroCard extends StatelessWidget {
  const HeroCard({
    super.key,
    required this.colors,
    required this.child,
    this.onTap,
    this.padding = const EdgeInsets.all(18),
  });

  final List<Color> colors;
  final Widget child;
  final VoidCallback? onTap;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) {
    final content = Container(
      padding: padding,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: colors,
        ),
        boxShadow: [
          BoxShadow(
            color: colors.last.withValues(alpha: 0.35),
            blurRadius: 22,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Stack(
        children: [
          Positioned(
            right: -30,
            top: -40,
            child: Container(
              width: 140,
              height: 140,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withValues(alpha: 0.06),
              ),
            ),
          ),
          DefaultTextStyle.merge(
            style: const TextStyle(color: Colors.white),
            child: IconTheme.merge(
              data: const IconThemeData(color: Colors.white),
              child: child,
            ),
          ),
        ],
      ),
    );
    if (onTap == null) return content;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(24),
        onTap: onTap,
        child: content,
      ),
    );
  }
}

/// Pastille translucide pour les cartes héros.
class GlassPill extends StatelessWidget {
  const GlassPill({super.key, required this.label, this.icon});

  final String label;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.16),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: Colors.white.withValues(alpha: 0.22)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 14, color: Colors.white),
            const SizedBox(width: 5),
          ],
          Text(
            label,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

/// Indicateur chiffré (dashboard, manifeste).
class KpiTile extends StatelessWidget {
  const KpiTile({
    super.key,
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
    this.onTap,
    this.caption,
  });

  final String label;
  final String value;
  final IconData icon;
  final Color color;
  final VoidCallback? onTap;
  final String? caption;

  @override
  Widget build(BuildContext context) {
    return MoncarCard(
      onTap: onTap,
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  color: color.withValues(
                    alpha: MoncarColors.isDark ? 0.22 : 0.12,
                  ),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, size: 19, color: color),
              ),
              const Spacer(),
              if (onTap != null)
                Icon(
                  Icons.chevron_right_rounded,
                  size: 18,
                  color: MoncarColors.inkFaint,
                ),
            ],
          ),
          const SizedBox(height: 10),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              value,
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.w800,
                color: MoncarColors.ink,
                height: 1.1,
              ),
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(fontSize: 12, color: MoncarColors.inkMut),
          ),
          if (caption != null)
            Text(
              caption!,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 11,
                color: color,
                fontWeight: FontWeight.w600,
              ),
            ),
        ],
      ),
    );
  }
}

/// Grille 2 colonnes à hauteur naturelle.
class TwoColumnGrid extends StatelessWidget {
  const TwoColumnGrid({super.key, required this.children, this.gap = 12});

  final List<Widget> children;
  final double gap;

  @override
  Widget build(BuildContext context) {
    final rows = <Widget>[];
    for (var i = 0; i < children.length; i += 2) {
      rows.add(
        IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(child: children[i]),
              SizedBox(width: gap),
              Expanded(
                child: i + 1 < children.length
                    ? children[i + 1]
                    : const SizedBox(),
              ),
            ],
          ),
        ),
      );
      if (i + 2 < children.length) rows.add(SizedBox(height: gap));
    }
    return Column(children: rows);
  }
}

/// Mini-compteur centré (synthèses de liste).
class MiniStat extends StatelessWidget {
  const MiniStat({
    super.key,
    required this.value,
    required this.label,
    required this.color,
    this.icon,
  });

  final String value;
  final String label;
  final Color color;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
      decoration: BoxDecoration(
        color: MoncarColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: MoncarColors.hairline),
      ),
      child: Column(
        children: [
          if (icon != null) Icon(icon, size: 18, color: color),
          Text(
            value,
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w800,
              color: color,
            ),
          ),
          Text(
            label,
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(fontSize: 11, color: MoncarColors.inkMut),
          ),
        ],
      ),
    );
  }
}

/// Ligne libellé / valeur.
class DetailRow extends StatelessWidget {
  const DetailRow({
    super.key,
    required this.label,
    required this.value,
    this.icon,
    this.valueColor,
    this.onDark = false,
  });

  final String label;
  final String value;
  final IconData? icon;
  final Color? valueColor;
  final bool onDark;

  @override
  Widget build(BuildContext context) {
    final mut = onDark ? Colors.white70 : MoncarColors.inkMut;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        children: [
          if (icon != null) ...[
            Icon(icon, size: 17, color: mut),
            const SizedBox(width: 8),
          ],
          Text(label, style: TextStyle(fontSize: 13.5, color: mut)),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              value,
              textAlign: TextAlign.right,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 13.5,
                fontWeight: FontWeight.w700,
                color: valueColor ?? (onDark ? Colors.white : MoncarColors.ink),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Titre de section.
class SectionTitle extends StatelessWidget {
  const SectionTitle(this.title, {super.key, this.trailing, this.top = 20});

  final String title;
  final Widget? trailing;
  final double top;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(2, top, 2, 10),
      child: Row(
        children: [
          Expanded(
            child: Text(
              title,
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w800,
                color: MoncarColors.ink,
              ),
            ),
          ),
          ?trailing,
        ],
      ),
    );
  }
}

// ----------------------------- Filtres -----------------------------

class FilterOption<T> {
  const FilterOption(this.value, this.label, {this.count});
  final T value;
  final String label;
  final int? count;
}

/// Barre de filtres horizontale (puces).
class FilterBar<T> extends StatelessWidget {
  const FilterBar({
    super.key,
    required this.options,
    required this.selected,
    required this.onSelected,
    required this.accent,
  });

  final List<FilterOption<T>> options;
  final T selected;
  final ValueChanged<T> onSelected;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 40,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: options.length,
        separatorBuilder: (_, _) => const SizedBox(width: 8),
        itemBuilder: (context, i) {
          final o = options[i];
          final active = o.value == selected;
          return Material(
            color: active ? accent : MoncarColors.surface,
            shape: StadiumBorder(
              side: BorderSide(color: active ? accent : MoncarColors.hairline),
            ),
            child: InkWell(
              customBorder: const StadiumBorder(),
              onTap: () {
                haptic(HapticKind.tap);
                onSelected(o.value);
              },
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 14),
                child: Center(
                  child: Text(
                    o.count == null ? o.label : '${o.label}  ${o.count}',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: active ? Colors.white : MoncarColors.inkMut,
                    ),
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

/// Champ de recherche compact.
class SearchField extends StatelessWidget {
  const SearchField({super.key, required this.hint, required this.onChanged});

  final String hint;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return TextField(
      onChanged: onChanged,
      textInputAction: TextInputAction.search,
      decoration: InputDecoration(
        hintText: hint,
        prefixIcon: Icon(Icons.search_rounded, color: MoncarColors.inkFaint),
        contentPadding: const EdgeInsets.symmetric(vertical: 12),
      ),
    );
  }
}

// ----------------------------- Actions -----------------------------

/// Gros bouton d'action terrain (h. 60), utilisable d'une main.
class BigActionButton extends StatelessWidget {
  const BigActionButton({
    super.key,
    required this.label,
    required this.icon,
    required this.color,
    required this.onPressed,
    this.loading = false,
    this.height = 60,
  });

  final String label;
  final IconData icon;
  final Color color;
  final VoidCallback? onPressed;
  final bool loading;
  final double height;

  @override
  Widget build(BuildContext context) {
    final enabled = onPressed != null && !loading;
    return SizedBox(
      height: height,
      width: double.infinity,
      child: FilledButton(
        onPressed: enabled ? onPressed : null,
        style: FilledButton.styleFrom(
          backgroundColor: color,
          disabledBackgroundColor: color.withValues(alpha: 0.4),
          foregroundColor: Colors.white,
          disabledForegroundColor: Colors.white70,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
          ),
          textStyle: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800),
        ),
        child: loading
            ? const SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(
                  strokeWidth: 2.4,
                  color: Colors.white,
                ),
              )
            : Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(icon, size: 24),
                  const SizedBox(width: 10),
                  Flexible(
                    child: Text(
                      label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}

/// Tuile d'action rapide (dashboard).
class QuickActionTile extends StatelessWidget {
  const QuickActionTile({
    super.key,
    required this.label,
    required this.icon,
    required this.color,
    required this.onTap,
    this.badge,
  });

  final String label;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;
  final String? badge;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: color.withValues(alpha: MoncarColors.isDark ? 0.16 : 0.07),
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: () {
          haptic(HapticKind.tap);
          onTap();
        },
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: color.withValues(alpha: 0.25)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 42,
                    height: 42,
                    decoration: BoxDecoration(
                      color: color,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Icon(icon, color: Colors.white, size: 22),
                  ),
                  const Spacer(),
                  if (badge != null)
                    MoncarBadge(
                      label: badge!,
                      size: MoncarBadgeSize.sm,
                      backgroundColor: color,
                      textColor: Colors.white,
                    ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      label,
                      maxLines: 2,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: MoncarColors.ink,
                        height: 1.2,
                      ),
                    ),
                  ),
                  Icon(Icons.arrow_forward_rounded, size: 18, color: color),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// « Glisser pour confirmer » : pour les actions définitives du
/// chauffeur (démarrer, clôturer) — évite les appuis accidentels.
class SwipeToConfirm extends StatefulWidget {
  const SwipeToConfirm({
    super.key,
    required this.label,
    required this.color,
    required this.onConfirmed,
    this.icon = Icons.arrow_forward_rounded,
    this.enabled = true,
  });

  final String label;
  final Color color;
  final IconData icon;
  final bool enabled;
  final Future<void> Function() onConfirmed;

  @override
  State<SwipeToConfirm> createState() => _SwipeToConfirmState();
}

class _SwipeToConfirmState extends State<SwipeToConfirm>
    with SingleTickerProviderStateMixin {
  double _dx = 0;
  double _from = 0;
  bool _busy = false;
  late final AnimationController _back;

  static const _h = 64.0;
  static const _knob = 54.0;

  @override
  void initState() {
    super.initState();
    // Créé ici (et non à la volée) : sinon dispose() le créerait sur un
    // widget déjà désactivé.
    _back = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 250),
    )..addListener(() => setState(() => _dx = _from * (1 - _back.value)));
  }

  @override
  void dispose() {
    _back.dispose();
    super.dispose();
  }

  void _reset() {
    _from = _dx;
    _back.forward(from: 0);
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, c) {
        final max = c.maxWidth - _knob - 10;
        final progress = max <= 0 ? 0.0 : (_dx / max).clamp(0.0, 1.0);
        return Opacity(
          opacity: widget.enabled ? 1 : 0.45,
          child: Container(
            height: _h,
            decoration: BoxDecoration(
              color: widget.color,
              borderRadius: BorderRadius.circular(_h / 2),
              boxShadow: [
                BoxShadow(
                  color: widget.color.withValues(alpha: 0.35),
                  blurRadius: 18,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Stack(
              alignment: Alignment.centerLeft,
              children: [
                Center(
                  child: Opacity(
                    opacity: 1 - progress,
                    child: Padding(
                      padding: const EdgeInsets.only(left: 48),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Flexible(
                            child: Text(
                              _busy ? 'Enregistrement…' : widget.label,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 16.5,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                          const SizedBox(width: 6),
                          const Icon(
                            Icons.keyboard_double_arrow_right_rounded,
                            color: Colors.white70,
                            size: 20,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                Positioned(
                  left: 5 + _dx,
                  child: GestureDetector(
                    onHorizontalDragUpdate: !widget.enabled || _busy
                        ? null
                        : (d) => setState(
                            () => _dx = (_dx + d.delta.dx).clamp(0.0, max),
                          ),
                    onHorizontalDragEnd: !widget.enabled || _busy
                        ? null
                        : (_) async {
                            if (progress > 0.85) {
                              setState(() {
                                _dx = max;
                                _busy = true;
                              });
                              haptic(HapticKind.heavy);
                              await widget.onConfirmed();
                              if (mounted) {
                                setState(() => _busy = false);
                                _reset();
                              }
                            } else {
                              _reset();
                            }
                          },
                    child: Container(
                      width: _knob,
                      height: _knob,
                      decoration: const BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                      ),
                      child: _busy
                          ? Padding(
                              padding: const EdgeInsets.all(15),
                              child: CircularProgressIndicator(
                                strokeWidth: 2.6,
                                color: widget.color,
                              ),
                            )
                          : Icon(widget.icon, color: widget.color, size: 26),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

// ----------------------------- Retours utilisateur -----------------------------

enum ToastTone { info, success, warning, error }

void showProToast(
  BuildContext context,
  String message, {
  ToastTone tone = ToastTone.info,
}) {
  final (icon, color) = switch (tone) {
    ToastTone.info => (Icons.info_rounded, MoncarColors.info),
    ToastTone.success => (Icons.check_circle_rounded, MoncarColors.success),
    ToastTone.warning => (Icons.cloud_off_rounded, MoncarColors.warn),
    ToastTone.error => (Icons.error_rounded, MoncarColors.danger),
  };
  final m = ScaffoldMessenger.maybeOf(context);
  if (m == null) return;
  m
    ..hideCurrentSnackBar()
    ..showSnackBar(
      SnackBar(
        backgroundColor: const Color(0xFF16213E),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        duration: const Duration(seconds: 3),
        content: Row(
          children: [
            Icon(icon, color: color, size: 20),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                message,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      ),
    );
}

/// Feuille de confirmation (actions sensibles / irréversibles).
Future<bool> confirmAction(
  BuildContext context, {
  required String title,
  required String message,
  required String confirmLabel,
  IconData icon = Icons.help_outline_rounded,
  Color? color,
}) async {
  final c = color ?? MoncarColors.brand;
  final ok = await showModalBottomSheet<bool>(
    context: context,
    useSafeArea: true,
    builder: (context) => Padding(
      padding: const EdgeInsets.fromLTRB(20, 14, 20, 20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: MoncarColors.hairline,
              borderRadius: BorderRadius.circular(99),
            ),
          ),
          const SizedBox(height: 18),
          Container(
            width: 60,
            height: 60,
            decoration: BoxDecoration(
              color: c.withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: c, size: 30),
          ),
          const SizedBox(height: 14),
          Text(
            title,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w800,
              color: MoncarColors.ink,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            message,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 14,
              color: MoncarColors.inkMut,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 20),
          BigActionButton(
            label: confirmLabel,
            icon: Icons.check_rounded,
            color: c,
            height: 54,
            onPressed: () => Navigator.of(context).pop(true),
          ),
          const SizedBox(height: 8),
          SizedBox(
            width: double.infinity,
            height: 48,
            child: TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: Text(
                'Annuler',
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                  color: MoncarColors.inkMut,
                ),
              ),
            ),
          ),
        ],
      ),
    ),
  );
  return ok ?? false;
}

/// Carte vide (liste sans résultat).
class EmptyCard extends StatelessWidget {
  const EmptyCard({
    super.key,
    required this.message,
    this.icon = Icons.inbox_rounded,
  });

  final String message;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 20),
      decoration: BoxDecoration(
        color: MoncarColors.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: MoncarColors.hairline),
      ),
      child: Column(
        children: [
          Icon(icon, size: 34, color: MoncarColors.inkFaint),
          const SizedBox(height: 10),
          Text(
            message,
            textAlign: TextAlign.center,
            style: TextStyle(color: MoncarColors.inkMut, fontSize: 14),
          ),
        ],
      ),
    );
  }
}

/// Bandeau d'information (traçabilité, règles serveur…).
class InfoBanner extends StatelessWidget {
  const InfoBanner({
    super.key,
    required this.message,
    this.icon = Icons.info_outline_rounded,
    this.color,
  });

  final String message;
  final IconData icon;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final c = color ?? MoncarColors.info;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: c.withValues(alpha: MoncarColors.isDark ? 0.16 : 0.08),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: c.withValues(alpha: 0.25)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: c),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: TextStyle(
                fontSize: 12.5,
                color: MoncarColors.ink,
                height: 1.35,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Avatar à initiales coloré.
class InitialsAvatar extends StatelessWidget {
  const InitialsAvatar({
    super.key,
    required this.initials,
    required this.color,
    this.size = 44,
  });

  final String initials;
  final Color color;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: color.withValues(alpha: MoncarColors.isDark ? 0.28 : 0.14),
        borderRadius: BorderRadius.circular(size * 0.32),
      ),
      child: Text(
        initials,
        style: TextStyle(
          color: color,
          fontWeight: FontWeight.w800,
          fontSize: size * 0.34,
        ),
      ),
    );
  }
}

/// Badge de siège (A1…).
class SeatBadge extends StatelessWidget {
  const SeatBadge(this.seat, {super.key, this.color});

  final String seat;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final c = color ?? MoncarColors.brand;
    return Container(
      width: 44,
      height: 44,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: c.withValues(alpha: 0.35), width: 1.5),
        color: c.withValues(alpha: 0.06),
      ),
      child: Text(
        seat,
        style: TextStyle(fontWeight: FontWeight.w800, color: c, fontSize: 14),
      ),
    );
  }
}
