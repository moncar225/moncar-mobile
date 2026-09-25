import 'dart:convert';
import 'dart:typed_data';

import 'package:core_api/core_api.dart' show AppEnvironment;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show appFlavor;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../shared/foundation.dart';
import '../data/device_data.dart';
import '../data/legal_docs.dart';

const _notifPrefs = [
  (
    key: 'voyager',
    label: 'Voyager',
    desc: 'Départs, embarquement, arrêts',
    locked: false,
  ),
  (
    key: 'colis',
    label: 'Colis',
    desc: 'Statut du suivi de colis',
    locked: false,
  ),
  (
    key: 'location',
    label: 'Location',
    desc: 'Véhicules, rappels de retour',
    locked: false,
  ),
  (
    key: 'paiements',
    label: 'Paiements',
    desc: 'Reçus et échecs de paiement',
    locked: true,
  ),
  (
    key: 'promotions',
    label: 'Promotions',
    desc: 'Offres et codes promo',
    locked: false,
  ),
  (
    key: 'securite',
    label: 'Sécurité',
    desc: 'Nouveaux appareils, alertes',
    locked: true,
  ),
];

/// Version réellement compilée (pubspec `version: x.y.z+build`), lue sur
/// l'appareil — jamais écrite en dur.
final _appInfoProvider = FutureProvider<PackageInfo>(
  (ref) => PackageInfo.fromPlatform(),
);

/// Paramètres : langue, thème, notifications (sécurité et paiements
/// verrouillés), devise, documents légaux, à propos, données, compte.
class SettingsPage extends ConsumerStatefulWidget {
  const SettingsPage({super.key});

  @override
  ConsumerState<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends ConsumerState<SettingsPage> {
  bool _busy = false;

  void _setTheme(AppThemeChoice t) {
    ref.read(appPreferencesProvider.notifier).setTheme(t);
    final label = switch (t) {
      AppThemeChoice.clair => 'Clair',
      AppThemeChoice.sombre => 'Sombre',
      AppThemeChoice.systeme => 'Système',
    };
    showMoncarToast(context, 'Thème : $label', success: true);
  }

  Future<void> _clearCache() async {
    if (_busy) return;
    setState(() => _busy = true);
    final freed = await clearAppCache();
    if (!mounted) return;
    setState(() => _busy = false);
    showMoncarToast(
      context,
      freed > 0
          ? 'Cache effacé — ${formatBytes(freed)} libérés.'
          : 'Le cache était déjà vide.',
      success: true,
    );
  }

  /// Export JSON des données personnelles, ouvert dans la feuille de
  /// partage (Enregistrer dans Fichiers/Drive, e-mail…).
  Future<void> _exportData() async {
    final user = ref.read(authProvider).user;
    if (user == null || _busy) return;
    setState(() => _busy = true);
    try {
      final json = buildPersonalDataExport(
        user: user,
        store: ref.read(mockStoreProvider),
        prefs: ref.read(appPreferencesProvider),
        favorites: ref.read(favoritesProvider).favorites,
      );
      const name = 'mes-donnees-moncar.json';
      await SharePlus.instance.share(
        ShareParams(
          files: [
            XFile.fromData(
              Uint8List.fromList(utf8.encode(json)),
              mimeType: 'application/json',
              name: name,
            ),
          ],
          fileNameOverrides: const [name],
          subject: 'Mes données MON CAR',
        ),
      );
    } catch (_) {
      if (mounted) {
        showMoncarToast(
          context,
          "Impossible de préparer l'export. Réessayez.",
          error: true,
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _openLegal(String key) {
    final doc = legalDocs[key]!;
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: MoncarColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => FractionallySizedBox(
        heightFactor: 0.85,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 20, 16, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    doc.title,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: MoncarColors.ink,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Dernière mise à jour : ${doc.updated}',
                    style: TextStyle(fontSize: 11, color: MoncarColors.inkMut),
                  ),
                ],
              ),
            ),
            Divider(height: 1, color: MoncarColors.hairline),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: SelectionArea(child: _LegalBody(doc.body)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _confirmDelete() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: MoncarColors.danger),
            SizedBox(width: 8),
            Expanded(
              child: Text(
                'Supprimer votre compte ?',
                style: TextStyle(color: MoncarColors.danger),
              ),
            ),
          ],
        ),
        content: const Text(
          "Cette action est irréversible. Vos données personnelles seront supprimées sous 30 jours. Vos réservations en cours et billets électroniques restent valables jusqu'à leur date d'échéance. Un email de confirmation vous sera envoyé.",
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Annuler'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: MoncarColors.danger),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Supprimer'),
          ),
        ],
      ),
    );
    if (ok == true && mounted) {
      showMoncarToast(
        context,
        'Demande de suppression envoyée. Un email de confirmation vous a été envoyé. Compte supprimé sous 30 jours.',
        success: true,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final prefs = ref.watch(appPreferencesProvider);
    final info = ref.watch(_appInfoProvider).value;
    final version = info == null
        ? '…'
        : '${info.version} (${info.buildNumber})'
              '${appFlavor == null ? '' : ' • $appFlavor'}';
    return Scaffold(
      backgroundColor: MoncarColors.background,
      appBar: const TopBar(
        title: 'Paramètres',
        showBack: true,
        showBell: false,
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 80),
        children: [
          _Section(
            icon: Icons.language,
            title: 'Langue',
            child: const Row(
              children: [
                Expanded(
                  child: _RadioCard(
                    label: 'Français',
                    sub: 'Par défaut',
                    checked: true,
                  ),
                ),
                SizedBox(width: 8),
                Expanded(
                  child: _RadioCard(
                    label: 'English',
                    sub: 'Bientôt',
                    checked: false,
                    disabled: true,
                  ),
                ),
              ],
            ),
          ),
          _Section(
            icon: Icons.palette_outlined,
            title: 'Thème',
            child: Row(
              children: [
                for (final (t, label, icon) in const [
                  (AppThemeChoice.clair, 'Clair', Icons.light_mode_outlined),
                  (AppThemeChoice.sombre, 'Sombre', Icons.dark_mode_outlined),
                  (AppThemeChoice.systeme, 'Système', Icons.smartphone),
                ]) ...[
                  if (t != AppThemeChoice.clair) const SizedBox(width: 8),
                  Expanded(
                    child: _ThemeCard(
                      label: label,
                      icon: icon,
                      checked: prefs.theme == t,
                      onTap: () => _setTheme(t),
                    ),
                  ),
                ],
              ],
            ),
          ),
          _Section(
            icon: Icons.shield_outlined,
            title: 'Notifications',
            desc: 'Sélectionnez les alertes que vous souhaitez recevoir.',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                MoncarCard(
                  padding: const EdgeInsets.all(6),
                  child: Column(
                    children: [
                      for (var i = 0; i < _notifPrefs.length; i++)
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 8,
                          ),
                          decoration: BoxDecoration(
                            border: i < _notifPrefs.length - 1
                                ? Border(
                                    bottom: BorderSide(
                                      color: MoncarColors.hairline.withValues(
                                        alpha: 0.7,
                                      ),
                                    ),
                                  )
                                : null,
                          ),
                          child: Row(
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Flexible(
                                          child: Text(
                                            _notifPrefs[i].label,
                                            overflow: TextOverflow.ellipsis,
                                            style: TextStyle(
                                              fontSize: 14,
                                              fontWeight: FontWeight.w600,
                                              color: MoncarColors.ink,
                                            ),
                                          ),
                                        ),
                                        if (_notifPrefs[i].locked) ...[
                                          const SizedBox(width: 6),
                                          const MoncarBadge(
                                            label: 'Verrouillé',
                                            tone: MoncarBadgeTone.neutral,
                                            size: MoncarBadgeSize.sm,
                                            icon: Icons.lock_outline,
                                          ),
                                        ],
                                      ],
                                    ),
                                    Text(
                                      _notifPrefs[i].desc,
                                      style: TextStyle(
                                        fontSize: 11,
                                        color: MoncarColors.inkMut,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              Switch(
                                value:
                                    prefs.notifications[_notifPrefs[i].key] ??
                                    true,
                                activeTrackColor: MoncarColors.accent,
                                onChanged: _notifPrefs[i].locked
                                    ? null
                                    : (v) => ref
                                          .read(appPreferencesProvider.notifier)
                                          .setNotification(
                                            _notifPrefs[i].key,
                                            v,
                                          ),
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    SizedBox(width: 4),
                    Icon(
                      Icons.info_outline,
                      size: 12,
                      color: MoncarColors.inkFaint,
                    ),
                    SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        'Les notifications de sécurité et de paiement ne peuvent pas être désactivées.',
                        style: TextStyle(
                          fontSize: 11,
                          color: MoncarColors.inkFaint,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          _Section(
            icon: Icons.language,
            title: 'Devise',
            child: MoncarCard(
              padding: EdgeInsets.all(14),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 20,
                    backgroundColor: MoncarColors.brandSoft,
                    child: Text(
                      'FCFA',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: MoncarColors.brand,
                      ),
                    ),
                  ),
                  SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Franc CFA (XOF)',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: MoncarColors.ink,
                          ),
                        ),
                        Text(
                          "Devise officielle de MON CAR en Côte d'Ivoire.",
                          style: TextStyle(
                            fontSize: 11,
                            color: MoncarColors.inkMut,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Icon(
                    Icons.lock_outline,
                    size: 16,
                    color: MoncarColors.inkFaint,
                  ),
                ],
              ),
            ),
          ),
          _Section(
            icon: Icons.description_outlined,
            title: 'Confidentialité',
            child: MoncarCard(
              padding: const EdgeInsets.all(6),
              child: Column(
                children: [
                  _Row(
                    icon: Icons.description_outlined,
                    label: 'Politique de confidentialité',
                    onTap: () => _openLegal('privacy'),
                  ),
                  _Row(
                    icon: Icons.description_outlined,
                    label: "Conditions d'utilisation",
                    onTap: () => _openLegal('terms'),
                  ),
                  _Row(
                    icon: Icons.description_outlined,
                    label: 'Mentions légales',
                    onTap: () => _openLegal('legal'),
                  ),
                  _Row(
                    icon: Icons.groups_outlined,
                    label: 'Crédits',
                    onTap: () => _openLegal('credits'),
                    last: true,
                  ),
                ],
              ),
            ),
          ),
          _Section(
            icon: Icons.info_outline,
            title: 'À propos',
            child: MoncarCard(
              padding: const EdgeInsets.all(14),
              child: Column(
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'MON CAR',
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w700,
                                color: MoncarColors.ink,
                              ),
                            ),
                            Text(
                              'Version $version',
                              style: TextStyle(
                                fontSize: 11,
                                color: MoncarColors.inkMut,
                              ),
                            ),
                          ],
                        ),
                      ),
                      MoncarBadge(label: 'Flutter'),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: MoncarButton(
                          label: "Évaluer l'app",
                          icon: Icons.star_border,
                          variant: MoncarButtonVariant.soft,
                          size: MoncarButtonSize.md,
                          expand: true,
                          onPressed: () => showMoncarToast(
                            context,
                            "Ouverture de l'App Store / Google Play… Merci de prendre 30s pour noter MON CAR ⭐",
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: MoncarButton(
                          label: "Partager l'app",
                          icon: Icons.smartphone,
                          variant: MoncarButtonVariant.soft,
                          size: MoncarButtonSize.md,
                          expand: true,
                          onPressed: () => copyWithToast(
                            context,
                            'https://moncar.ci',
                            message: 'Lien copié dans le presse-papier.',
                          ),
                        ),
                      ),
                    ],
                  ),
                  if (!AppEnvironment.isProd) ...[
                    const SizedBox(height: 8),
                    MoncarButton(
                      label: 'Galerie du design system',
                      icon: Icons.palette_outlined,
                      variant: MoncarButtonVariant.ghost,
                      size: MoncarButtonSize.md,
                      expand: true,
                      onPressed: () => context.push('/galerie'),
                    ),
                  ],
                ],
              ),
            ),
          ),
          _Section(
            icon: Icons.storage_outlined,
            title: 'Données',
            child: MoncarCard(
              padding: const EdgeInsets.all(6),
              child: Column(
                children: [
                  _Row(
                    icon: Icons.delete_outline,
                    label: 'Effacer le cache',
                    desc: "Images et fichiers temporaires",
                    onTap: _clearCache,
                  ),
                  _Row(
                    icon: Icons.storage_outlined,
                    label: 'Télécharger mes données',
                    desc: 'Fichier JSON de vos informations',
                    onTap: _exportData,
                    last: true,
                  ),
                ],
              ),
            ),
          ),
          _Section(
            icon: Icons.person_off_outlined,
            title: 'Compte',
            danger: true,
            child: MoncarCard(
              padding: const EdgeInsets.all(6),
              child: _Row(
                icon: Icons.person_off_outlined,
                label: 'Supprimer mon compte',
                desc: 'Action irréversible sous 30 jours',
                danger: true,
                onTap: _confirmDelete,
                last: true,
              ),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'MON CAR v${info?.version ?? '…'} — © ${DateTime.now().year} PROSOFT ACADEMY SARL',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 11, color: MoncarColors.inkFaint),
          ),
        ],
      ),
    );
  }
}

/// Rendu d'un texte légal : « ## » = titre, « - » = puce, sinon paragraphe.
class _LegalBody extends StatelessWidget {
  const _LegalBody(this.body);

  final String body;

  @override
  Widget build(BuildContext context) {
    final text = TextStyle(
      fontSize: 13,
      height: 1.6,
      color: MoncarColors.inkMut,
    );
    final children = <Widget>[];
    for (final line in body.trim().split('\n')) {
      if (line.trim().isEmpty) {
        children.add(const SizedBox(height: 8));
      } else if (line.startsWith('## ')) {
        children.add(
          Padding(
            padding: EdgeInsets.only(top: children.isEmpty ? 0 : 12, bottom: 2),
            child: Text(
              line.substring(3),
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: MoncarColors.ink,
              ),
            ),
          ),
        );
      } else if (line.startsWith('- ')) {
        children.add(
          Padding(
            padding: const EdgeInsets.only(left: 4),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('•  ', style: text),
                Expanded(child: Text(line.substring(2), style: text)),
              ],
            ),
          ),
        );
      } else {
        children.add(_linkified(line, text));
      }
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: children,
    );
  }

  static final _link = RegExp(r'\[([^\]]+)\]\((https?://[^)]+)\)');

  /// Transforme les « [libellé](url) » d'une ligne en liens ouverts dans le
  /// navigateur externe.
  Widget _linkified(String line, TextStyle style) {
    if (!_link.hasMatch(line)) return Text(line, style: style);
    final spans = <InlineSpan>[];
    var start = 0;
    for (final m in _link.allMatches(line)) {
      spans.add(TextSpan(text: line.substring(start, m.start)));
      final uri = Uri.parse(m.group(2)!);
      spans.add(
        WidgetSpan(
          alignment: PlaceholderAlignment.baseline,
          baseline: TextBaseline.alphabetic,
          child: GestureDetector(
            onTap: () => launchUrl(uri, mode: LaunchMode.externalApplication),
            child: Text(
              m.group(1)!,
              style: style.copyWith(
                color: MoncarColors.primary,
                fontWeight: FontWeight.w600,
                decoration: TextDecoration.underline,
                decorationColor: MoncarColors.primary,
              ),
            ),
          ),
        ),
      );
      start = m.end;
    }
    spans.add(TextSpan(text: line.substring(start)));
    return Text.rich(TextSpan(style: style, children: spans));
  }
}

class _Section extends StatelessWidget {
  const _Section({
    required this.icon,
    required this.title,
    required this.child,
    this.desc,
    this.danger = false,
  });

  final IconData icon;
  final String title;
  final String? desc;
  final Widget child;
  final bool danger;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(4, 0, 4, 8),
            child: Row(
              children: [
                Icon(
                  icon,
                  size: 14,
                  color: danger ? MoncarColors.danger : MoncarColors.brand,
                ),
                const SizedBox(width: 6),
                OverlineText(
                  title,
                  color: danger ? MoncarColors.danger : MoncarColors.inkFaint,
                ),
              ],
            ),
          ),
          if (desc != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(4, 0, 4, 8),
              child: Text(
                desc!,
                style: TextStyle(fontSize: 11, color: MoncarColors.inkMut),
              ),
            ),
          child,
        ],
      ),
    );
  }
}

class _RadioCard extends StatelessWidget {
  const _RadioCard({
    required this.label,
    required this.checked,
    this.sub,
    this.disabled = false,
  });

  final String label;
  final String? sub;
  final bool checked;
  final bool disabled;

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: disabled ? 0.5 : 1,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: disabled
              ? MoncarColors.muted.withValues(alpha: 0.3)
              : checked
              ? MoncarColors.brandSoft.withValues(alpha: 0.5)
              : MoncarColors.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: checked && !disabled
                ? MoncarColors.brand
                : MoncarColors.hairline,
            width: 2,
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 20,
              height: 20,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: disabled ? MoncarColors.muted : null,
                border: Border.all(
                  color: checked && !disabled
                      ? MoncarColors.brand
                      : MoncarColors.inkFaint,
                  width: 2,
                ),
              ),
              child: disabled
                  ? Icon(
                      Icons.lock_outline,
                      size: 10,
                      color: MoncarColors.inkFaint,
                    )
                  : checked
                  ? Container(
                      width: 10,
                      height: 10,
                      decoration: BoxDecoration(
                        color: MoncarColors.brand,
                        shape: BoxShape.circle,
                      ),
                    )
                  : null,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: disabled
                          ? MoncarColors.inkFaint
                          : MoncarColors.ink,
                    ),
                  ),
                  if (sub != null)
                    Text(
                      sub!,
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                        color: MoncarColors.inkMut,
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ThemeCard extends StatelessWidget {
  const _ThemeCard({
    required this.label,
    required this.icon,
    required this.checked,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final bool checked;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      selected: checked,
      button: true,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: checked
                ? MoncarColors.brandSoft.withValues(alpha: 0.5)
                : MoncarColors.surface,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: checked ? MoncarColors.brand : MoncarColors.hairline,
              width: 2,
            ),
          ),
          child: Column(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: checked
                    ? brandGradientDecoration().copyWith(shape: BoxShape.circle)
                    : BoxDecoration(
                        color: MoncarColors.brandSoft,
                        shape: BoxShape.circle,
                      ),
                child: Icon(
                  icon,
                  size: 16,
                  color: checked ? Colors.white : MoncarColors.brand,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: checked ? MoncarColors.brand : MoncarColors.inkMut,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Row extends StatelessWidget {
  const _Row({
    required this.icon,
    required this.label,
    required this.onTap,
    this.desc,
    this.last = false,
    this.danger = false,
  });

  final IconData icon;
  final String label;
  final String? desc;
  final VoidCallback onTap;
  final bool last;
  final bool danger;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          border: last
              ? null
              : Border(
                  bottom: BorderSide(
                    color: MoncarColors.hairline.withValues(alpha: 0.7),
                  ),
                ),
        ),
        child: Row(
          children: [
            IconTile(
              icon: icon,
              color: danger ? MoncarColors.danger : MoncarColors.brand,
              background: danger
                  ? MoncarColors.dangerSoft
                  : MoncarColors.brandSoft,
              size: 36,
              radius: 18,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: danger ? MoncarColors.danger : MoncarColors.ink,
                    ),
                  ),
                  if (desc != null)
                    Text(
                      desc!,
                      style: TextStyle(
                        fontSize: 11,
                        color: MoncarColors.inkMut,
                      ),
                    ),
                ],
              ),
            ),
            Icon(Icons.chevron_right, size: 16, color: MoncarColors.inkFaint),
          ],
        ),
      ),
    );
  }
}
