import 'package:flutter/material.dart';

import '../components/moncar_avatar.dart';
import '../components/moncar_badge.dart';
import '../components/moncar_button.dart';
import '../components/moncar_card.dart';
import '../components/moncar_chip.dart';
import '../components/moncar_empty_state.dart';
import '../components/moncar_error_state.dart';
import '../components/moncar_inline_error.dart';
import '../components/moncar_loader.dart';
import '../components/moncar_offline_banner.dart';
import '../components/moncar_pending_state.dart';
import '../components/moncar_rating.dart';
import '../components/moncar_section_header.dart';
import '../components/moncar_skeleton.dart';
import '../components/moncar_success_state.dart';
import '../theme/moncar_colors.dart';
import '../theme/moncar_radius.dart';
import '../theme/moncar_spacing.dart';

/// Section supplémentaire fournie par une app (ex. messages d'erreur API).
class MoncarGallerySection {
  const MoncarGallerySection({required this.title, required this.child});

  final String title;
  final Widget child;
}

/// Galerie du design system MON CAR : couleurs, typographie, composants et
/// états (chargement, vide, erreur…). Écran de contrôle visuel partagé par
/// les apps client et PRO (roadmap Sprint 1) — réservé aux environnements
/// dev et recette.
class MoncarGalleryPage extends StatelessWidget {
  const MoncarGalleryPage({
    super.key,
    this.subtitle,
    this.errorMessages = const {},
    this.extraSections = const [],
  });

  /// Ligne d'information sous le titre (app, environnement, version).
  final String? subtitle;

  /// Messages d'erreur normalisés par code HTTP (`apiErrorMessages` de
  /// core_api) : affichés pour relecture des textes (§11.2).
  final Map<int, String> errorMessages;

  final List<MoncarGallerySection> extraSections;

  @override
  Widget build(BuildContext context) {
    final sections = <MoncarGallerySection>[
      const MoncarGallerySection(title: 'Couleurs', child: _Colors()),
      const MoncarGallerySection(title: 'Typographie', child: _Typography()),
      const MoncarGallerySection(
        title: 'Espacements et rayons',
        child: _SpacingAndRadius(),
      ),
      const MoncarGallerySection(title: 'Boutons', child: _Buttons()),
      const MoncarGallerySection(
        title: 'Badges, puces, avatar, note',
        child: _SmallComponents(),
      ),
      const MoncarGallerySection(title: 'Cartes', child: _Cards()),
      const MoncarGallerySection(title: 'Chargement', child: _LoadingStates()),
      const MoncarGallerySection(
        title: 'États vide, erreur, attente, succès',
        child: _FeedbackStates(),
      ),
      if (errorMessages.isNotEmpty)
        MoncarGallerySection(
          title: "Messages d'erreur API",
          child: _ErrorMessages(errorMessages),
        ),
      ...extraSections,
    ];

    return Scaffold(
      appBar: AppBar(title: const Text('Galerie du design system')),
      body: ListView.separated(
        padding: const EdgeInsets.only(bottom: MoncarSpacing.xxl),
        itemCount: sections.length + 1,
        separatorBuilder: (_, _) => const SizedBox(height: MoncarSpacing.lg),
        itemBuilder: (context, i) {
          if (i == 0) {
            return Padding(
              padding: const EdgeInsets.fromLTRB(
                MoncarSpacing.md,
                MoncarSpacing.md,
                MoncarSpacing.md,
                0,
              ),
              child: Text(
                subtitle ?? 'Composants partagés `core_ui`',
                style: Theme.of(
                  context,
                ).textTheme.bodySmall?.copyWith(color: MoncarColors.inkMut),
              ),
            );
          }
          final s = sections[i - 1];
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              MoncarSectionHeader(title: s.title),
              const SizedBox(height: MoncarSpacing.sm),
              s.child,
            ],
          );
        },
      ),
    );
  }
}

const _hPad = EdgeInsets.symmetric(horizontal: MoncarSpacing.md);

class _Colors extends StatelessWidget {
  const _Colors();

  @override
  Widget build(BuildContext context) {
    final swatches = <(String, Color)>[
      ('brand', MoncarColors.brand),
      ('brandSoft', MoncarColors.brandSoft),
      ('brandInk', MoncarColors.brandInk),
      ('accent', MoncarColors.accent),
      ('accentSoft', MoncarColors.accentSoft),
      ('accentInk', MoncarColors.accentInk),
      ('success', MoncarColors.success),
      ('successSoft', MoncarColors.successSoft),
      ('danger', MoncarColors.danger),
      ('dangerSoft', MoncarColors.dangerSoft),
      ('warn', MoncarColors.warn),
      ('warnSoft', MoncarColors.warnSoft),
      ('info', MoncarColors.info),
      ('background', MoncarColors.background),
      ('surface', MoncarColors.surface),
      ('muted', MoncarColors.muted),
      ('hairline', MoncarColors.hairline),
      ('ink', MoncarColors.ink),
      ('inkMut', MoncarColors.inkMut),
      ('inkFaint', MoncarColors.inkFaint),
    ];
    return Padding(
      padding: _hPad,
      child: Wrap(
        spacing: MoncarSpacing.sm,
        runSpacing: MoncarSpacing.sm,
        children: [
          for (final (name, color) in swatches)
            SizedBox(
              width: 96,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    height: 44,
                    decoration: BoxDecoration(
                      color: color,
                      borderRadius: BorderRadius.circular(MoncarRadius.medium),
                      border: Border.all(color: MoncarColors.hairline),
                    ),
                  ),
                  const SizedBox(height: MoncarSpacing.xs),
                  Text(name, style: Theme.of(context).textTheme.labelSmall),
                  Text(
                    '#${color.toARGB32().toRadixString(16).substring(2).toUpperCase()}',
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: MoncarColors.inkMut,
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _Typography extends StatelessWidget {
  const _Typography();

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final styles = <(String, TextStyle?)>[
      ('headlineSmall', t.headlineSmall),
      ('titleLarge', t.titleLarge),
      ('titleMedium', t.titleMedium),
      ('bodyLarge', t.bodyLarge),
      ('bodyMedium', t.bodyMedium),
      ('bodySmall', t.bodySmall),
      ('labelLarge', t.labelLarge),
      ('labelSmall', t.labelSmall),
    ];
    return Padding(
      padding: _hPad,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (final (name, style) in styles)
            Padding(
              padding: const EdgeInsets.only(bottom: MoncarSpacing.xs),
              child: Text('$name — Abidjan → Yamoussoukro', style: style),
            ),
        ],
      ),
    );
  }
}

class _SpacingAndRadius extends StatelessWidget {
  const _SpacingAndRadius();

  @override
  Widget build(BuildContext context) {
    const spacings = <(String, double)>[
      ('xs', MoncarSpacing.xs),
      ('sm', MoncarSpacing.sm),
      ('md', MoncarSpacing.md),
      ('lg', MoncarSpacing.lg),
      ('xl', MoncarSpacing.xl),
      ('xxl', MoncarSpacing.xxl),
    ];
    const radii = <(String, double)>[
      ('small', MoncarRadius.small),
      ('medium', MoncarRadius.medium),
      ('large', MoncarRadius.large),
      ('card', MoncarRadius.card),
      ('xl', MoncarRadius.xl),
    ];
    final label = Theme.of(context).textTheme.labelSmall;
    return Padding(
      padding: _hPad,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (final (name, v) in spacings)
            Padding(
              padding: const EdgeInsets.only(bottom: MoncarSpacing.xs),
              child: Row(
                children: [
                  SizedBox(
                    width: 72,
                    child: Text('$name · ${v.toInt()}', style: label),
                  ),
                  Container(width: v, height: 12, color: MoncarColors.brand),
                ],
              ),
            ),
          const SizedBox(height: MoncarSpacing.sm),
          Wrap(
            spacing: MoncarSpacing.sm,
            runSpacing: MoncarSpacing.sm,
            children: [
              for (final (name, r) in radii)
                Container(
                  width: 72,
                  height: 48,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: MoncarColors.brandSoft,
                    borderRadius: BorderRadius.circular(r),
                  ),
                  child: Text(
                    '$name\n${r.toInt()}',
                    textAlign: TextAlign.center,
                    style: label,
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _Buttons extends StatelessWidget {
  const _Buttons();

  @override
  Widget build(BuildContext context) {
    void noop() {}
    return Padding(
      padding: _hPad,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Wrap(
            spacing: MoncarSpacing.sm,
            runSpacing: MoncarSpacing.sm,
            children: [
              for (final v in MoncarButtonVariant.values)
                MoncarButton(label: v.name, variant: v, onPressed: noop),
            ],
          ),
          const SizedBox(height: MoncarSpacing.md),
          Wrap(
            spacing: MoncarSpacing.sm,
            runSpacing: MoncarSpacing.sm,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              for (final s in MoncarButtonSize.values)
                MoncarButton(
                  label: 'Taille ${s.name}',
                  size: s,
                  onPressed: noop,
                ),
            ],
          ),
          const SizedBox(height: MoncarSpacing.md),
          MoncarButton(
            label: 'Avec icône, pleine largeur',
            icon: Icons.qr_code_scanner,
            expand: true,
            onPressed: noop,
          ),
          const SizedBox(height: MoncarSpacing.sm),
          const MoncarButton(label: 'En cours', isLoading: true, expand: true),
          const SizedBox(height: MoncarSpacing.sm),
          const MoncarButton(label: 'Désactivé', expand: true),
        ],
      ),
    );
  }
}

class _SmallComponents extends StatefulWidget {
  const _SmallComponents();

  @override
  State<_SmallComponents> createState() => _SmallComponentsState();
}

class _SmallComponentsState extends State<_SmallComponents> {
  int _chip = 0;

  @override
  Widget build(BuildContext context) {
    const chips = ['Aller simple', 'Aller-retour', 'VIP'];
    return Padding(
      padding: _hPad,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: MoncarSpacing.sm,
            runSpacing: MoncarSpacing.sm,
            children: [
              for (final tone in MoncarBadgeTone.values)
                MoncarBadge(label: tone.name, tone: tone),
              const MoncarBadge(
                label: 'Payé',
                tone: MoncarBadgeTone.success,
                icon: Icons.check,
              ),
            ],
          ),
          const SizedBox(height: MoncarSpacing.md),
          Wrap(
            spacing: MoncarSpacing.sm,
            runSpacing: MoncarSpacing.sm,
            children: [
              for (var i = 0; i < chips.length; i++)
                MoncarChip(
                  label: chips[i],
                  active: _chip == i,
                  onTap: () => setState(() => _chip = i),
                ),
            ],
          ),
          const SizedBox(height: MoncarSpacing.md),
          const Row(
            children: [
              MoncarAvatar(initials: 'KA'),
              SizedBox(width: MoncarSpacing.sm),
              MoncarAvatar(initials: 'MC', size: 48),
              SizedBox(width: MoncarSpacing.md),
              MoncarRating(value: 4.5, count: 128),
            ],
          ),
        ],
      ),
    );
  }
}

class _Cards extends StatelessWidget {
  const _Cards();

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return Padding(
      padding: _hPad,
      child: Column(
        children: [
          MoncarCard(
            onTap: () {},
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Abidjan → Yamoussoukro', style: t.titleMedium),
                      Text('Départ 07:30 · 3 h 10', style: t.bodySmall),
                    ],
                  ),
                ),
                const MoncarBadge(label: 'VIP', tone: MoncarBadgeTone.accent),
              ],
            ),
          ),
          const SizedBox(height: MoncarSpacing.sm),
          MoncarCard(
            color: MoncarColors.brandSoft,
            child: Text('Carte de couleur « brandSoft »', style: t.bodyMedium),
          ),
        ],
      ),
    );
  }
}

class _LoadingStates extends StatelessWidget {
  const _LoadingStates();

  @override
  Widget build(BuildContext context) {
    return const Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        MoncarOfflineBanner(),
        SizedBox(height: MoncarSpacing.md),
        MoncarLoader(label: 'Chargement des voyages…'),
        SizedBox(height: MoncarSpacing.md),
        Padding(
          padding: _hPad,
          child: Row(
            children: [
              MoncarSkeleton(width: 48, height: 48, circle: true),
              SizedBox(width: MoncarSpacing.sm),
              Expanded(child: MoncarSkeleton(height: 14)),
            ],
          ),
        ),
        SizedBox(height: MoncarSpacing.sm),
        MoncarListSkeleton(count: 2),
      ],
    );
  }
}

class _FeedbackStates extends StatelessWidget {
  const _FeedbackStates();

  @override
  Widget build(BuildContext context) {
    void noop() {}
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        MoncarEmptyState(
          title: 'Aucun voyage trouvé',
          message: 'Essayez une autre date ou une autre destination.',
          icon: Icons.directions_bus_outlined,
          actionLabel: 'Modifier la recherche',
          onAction: noop,
        ),
        MoncarErrorState(
          message:
              'Une erreur est survenue côté serveur. Veuillez réessayer plus tard.',
          incidentId: 'REQ-2026-000125',
          onRetry: noop,
        ),
        Padding(
          padding: _hPad,
          child: MoncarInlineError(
            message: 'Connexion impossible. Vérifiez votre réseau.',
            onRetry: noop,
          ),
        ),
        const MoncarPendingState(
          title: 'Paiement en attente',
          message: 'Validez la demande sur votre téléphone.',
          countdown: 120,
        ),
        MoncarSuccessState(
          title: 'Paiement confirmé',
          message: 'Votre billet est disponible.',
          actionLabel: 'Voir mon billet',
          onAction: noop,
        ),
      ],
    );
  }
}

class _ErrorMessages extends StatelessWidget {
  const _ErrorMessages(this.messages);

  final Map<int, String> messages;

  @override
  Widget build(BuildContext context) {
    final codes = messages.keys.toList()..sort();
    return Padding(
      padding: _hPad,
      child: Column(
        children: [
          for (final code in codes)
            Padding(
              padding: const EdgeInsets.only(bottom: MoncarSpacing.sm),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(
                    width: 64,
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: MoncarBadge(
                        label: '$code',
                        tone: code >= 500
                            ? MoncarBadgeTone.danger
                            : MoncarBadgeTone.warn,
                      ),
                    ),
                  ),
                  const SizedBox(width: MoncarSpacing.sm),
                  Expanded(
                    child: Text(
                      messages[code]!,
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
